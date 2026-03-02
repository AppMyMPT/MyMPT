import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:my_mpt/data/models/teacher.dart';
import 'package:my_mpt/data/parsers/teacher_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<Map<String, dynamic>> _parseTeacherIsolate(Map<String, dynamic> message) {
  final html = message['html'] as String? ?? '';
  final document = parser.parse(html);
  
  final teachers = TeacherParser().parse(document.outerHtml);
  return teachers.map((t) => t.toJson()).toList();
}

class TeacherRemoteDatasource {
  TeacherRemoteDatasource({
    http.Client? client,
    this.baseUrl = 'https://mpt.ru/raspisanie-zanyatiy/',
    this.cacheTtl = const Duration(hours: 24),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;
  final Duration cacheTtl;

  static const String _cacheKeyTeachers = 'mpt_parser_teachers';
  static const String _cacheKeyTeachersTimestamp = 'mpt_parser_teachers_timestamp';

  Future<List<Teacher>> fetchTeachers({bool forceRefresh = false}) async {
    try {
      if (!forceRefresh) {
        final cached = await _getCachedTeachers();
        if (cached != null && cached.isNotEmpty) return cached;
      }

      final response = await _client
          .get(Uri.parse(baseUrl))
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception(
              'Превышено время ожидания ответа от сервера (15 секунд)',
            ),
          );

      if (response.statusCode != 200) {
        throw Exception('Не удалось загрузить страницу: ${response.statusCode}');
      }

      final html = utf8.decode(response.bodyBytes);

      final decoded = await compute(_parseTeacherIsolate, {'html': html});

      final teachers = decoded.map((map) => Teacher.fromJson(map)).toList();

      if (teachers.isEmpty) {
        throw Exception('Сайт МПТ не вернул список преподавателей. Возможно, страница недоступна.');
      }

      await _saveCachedTeachers(teachers);
      return teachers;
    } catch (e) {
      final fallbackCache = await _getCachedTeachers(ignoreTtl: true);
      if (fallbackCache != null && fallbackCache.isNotEmpty) {
        return fallbackCache;
      }
      throw Exception('Ошибка при получении преподавателей: $e');
    }
  }

  Future<List<Teacher>?> _getCachedTeachers({bool ignoreTtl = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final timestamp = prefs.getInt(_cacheKeyTeachersTimestamp);
      final cachedJson = prefs.getString(_cacheKeyTeachers);

      if (timestamp != null && cachedJson != null) {
        final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final age = DateTime.now().difference(cacheTime);

        if (ignoreTtl || age < cacheTtl) {
          final List<dynamic> decoded = jsonDecode(cachedJson);
          final result = decoded
              .map((json) => Teacher.fromJson(json as Map<String, dynamic>))
              .toList();
              
          if (result.isNotEmpty) return result;
        } else {
          if (!ignoreTtl) {
            await prefs.remove(_cacheKeyTeachers);
            await prefs.remove(_cacheKeyTeachersTimestamp);
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _saveCachedTeachers(List<Teacher> teachers) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(teachers.map((t) => t.toJson()).toList());
      await prefs.setString(_cacheKeyTeachers, json);
      await prefs.setInt(_cacheKeyTeachersTimestamp, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }
}
