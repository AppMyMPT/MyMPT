import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'package:my_mpt/data/parsers/speciality_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SpecialityRemoteDatasource {
  SpecialityRemoteDatasource({
    http.Client? client,
    this.baseUrl = 'https://mpt.ru/raspisanie/',
    this.cacheTtl = const Duration(hours: 24),
    SpecialityParser? specialityParser,
  }) : _client = client ?? http.Client(),
       _specialityParser = specialityParser ?? SpecialityParser();

  final http.Client _client;
  final SpecialityParser _specialityParser;
  final String baseUrl;
  final Duration cacheTtl;

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

      final response = await _client
          .get(Uri.parse(baseUrl))
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Превышено время ожидания ответа от сервера');
            },
          );

      if (response.statusCode == 200) {
        final document = parse(response.body);
        final tabs = _specialityParser.parse(document);

        if (tabs.isEmpty) {
          throw Exception('Сайт МПТ не вернул список специальностей.');
        }

        await _saveCachedTabs(tabs);
        return tabs;
      } else {
        throw Exception(
          'Не удалось загрузить страницу: ${response.statusCode}',
        );
      }
    } catch (e) {
      // Если принудительное обновление не удалось, пробуем отдать старый кэш
      final fallbackCache = await _getCachedTabs(ignoreTtl: true);
      if (fallbackCache != null && fallbackCache.isNotEmpty) {
        return fallbackCache;
      }
      throw Exception('Ошибка при парсинге списка вкладок: $e');
    }
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
        } else {
          if (!ignoreTtl) {
            await prefs.remove(_cacheKeyTabs);
            await prefs.remove(_cacheKeyTabsTimestamp);
          }
        }
      }
    } catch (e) {
      // Игнорируем ошибки кэша
    }
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
    } catch (e) {
      // Игнорируем ошибки кэша
    }
  }
}
