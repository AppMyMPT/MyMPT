import 'dart:convert';

import 'package:my_mpt/domain/entities/schedule.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Модель кэша расписания
///
/// Этот класс представляет собой структуру данных для хранения
/// кэшированного расписания и метаинформации о нем
class ScheduleCache {
  /// Конструктор модели кэша
  ///
  /// Параметры:
  /// - [weeklySchedule]: Расписание на неделю
  /// - [todaySchedule]: Расписание на сегодня
  /// - [tomorrowSchedule]: Расписание на завтра
  /// - [lastUpdate]: Время последнего обновления
  ScheduleCache({
    required this.weeklySchedule,
    required this.todaySchedule,
    required this.tomorrowSchedule,
    required this.lastUpdate,
  });

  /// Расписание на неделю
  final Map<String, List<Schedule>> weeklySchedule;

  /// Расписание на сегодня
  final List<Schedule> todaySchedule;

  /// Расписание на завтра
  final List<Schedule> tomorrowSchedule;

  /// Время последнего обновления
  final DateTime lastUpdate;
}

/// Источник данных для кэширования расписания
///
/// Этот класс отвечает за сохранение и загрузку кэшированного расписания
/// в локальное хранилище устройства с помощью shared_preferences
class ScheduleCacheDataSource {
  /// Ключ для хранения расписания на неделю
  static const _weeklyKey = 'schedule_cache_weekly';

  /// Ключ для хранения расписания на сегодня
  static const _todayKey = 'schedule_cache_today';

  /// Ключ для хранения расписания на завтра
  static const _tomorrowKey = 'schedule_cache_tomorrow';

  /// Ключ для хранения времени последнего обновления
  static const _lastUpdateKey = 'schedule_cache_last_update';

  /// Сохраняет кэш расписания в локальное хранилище
  ///
  /// Метод сериализует данные расписания в JSON и сохраняет
  /// их в shared_preferences с соответствующими ключами
  ///
  /// Параметры:
  /// - [cache]: Объект кэша для сохранения
  Future<void> save(ScheduleCache cache) async {
    // Получаем экземпляр shared_preferences
    final prefs = await SharedPreferences.getInstance();
    // Сохраняем расписание на неделю
    await prefs.setString(
      _weeklyKey,
      jsonEncode(_mapToJson(cache.weeklySchedule)),
    );
    // Сохраняем расписание на сегодня
    await prefs.setString(
      _todayKey,
      jsonEncode(_listToJson(cache.todaySchedule)),
    );
    // Сохраняем расписание на завтра
    await prefs.setString(
      _tomorrowKey,
      jsonEncode(_listToJson(cache.tomorrowSchedule)),
    );
    // Сохраняем время последнего обновления
    await prefs.setString(_lastUpdateKey, cache.lastUpdate.toIso8601String());
  }

  /// Загружает кэш расписания из локального хранилища
  ///
  /// Метод извлекает сериализованные данные из shared_preferences
  /// и десериализует их в объекты приложения
  ///
  /// Возвращает:
  /// Объект кэша или null, если данные не найдены или повреждены
  Future<ScheduleCache?> load() async {
    // Получаем экземпляр shared_preferences
    final prefs = await SharedPreferences.getInstance();
    // Извлекаем сырые данные
    final weeklyRaw = prefs.getString(_weeklyKey);
    final todayRaw = prefs.getString(_todayKey);
    final tomorrowRaw = prefs.getString(_tomorrowKey);
    final lastUpdateRaw = prefs.getString(_lastUpdateKey);

    // Проверяем, что все данные присутствуют
    if (weeklyRaw == null ||
        todayRaw == null ||
        tomorrowRaw == null ||
        lastUpdateRaw == null) {
      return null;
    }

    try {
      // Десериализуем данные
      final weekly = _mapFromJson(jsonDecode(weeklyRaw));
      final today = _listFromJson(jsonDecode(todayRaw));
      final tomorrow = _listFromJson(jsonDecode(tomorrowRaw));
      final lastUpdate = DateTime.parse(lastUpdateRaw);

      // Создаем и возвращаем объект кэша
      return ScheduleCache(
        weeklySchedule: weekly,
        todaySchedule: today,
        tomorrowSchedule: tomorrow,
        lastUpdate: lastUpdate,
      );
    } catch (_) {
      // В случае ошибки возвращаем null
      return null;
    }
  }

  /// Очищает кэш расписания из локального хранилища
  ///
  /// Метод удаляет все данные кэша из shared_preferences
  Future<void> clear() async {
    // Получаем экземпляр shared_preferences
    final prefs = await SharedPreferences.getInstance();
    // Удаляем все данные кэша
    await prefs.remove(_weeklyKey);
    await prefs.remove(_todayKey);
    await prefs.remove(_tomorrowKey);
    await prefs.remove(_lastUpdateKey);
  }

  /// Преобразует Map в JSON-совместимую структуру
  ///
  /// Параметры:
  /// - [map]: Карта расписания для преобразования
  ///
  /// Возвращает:
  /// JSON-совместимая структура
  Map<String, dynamic> _mapToJson(Map<String, List<Schedule>> map) {
    return map.map((key, value) => MapEntry(key, _listToJson(value)));
  }

  /// Преобразует JSON-совместимую структуру в Map
  ///
  /// Параметры:
  /// - [json]: JSON-совместимая структура для преобразования
  ///
  /// Возвращает:
  /// Карта расписания
  Map<String, List<Schedule>> _mapFromJson(dynamic json) {
    if (json is! Map) return {};
    return json.map((key, value) {
      return MapEntry(key as String, _listFromJson(value));
    });
  }

  /// Преобразует List в JSON-совместимую структуру
  ///
  /// Параметры:
  /// - [schedules]: Список расписаний для преобразования
  ///
  /// Возвращает:
  /// JSON-совместимая структура
  List<Map<String, dynamic>> _listToJson(List<Schedule> schedules) {
    return schedules.map(_scheduleToJson).toList();
  }

  /// Преобразует JSON-совместимую структуру в List
  ///
  /// Параметры:
  /// - [json]: JSON-совместимая структура для преобразования
  ///
  /// Возвращает:
  /// Список расписаний
  List<Schedule> _listFromJson(dynamic json) {
    if (json is! List) return [];
    return json
        .whereType<Map>()
        .map((item) => _scheduleFromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  /// Преобразует Schedule в JSON-совместимую структуру
  ///
  /// Параметры:
  /// - [schedule]: Объект расписания для преобразования
  ///
  /// Возвращает:
  /// JSON-совместимая структура
  Map<String, dynamic> _scheduleToJson(Schedule schedule) {
    return {
      'id': schedule.id,
      'number': schedule.number,
      'subject': schedule.subject,
      'teacher': schedule.teacher,
      'group': schedule.group,
      'startTime': schedule.startTime,
      'endTime': schedule.endTime,
      'building': schedule.building,
      'lessonType': schedule.lessonType,
      'comment': schedule.comment,
    };
  }

  /// Преобразует JSON-совместимую структуру в Schedule
  ///
  /// Параметры:
  /// - [json]: JSON-совместимая структура для преобразования
  ///
  /// Возвращает:
  /// - Schedule: Объект расписания
  Schedule _scheduleFromJson(Map<String, dynamic> json) {
    return Schedule(
      id: json['id'] as String? ?? '',
      number: json['number'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      teacher: json['teacher'] as String? ?? '',
      group: json['group'] as String? ?? '',
      startTime: json['startTime'] as String? ?? '',
      endTime: json['endTime'] as String? ?? '',
      building: json['building'] as String? ?? '',
      lessonType: json['lessonType'] as String?,
      comment: json['comment'] as String? ?? '',
    );
  }
}
