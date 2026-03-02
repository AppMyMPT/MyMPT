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

  String? _cachedHtml;
  DateTime? _lastFetch;

  Future<Map<String, List<Lesson>>> fetchWeeklySchedule(
    String targetName, {
    bool forceRefresh = false,
    bool isTeacher = false,
  }) async {
    if (targetName.isEmpty) return {};

    try {
      final html = await _fetchSchedulePage(forceRefresh: forceRefresh);

      final decoded = await compute(
        isTeacher ? _parseTeacherScheduleIsolate : _parseScheduleIsolate,
        {'html': html, isTeacher ? 'teacherName' : 'groupCode': targetName},
      );

      final result = <String, List<Lesson>>{};
      decoded.forEach((day, lessonMaps) {
        result[day] = lessonMaps.map(Lesson.fromJson).toList();
      });

      if (result.isEmpty) {
        throw Exception('Сайт МПТ вернул пустую страницу или расписание для "$targetName" не найдено. Возможно, включена защита от ботов или ведутся технические работы.');
      }

      return result;
    } catch (error) {
      throw Exception('Error fetching schedule for ${isTeacher ? 'teacher' : 'group'} $targetName: $error');
    }
  }

  Future<String> _fetchSchedulePage({bool forceRefresh = false}) async {
    final isCacheValid = _cachedHtml != null &&
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < cacheTtl;

    if (!forceRefresh && isCacheValid) {
      return _cachedHtml!;
    }

    final freshHtml = await _loadFromNetwork();
    _cachedHtml = freshHtml;
    _lastFetch = DateTime.now();
    return freshHtml;
  }

  Future<String> _loadFromNetwork() async {
    final response = await _client
        .get(Uri.parse(baseUrl))
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw const HttpException(
            'Превышено время ожидания ответа от сервера (15 секунд)',
          ),
        );

    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('Не удалось загрузить страницу: ${response.statusCode}');
    }

    return utf8.decode(response.bodyBytes);
  }

  void clearCache() {
    _cachedHtml = null;
    _lastFetch = null;
  }
}
