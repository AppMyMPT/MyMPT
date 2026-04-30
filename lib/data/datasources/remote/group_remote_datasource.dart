import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as parser;
import 'package:http/http.dart' as http;
import 'package:my_mpt/data/models/group.dart';
import 'package:my_mpt/data/parsers/group_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<Map<String, dynamic>> _parseGroupsIsolate(Map<String, dynamic> message) {
  final html = message['html'] as String? ?? '';
  final filter = message['specialtyFilter'] as String?;
  final document = parser.parse(html);

  final groups = GroupParser().parseGroups(document, filter);

  return groups.whereType<Group>().map((g) => g.toJson()).toList();
}

class GroupRemoteDatasource {
  GroupRemoteDatasource({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  final String baseUrl = 'https://mpt.ru/raspisanie/';

  static const Duration _cacheTtl = Duration(hours: 24);
  static const Duration _requestTimeout = Duration(seconds: 8);
  static const int _maxRetryAttempts = 3;
  static const Duration _retryBaseDelay = Duration(milliseconds: 350);

  static const String _cacheKeyGroups = 'mpt_parser_groups_';
  static const String _cacheKeyGroupsTimestamp = 'mpt_parser_groups_timestamp_';

  Future<List<Group>> parseGroups([
    String? specialtyFilter,
    bool forceRefresh = false,
  ]) async {
    if (specialtyFilter != null) {
      return _parseGroupsBySpecialty(specialtyFilter, forceRefresh: forceRefresh);
    }
    return _parseAllGroups(forceRefresh: forceRefresh);
  }

  Future<List<Group>> _parseAllGroups({bool forceRefresh = false}) async {
    try {
      if (!forceRefresh) {
        final cached = await _getCachedGroups(null);
        if (cached != null && cached.isNotEmpty) return cached;
      }

      final response = await _getWithRetry(Uri.parse(baseUrl));
      final html = utf8.decode(response.bodyBytes);

      final decoded = await compute(
        _parseGroupsIsolate,
        {'html': html, 'specialtyFilter': null},
      );

      final groups = decoded.map(Group.fromJson).toList();
      if (groups.isEmpty) {
        throw Exception('Сайт МПТ не вернул список групп.');
      }

      await _saveCachedGroups(null, groups);
      return groups;
    } catch (e) {
      final fallbackCache = await _getCachedGroups(null, ignoreTtl: true);
      if (fallbackCache != null && fallbackCache.isNotEmpty) {
        return fallbackCache;
      }
      throw Exception('Ошибка при парсинге групп: $e');
    }
  }

  Future<List<Group>> _parseGroupsBySpecialty(
    String specialtyFilter, {
    bool forceRefresh = false,
  }) async {
    try {
      if (!forceRefresh) {
        final cached = await _getCachedGroups(specialtyFilter);
        if (cached != null && cached.isNotEmpty) return cached;
      }

      final response = await _getWithRetry(Uri.parse(baseUrl));
      final html = utf8.decode(response.bodyBytes);

      final decoded = await compute(
        _parseGroupsIsolate,
        {'html': html, 'specialtyFilter': specialtyFilter},
      );

      final groups = decoded.map(Group.fromJson).toList();
      if (groups.isEmpty) {
        throw Exception(
          'Сайт МПТ не вернул список групп для специальности "$specialtyFilter".',
        );
      }

      await _saveCachedGroups(specialtyFilter, groups);
      return groups;
    } catch (e) {
      final fallbackCache = await _getCachedGroups(specialtyFilter, ignoreTtl: true);
      if (fallbackCache != null && fallbackCache.isNotEmpty) {
        return fallbackCache;
      }
      throw Exception(
        'Ошибка при парсинге групп для специальности "$specialtyFilter": $e',
      );
    }
  }

  Future<http.Response> _getWithRetry(Uri uri) async {
    Object? lastError;

    for (var attempt = 1; attempt <= _maxRetryAttempts; attempt++) {
      try {
        final response = await _client.get(uri).timeout(
              _requestTimeout,
              onTimeout: () => throw TimeoutException(
                'Превышено время ожидания ответа от сервера',
              ),
            );

        if (response.statusCode == HttpStatus.ok) {
          return response;
        }

        if (!_isRetryableStatus(response.statusCode) ||
            attempt == _maxRetryAttempts) {
          throw HttpException(
            'Не удалось загрузить страницу: ${response.statusCode}',
          );
        }
      } catch (e) {
        lastError = e;
        if (!_isRetryableError(e) || attempt == _maxRetryAttempts) {
          rethrow;
        }
      }

      await Future.delayed(_retryDelayForAttempt(attempt));
    }

    throw Exception('Ошибка загрузки сайта: $lastError');
  }

  bool _isRetryableStatus(int statusCode) {
    return statusCode == 408 ||
        statusCode == 425 ||
        statusCode == 429 ||
        statusCode == 500 ||
        statusCode == 502 ||
        statusCode == 503 ||
        statusCode == 504;
  }

  bool _isRetryableError(Object error) {
    return error is SocketException ||
        error is TimeoutException ||
        error is HandshakeException ||
        error is HttpException;
  }

  Duration _retryDelayForAttempt(int attempt) {
    return _retryBaseDelay * attempt;
  }

  Future<List<Group>?> _getCachedGroups(String? specialtyFilter, {bool ignoreTtl = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final cacheKey = specialtyFilter != null
          ? '$_cacheKeyGroups${specialtyFilter.hashCode}'
          : '${_cacheKeyGroups}all';
      final timestampKey = specialtyFilter != null
          ? '$_cacheKeyGroupsTimestamp${specialtyFilter.hashCode}'
          : '${_cacheKeyGroupsTimestamp}all';

      final timestamp = prefs.getInt(timestampKey);
      final cachedJson = prefs.getString(cacheKey);

      if (timestamp != null && cachedJson != null) {
        final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final age = DateTime.now().difference(cacheTime);

        if (ignoreTtl || age < _cacheTtl) {
          final List<dynamic> decoded = jsonDecode(cachedJson);
          final result = decoded
              .map((json) => Group.fromJson(json as Map<String, dynamic>))
              .toList();

          if (result.isNotEmpty) return result;
        } else if (!ignoreTtl) {
          await prefs.remove(cacheKey);
          await prefs.remove(timestampKey);
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _saveCachedGroups(
    String? specialtyFilter,
    List<Group> groups,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final cacheKey = specialtyFilter != null
          ? '$_cacheKeyGroups${specialtyFilter.hashCode}'
          : '${_cacheKeyGroups}all';
      final timestampKey = specialtyFilter != null
          ? '$_cacheKeyGroupsTimestamp${specialtyFilter.hashCode}'
          : '${_cacheKeyGroupsTimestamp}all';

      final json = jsonEncode(groups.map((g) => g.toJson()).toList());
      await prefs.setString(cacheKey, json);
      await prefs.setInt(timestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }
}
