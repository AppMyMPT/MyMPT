import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:html/parser.dart' show parse;
import 'package:http/http.dart' as http;
import 'package:my_mpt/data/parsers/speciality_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SpecialityRemoteDatasource {
  SpecialityRemoteDatasource({
    http.Client? client,
    this.baseUrl = 'https://mpt.ru/raspisanie/',
    this.cacheTtl = const Duration(hours: 24),
    SpecialityParser? specialityParser,
  })  : _client = client ?? http.Client(),
        _specialityParser = specialityParser ?? SpecialityParser();

  final http.Client _client;
  final SpecialityParser _specialityParser;
  final String baseUrl;
  final Duration cacheTtl;

  static const Duration _requestTimeout = Duration(seconds: 8);
  static const int _maxRetryAttempts = 3;
  static const Duration _retryBaseDelay = Duration(milliseconds: 350);

  static const String _cacheKeyTabs = 'speciality_tabs';
  static const String _cacheKeyTabsTimestamp = 'speciality_tabs_timestamp';

  Future<List<Map<String, String>>> parseTabList({
    bool forceRefresh = false,
  }) async {
    try {
      if (!forceRefresh) {
        final cachedTabs = await _getCachedTabs();
        if (cachedTabs != null && cachedTabs.isNotEmpty) {
          return cachedTabs;
        }
      }

      final response = await _getWithRetry(Uri.parse(baseUrl));

      final document = parse(utf8.decode(response.bodyBytes));
      final tabs = _specialityParser.parse(document);

      if (tabs.isEmpty) {
        throw Exception('Сайт МПТ не вернул список специальностей.');
      }

      await _saveCachedTabs(tabs);
      return tabs;
    } catch (e) {
      final fallbackCache = await _getCachedTabs(ignoreTtl: true);
      if (fallbackCache != null && fallbackCache.isNotEmpty) {
        return fallbackCache;
      }
      throw Exception('Ошибка при парсинге списка вкладок: $e');
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

  Future<List<Map<String, String>>?> _getCachedTabs({bool ignoreTtl = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_cacheKeyTabsTimestamp);
      final cachedJson = prefs.getString(_cacheKeyTabs);

      if (timestamp != null && cachedJson != null) {
        final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final age = DateTime.now().difference(cacheTime);

        if (ignoreTtl || age < cacheTtl) {
          final List<dynamic> decoded = jsonDecode(cachedJson);
          final result = decoded
              .map(
                (json) => {
                  'href': json['href'] as String,
                  'ariaControls': json['ariaControls'] as String,
                  'name': json['name'] as String,
                },
              )
              .toList();

          if (result.isNotEmpty) return result;
        } else if (!ignoreTtl) {
          await prefs.remove(_cacheKeyTabs);
          await prefs.remove(_cacheKeyTabsTimestamp);
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _saveCachedTabs(List<Map<String, String>> tabs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(tabs);
      await prefs.setString(_cacheKeyTabs, json);
      await prefs.setInt(
        _cacheKeyTabsTimestamp,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {}
  }
}
