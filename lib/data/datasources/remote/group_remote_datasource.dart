import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as parser;
import 'package:http/http.dart' as http;
import 'package:my_mpt/data/models/group.dart';
import 'package:my_mpt/data/parsers/group_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// message -> {'html': String, 'specialtyFilter': String?}
List<Map<String, dynamic>> _parseGroupsIsolate(Map<String, dynamic> message) {
  final html = message['html'] as String? ?? '';
  final filter = message['specialtyFilter'] as String?;
  final document = parser.parse(html);

  final groups = GroupParser().parseGroups(document, filter);

  return groups
      .whereType<Group>()
      .map((g) => g.toJson())
      .toList();
}

/// Сервис для парсинга групп с сайта МПТ
class GroupRemoteDatasource {
  GroupRemoteDatasource({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Базовый URL сайта с расписанием
  final String baseUrl = 'https://mpt.ru/raspisanie/';

  /// Время жизни кэша (24 часа)
  static const Duration _cacheTtl = Duration(hours: 24);

  /// Ключи для кэширования
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
      // Если принудительное обновление не удалось, пробуем отдать кэш, даже если он старый
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

      final decoded = await compute(
        _parseGroupsIsolate,
        {'html': html, 'specialtyFilter': specialtyFilter},
      );

      final groups = decoded.map(Group.fromJson).toList();

      if (groups.isEmpty) {
        throw Exception('Сайт МПТ не вернул список групп для специальности "$specialtyFilter".');
      }

      await _saveCachedGroups(specialtyFilter, groups);
      return groups;
    } catch (e) {
      // Если принудительное обновление не удалось, пробуем отдать кэш
      final fallbackCache = await _getCachedGroups(specialtyFilter, ignoreTtl: true);
      if (fallbackCache != null && fallbackCache.isNotEmpty) {
        return fallbackCache;
      }
      throw Exception('Ошибка при парсинге групп для специальности "$specialtyFilter": $e');
    }
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
              .map(
                (json) => Group.fromJson(json as Map<String, dynamic>),
              )
              .toList();
              
          if (result.isNotEmpty) return result;
        } else {
          // Удаляем только если TTL истек и мы не игнорируем TTL (во время обычной загрузки)
          if (!ignoreTtl) {
            await prefs.remove(cacheKey);
            await prefs.remove(timestampKey);
          }
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
