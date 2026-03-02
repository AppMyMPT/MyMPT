import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:my_mpt/data/models/teacher.dart';
import 'package:my_mpt/data/parsers/teacher_parser.dart';

List<Map<String, dynamic>> _parseTeacherIsolate(Map<String, dynamic> message) {
  final html = message['html'] as String? ?? '';
  final document = parser.parse(html);
  
  final teachers = TeacherParser().parse(document);
  return teachers.map((t) => t.toJson()).toList();
}

class TeacherRemoteDatasource {
  TeacherRemoteDatasource({
    http.Client? client,
    this.baseUrl = 'https://mpt.ru/raspisanie-zanyatiy/',
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;

  Future<List<Teacher>> getTeachers() async {
    try {
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

      final teachers = decoded.map(Teacher.fromJson).toList();

      if (teachers.isEmpty) {
        throw Exception('Сайт МПТ не вернул список преподавателей. Возможно, страница недоступна.');
      }

      return teachers;
    } catch (e) {
      throw Exception('Ошибка при получении преподавателей: $e');
    }
  }
}
