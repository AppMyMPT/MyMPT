import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:my_mpt/data/models/lesson.dart';
import 'package:my_mpt/data/parsers/schedule_parser.dart';
import 'package:my_mpt/data/parsers/schedule_teacher_parser.dart';

Map<String, List<Map<String, dynamic>>> _parseScheduleIsolate(
  Map<String, dynamic> message,
) {
  final html = message['html'] as String? ?? '';
  final groupCode = message['groupCode'] as String? ?? '';

  final parsed = ScheduleParser().parse(html, groupCode);
  return parsed.map(
    (day, lessons) => MapEntry(day, lessons.map((l) => l.toJson()).toList()),
  );
}

Map<String, List<Map<String, dynamic>>> _parseTeacherScheduleIsolate(
  Map<String, dynamic> message,
) {
  final html = message['html'] as String? ?? '';
  final teacherName = message['teacherName'] as String? ?? '';

  final parsed = ScheduleTeacherParser().parse(html, teacherName);
  return parsed.map(
    (day, lessons) => MapEntry(day, lessons.map((l) => l.toJson()).toList()),
  );
}

class ScheduleRemoteDatasource {
  ScheduleRemoteDatasource({
    http.Client? client,
    this.baseUrl = 'https://mpt.ru/raspisanie/',
    this.cacheTtl = const Duration(hours: 24),
  }) : _client = client ?? http.Client();

  final http.Client _client;

  final String baseUrl;
  final Duration cacheTtl;
  static const Duration _requestTimeout = Duration(seconds: 8);
  static const int _maxRetryAttempts = 3;
  static const Duration _retryBaseDelay = Duration(milliseconds: 350);

  String? _cachedHtml;
  DateTime? _lastFetch;

  // Teacher parser uses the same page as student schedules.
  final String teacherBaseUrl = 'https://mpt.ru/raspisanie/';
  String? _cachedTeacherHtml;
  DateTime? _lastTeacherFetch;

  Future<Map<String, List<Lesson>>> fetchWeeklySchedule(
    String targetName, {
    bool forceRefresh = false,
    bool isTeacher = false,
  }) async {
    if (targetName.isEmpty) return {};

    try {
      final html = await _fetchSchedulePage(
        forceRefresh: forceRefresh,
        isTeacher: isTeacher,
      );

      final decoded = await compute(
        isTeacher ? _parseTeacherScheduleIsolate : _parseScheduleIsolate,
        {'html': html, isTeacher ? 'teacherName' : 'groupCode': targetName},
      );

      final result = <String, List<Lesson>>{};
      decoded.forEach((day, lessonMaps) {
        result[day] = lessonMaps.map(Lesson.fromJson).toList();
      });

      if (result.isEmpty) {
        throw Exception(
          'Сайт МПТ вернул пустую страницу или расписание для "$targetName" не найдено.',
        );
      }

      return result;
    } catch (error) {
      throw Exception(
        'Error fetching schedule for ${isTeacher ? 'teacher' : 'group'} $targetName: $error',
      );
    }
  }

  Future<String> _fetchSchedulePage({
    bool forceRefresh = false,
    bool isTeacher = false,
  }) async {
    final lastFetch = isTeacher ? _lastTeacherFetch : _lastFetch;
    final cachedHtml = isTeacher ? _cachedTeacherHtml : _cachedHtml;

    final isCacheValid = cachedHtml != null &&
        lastFetch != null &&
        DateTime.now().difference(lastFetch) < cacheTtl;

    if (!forceRefresh && isCacheValid) {
      return cachedHtml;
    }

    final freshHtml = await _loadFromNetwork(isTeacher: isTeacher);

    if (isTeacher) {
      _cachedTeacherHtml = freshHtml;
      _lastTeacherFetch = DateTime.now();
    } else {
      _cachedHtml = freshHtml;
      _lastFetch = DateTime.now();
    }

    return freshHtml;
  }

  Future<String> _loadFromNetwork({bool isTeacher = false}) async {
    final url = isTeacher ? teacherBaseUrl : baseUrl;
    final response = await _getWithRetry(Uri.parse(url));
    return utf8.decode(response.bodyBytes);
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

  void clearCache() {
    _cachedHtml = null;
    _lastFetch = null;
    _cachedTeacherHtml = null;
    _lastTeacherFetch = null;
  }
}
