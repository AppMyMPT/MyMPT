import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:my_mpt/core/utils/teacher_full_name_resolver.dart';
import 'package:my_mpt/data/parsers/teacher_full_name_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<String> _parseTeacherFullNames(String html) {
  return TeacherFullNameParser().parse(html);
}

class TeacherFullNameService {
  TeacherFullNameService({
    http.Client? client,
    this.refreshInterval = const Duration(days: 7),
    this.failedRequestBackoff = const Duration(hours: 12),
  }) : _client = client ?? http.Client();

  static final TeacherFullNameService instance = TeacherFullNameService();

  static const String sourceUrl =
      'https://www.rea.ru/structure/kolledji-i-tehnikum/'
      'moskovskiy-priborostroitelnyiy-tehnikum';
  static const Duration _requestTimeout = Duration(seconds: 10);
  static const int _minimumValidNames = 20;

  static const String _namesKey = 'teacher_full_names_v1';
  static const String _lastSuccessKey = 'teacher_full_names_last_success_v1';
  static const String _lastAttemptKey = 'teacher_full_names_last_attempt_v1';
  static const String _etagKey = 'teacher_full_names_etag_v1';
  static const String _lastModifiedKey = 'teacher_full_names_last_modified_v1';

  final http.Client _client;
  final Duration refreshInterval;
  final Duration failedRequestBackoff;

  Future<void>? _initialization;
  Future<void>? _refreshInFlight;

  /// Loads the persistent cache before the first frame and refreshes stale data
  /// in the background, so resolving a name never waits for the network.
  Future<void> initialize() {
    return _initialization ??= _initialize();
  }

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedNames = _readNames(prefs);
    if (cachedNames != null) {
      updateTeacherFullNameIndex(cachedNames);
    }

    if (_shouldRefresh(prefs, DateTime.now())) {
      unawaited(_refresh(prefs));
    }
  }

  bool _shouldRefresh(SharedPreferences prefs, DateTime now) {
    final lastSuccess = _readDate(prefs, _lastSuccessKey);
    if (lastSuccess != null && now.difference(lastSuccess) < refreshInterval) {
      return false;
    }

    final lastAttempt = _readDate(prefs, _lastAttemptKey);
    return lastAttempt == null ||
        now.difference(lastAttempt) >= failedRequestBackoff;
  }

  Future<void> _refresh(SharedPreferences prefs) {
    return _refreshInFlight ??= _performRefresh(prefs).whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<void> _performRefresh(SharedPreferences prefs) async {
    final now = DateTime.now();
    try {
      await prefs.setInt(_lastAttemptKey, now.millisecondsSinceEpoch);
      final cachedNames = _readNames(prefs);
      final headers = <String, String>{
        'Accept': 'text/html,application/xhtml+xml',
      };
      if (cachedNames != null) {
        final etag = prefs.getString(_etagKey);
        final lastModified = prefs.getString(_lastModifiedKey);
        if (etag != null && etag.isNotEmpty) headers['If-None-Match'] = etag;
        if (lastModified != null && lastModified.isNotEmpty) {
          headers['If-Modified-Since'] = lastModified;
        }
      }

      final response = await _client
          .get(Uri.parse(sourceUrl), headers: headers)
          .timeout(_requestTimeout);

      if (response.statusCode == 304) {
        await prefs.setInt(_lastSuccessKey, now.millisecondsSinceEpoch);
        return;
      }
      if (response.statusCode != 200) {
        throw http.ClientException(
          'Teacher page returned HTTP ${response.statusCode}',
          Uri.parse(sourceUrl),
        );
      }

      final html = utf8.decode(response.bodyBytes);
      final names = await compute(_parseTeacherFullNames, html);
      if (names.length < _minimumValidNames) {
        throw const FormatException('Teacher page has too few valid names');
      }

      if (cachedNames == null || !listEquals(cachedNames, names)) {
        await prefs.setString(_namesKey, jsonEncode(names));
        updateTeacherFullNameIndex(names);
      }

      await prefs.setInt(_lastSuccessKey, now.millisecondsSinceEpoch);
      await _saveValidator(prefs, _etagKey, response.headers['etag']);
      await _saveValidator(
        prefs,
        _lastModifiedKey,
        response.headers['last-modified'],
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Teacher full-name refresh skipped: $error');
      }
    }
  }

  List<String>? _readNames(SharedPreferences prefs) {
    try {
      final raw = prefs.getString(_namesKey);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      final names = decoded.whereType<String>().toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      return names.length >= _minimumValidNames ? names : null;
    } catch (_) {
      return null;
    }
  }

  DateTime? _readDate(SharedPreferences prefs, String key) {
    final milliseconds = prefs.getInt(key);
    return milliseconds == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(milliseconds);
  }

  Future<void> _saveValidator(
    SharedPreferences prefs,
    String key,
    String? value,
  ) async {
    if (value == null || value.isEmpty) return;
    await prefs.setString(key, value);
  }
}
