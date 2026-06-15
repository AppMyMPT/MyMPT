import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:my_mpt/data/models/replacement.dart';
import 'package:my_mpt/data/parsers/replacement_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Сервис для парсинга замен в расписании с сайта МПТ
///
/// Этот сервис отвечает за извлечение информации о заменах в расписании
/// с официального сайта техникума mpt.ru/izmeneniya-v-raspisanii/
class ReplacementRemoteDatasource {
  /// Базовый URL страницы с изменениями в расписании
  final String baseUrl = 'https://mpt.ru/izmeneniya-v-raspisanii/';

  /// Парсер замен
  final ReplacementParser _replacementParser = ReplacementParser();

  /// Время жизни кэша (15 минут для замен)
  static const Duration _cacheTtl = Duration(minutes: 15);

  /// Ключи для кэширования
  static const String _cacheKeyChanges = 'replacements_';
  static const String _cacheKeyChangesTimestamp = 'replacements_timestamp_';

  /// Парсит замены в расписании для конкретной группы
  ///
  /// Метод извлекает HTML-страницу с заменами в расписании и находит
  /// все замены, относящиеся к указанной группе, на сегодня и завтра
  ///
  /// Параметры:
  /// - [groupCode]: Код группы для которой нужно получить изменения
  /// - [forceRefresh]: Принудительное обновление без использования кэша
  ///
  /// Возвращает:
  /// Список замен в расписании для группы
  Future<List<Replacement>> parseScheduleChangesForGroup(
    String groupCode, {
    bool forceRefresh = false,
  }) async {
    try {
      // Проверяем кэш замен
      if (!forceRefresh) {
        final cachedChanges = await _getCachedChanges(groupCode);
        if (cachedChanges != null) {
          return cachedChanges;
        }
      }

      // Отправляем HTTP-запрос к странице замен в расписании
      final response = await http
          .get(Uri.parse(baseUrl))
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw Exception(
                'Превышено время ожидания ответа от сервера (15 секунд)',
              );
            },
          );

      // Проверяем успешность запроса
      if (response.statusCode == 200) {
        // Парсим HTML документ с помощью библиотеки html
        final document = parser.parse(response.body);

        // Парсим замены с помощью парсера
        final changes = _replacementParser.parseScheduleChangesForGroup(
          document,
          groupCode,
        );

        // Сохраняем замены в кэш
        await _saveCachedChanges(groupCode, changes);

        return changes;
      } else {
        throw Exception(
          'Не удалось загрузить страницу: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception(
        'Ошибка при парсинге изменений для группы $groupCode: $e',
      );
    }
  }

  /// Парсит замены в расписании для конкретного преподавателя.
  Future<List<Replacement>> parseScheduleChangesForTeacher(
    String teacherName, {
    bool forceRefresh = false,
  }) async {
    try {
      final cacheScope = 'teacher_${teacherName.trim().toLowerCase()}';
      if (!forceRefresh) {
        final cachedChanges = await _getCachedChanges(cacheScope);
        if (cachedChanges != null) {
          return cachedChanges;
        }
      }

      final response = await http
          .get(Uri.parse(baseUrl))
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw Exception(
                'Превышено время ожидания ответа от сервера (15 секунд)',
              );
            },
          );

      if (response.statusCode == 200) {
        final document = parser.parse(response.body);
        final changes = _replacementParser.parseScheduleChangesForTeacher(
          document,
          teacherName,
        );

        await _saveCachedChanges(cacheScope, changes);
        return changes;
      } else {
        throw Exception(
          'Не удалось загрузить страницу: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception(
        'Ошибка при парсинге изменений для преподавателя $teacherName: $e',
      );
    }
  }

  /// Получает кэшированные замены из хранилища
  Future<List<Replacement>?> _getCachedChanges(String groupCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cacheKeyChanges${groupCode.hashCode}';
      final timestampKey = '$_cacheKeyChangesTimestamp${groupCode.hashCode}';

      final timestamp = prefs.getInt(timestampKey);
      final cachedJson = prefs.getString(cacheKey);

      if (timestamp != null && cachedJson != null) {
        final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final now = DateTime.now();
        final age = now.difference(cacheTime);

        if (age < _cacheTtl) {
          // Кэш действителен, возвращаем данные
          final List<dynamic> decoded = jsonDecode(cachedJson);
          return decoded
              .map(
                (json) => Replacement(
                  lessonNumber: json['lessonNumber'] as String,
                  replaceFrom: json['replaceFrom'] as String,
                  replaceTo: json['replaceTo'] as String,
                  updatedAt: json['updatedAt'] as String,
                  changeDate: json['changeDate'] as String,
                  group: json['group'] as String? ?? '',
                ),
              )
              .toList();
        } else {
          // Кэш истек, очищаем устаревшие данные
          await prefs.remove(cacheKey);
          await prefs.remove(timestampKey);
        }
      }
    } catch (e) {
      // Игнорируем ошибки кэша
    }
    return null;
  }

  /// Сохраняет замены в кэш
  Future<void> _saveCachedChanges(
    String groupCode,
    List<Replacement> changes,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cacheKeyChanges${groupCode.hashCode}';
      final timestampKey = '$_cacheKeyChangesTimestamp${groupCode.hashCode}';

      final json = jsonEncode(
        changes.map((change) => change.toJson()).toList(),
      );
      await prefs.setString(cacheKey, json);
      await prefs.setInt(timestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      // Игнорируем ошибки кэша
    }
  }
}
