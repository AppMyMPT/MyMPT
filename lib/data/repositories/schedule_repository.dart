import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:my_mpt/data/datasources/cache/schedule_cache_data_source.dart';
import 'package:my_mpt/data/datasources/remote/schedule_remote_datasource.dart';
import 'package:my_mpt/domain/entities/schedule.dart';
import 'package:my_mpt/domain/repositories/schedule_repository_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScheduleRepository implements ScheduleRepositoryInterface {
  final ScheduleRemoteDatasource _remoteDatasource = ScheduleRemoteDatasource();
  final ScheduleCacheDataSource _cacheDataSource = ScheduleCacheDataSource();

  static const String _selectedGroupKey = 'selected_group';
  static const String _selectedRoleKey = 'selected_role';
  static const String _teacherNameKey = 'teacher';

  Map<String, List<Schedule>>? _cachedWeeklySchedule;
  List<Schedule>? _cachedTodaySchedule;
  List<Schedule>? _cachedTomorrowSchedule;

  DateTime? _lastUpdate;
  DateTime? _lastFailedRefreshAttempt;
  bool _cacheInitialized = false;
  bool _lastRefreshSucceeded = true;

  static const Duration _failedRefreshCooldown = Duration(minutes: 10);

  /// Дедупликация обновления: если refresh уже идёт — ждём тот же Future.
  Future<bool>? _refreshInFlight;

  final ValueNotifier<bool> dataUpdatedNotifier = ValueNotifier<bool>(false);

  static final ScheduleRepository _instance = ScheduleRepository._internal();
  factory ScheduleRepository() => _instance;
  ScheduleRepository._internal();

  DateTime? get lastUpdate => _lastUpdate;

  bool get isOfflineBadgeVisible => !_lastRefreshSucceeded && _lastUpdate != null;

  DateTime? get lastFailedRefreshAttempt => _lastFailedRefreshAttempt;

  @override
  Future<Map<String, List<Schedule>>> getWeeklySchedule() async {
    await _restoreCacheIfNeeded();

    final needRefresh = _shouldRefreshData() || _cachedWeeklySchedule == null;
    final canTryRefresh = !_isInFailedCooldown() || _cachedWeeklySchedule == null;

    if (needRefresh && canTryRefresh) {
      await _refreshAllData(forceRefresh: false);
    }

    return _cachedWeeklySchedule ?? {};
  }

  @override
  Future<List<Schedule>> getTodaySchedule() async {
    await _restoreCacheIfNeeded();

    final needRefresh = _shouldRefreshData() || _cachedTodaySchedule == null;
    final canTryRefresh = !_isInFailedCooldown() || _cachedTodaySchedule == null;

    if (needRefresh && canTryRefresh) {
      await _refreshAllData(forceRefresh: false);
    }

    return _cachedTodaySchedule ?? [];
  }

  @override
  Future<List<Schedule>> getTomorrowSchedule() async {
    await _restoreCacheIfNeeded();

    final needRefresh = _shouldRefreshData() || _cachedTomorrowSchedule == null;
    final canTryRefresh =
        !_isInFailedCooldown() || _cachedTomorrowSchedule == null;

    if (needRefresh && canTryRefresh) {
      await _refreshAllData(forceRefresh: false);
    }

    return _cachedTomorrowSchedule ?? [];
  }

  /// Совместимость: старый публичный метод остаётся.
  Future<void> refreshAllData() async {
    await refreshAllDataWithStatus(forceRefresh: true);
  }

  Future<bool> refreshAllDataWithStatus({bool forceRefresh = false}) async {
    await _restoreCacheIfNeeded();
    final ok = await _refreshAllData(forceRefresh: forceRefresh);
    if (ok) {
      dataUpdatedNotifier.value = !dataUpdatedNotifier.value;
    }
    return ok;
  }

  /// Совместимость: старый метод оставляем (используется в OverviewScreen),
  /// но "красивый" статус даём отдельным методом.
  Future<void> forceRefresh() async {
    await forceRefreshWithStatus();
  }

  Future<bool> forceRefreshWithStatus() async {
    return refreshAllDataWithStatus(forceRefresh: true);
  }

  bool _shouldRefreshData() {
    if (_lastUpdate == null) return true;
    return DateTime.now().difference(_lastUpdate!).inHours >= 24;
  }

  bool _isInFailedCooldown() {
    if (_lastFailedRefreshAttempt == null) return false;
    return DateTime.now().difference(_lastFailedRefreshAttempt!) <
        _failedRefreshCooldown;
  }

  /// Дедупликация: если уже обновляемся — не стартуем второй запрос.
  Future<bool> _refreshAllData({required bool forceRefresh}) {
    final inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight;

    final completer = Completer<bool>();
    _refreshInFlight = completer.future;

    () async {
      try {
        final ok = await _refreshAllDataInternal(forceRefresh: forceRefresh);
        completer.complete(ok);
      } catch (_) {
        completer.complete(false);
      } finally {
        _refreshInFlight = null;
      }
    }();

    return _refreshInFlight!;
  }

  Future<bool> _refreshAllDataInternal({required bool forceRefresh}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString(_selectedRoleKey) ?? 'student';
      
      String targetName = '';
      bool isTeacher = false;
      
      if (role == 'student') {
         targetName = await _getSelectedGroupCode();
      } else {
         targetName = prefs.getString(_teacherNameKey) ?? '';
         isTeacher = true;
      }

      if (targetName.isEmpty) {
        await _clearCache(); // тут реально нечего показывать
        _lastRefreshSucceeded = false;
        return false;
      }

      final parsedSchedule = await _remoteDatasource.fetchWeeklySchedule(
        targetName,
        forceRefresh: forceRefresh,
        isTeacher: isTeacher
      );

      final Map<String, List<Schedule>> weeklySchedule = {};
      parsedSchedule.forEach((day, lessons) {
        weeklySchedule[day] = lessons.map((lesson) {
          return Schedule(
            id: '${day}_${lesson.number}',
            number: lesson.number,
            subject: lesson.subject,
            teacher: lesson.teacher,
            startTime: lesson.startTime,
            endTime: lesson.endTime,
            building: lesson.building,
            lessonType: lesson.lessonType,
          );
        }).toList();
      });

      _cachedWeeklySchedule = weeklySchedule;
      _cachedTodaySchedule = weeklySchedule[_getTodayInRussian()] ?? [];
      _cachedTomorrowSchedule = weeklySchedule[_getTomorrowInRussian()] ?? [];

      _lastUpdate = DateTime.now();
      _lastFailedRefreshAttempt = null;
      _lastRefreshSucceeded = true;

      await _cacheDataSource.save(
        ScheduleCache(
          weeklySchedule: _cachedWeeklySchedule ?? {},
          todaySchedule: _cachedTodaySchedule ?? [],
          tomorrowSchedule: _cachedTomorrowSchedule ?? [],
          lastUpdate: _lastUpdate!,
        ),
      );

      return true;
    } catch (e) {
      debugPrint('Ошибка при обновлении данных расписания: $e');
      _lastFailedRefreshAttempt = DateTime.now();
      _lastRefreshSucceeded = false;

      // Ключевой момент: кэш НЕ очищаем — офлайн-просмотр сохраняется.
      return false;
    }
  }

  Future<void> _clearCache() async {
    _cachedWeeklySchedule = null;
    _cachedTodaySchedule = null;
    _cachedTomorrowSchedule = null;
    _lastUpdate = null;
    _lastFailedRefreshAttempt = null;
    _lastRefreshSucceeded = false;

    _remoteDatasource.clearCache();
    _cacheInitialized = false;
    await _cacheDataSource.clear();
  }

  Future<void> _restoreCacheIfNeeded() async {
    if (_cacheInitialized) return;
    _cacheInitialized = true;

    try {
      final cache = await _cacheDataSource.load();
      if (cache == null) return;

      _cachedWeeklySchedule = cache.weeklySchedule;
      // today/tomorrow теперь считаем из weekly (без дублей в prefs).
      _cachedTodaySchedule = (_cachedWeeklySchedule ?? {})[_getTodayInRussian()] ?? [];
      _cachedTomorrowSchedule = (_cachedWeeklySchedule ?? {})[_getTomorrowInRussian()] ?? [];
      _lastUpdate = cache.lastUpdate;

      // Если у нас есть кэш — считаем, что "данные есть", даже если сеть потом пропадёт.
      _lastRefreshSucceeded = true;
    } catch (_) {
      _cachedWeeklySchedule = null;
      _cachedTodaySchedule = null;
      _cachedTomorrowSchedule = null;
      _lastUpdate = null;
      _lastRefreshSucceeded = false;
    }
  }

  Future<String> _getSelectedGroupCode() async {
    try {
      const envGroup = String.fromEnvironment('SELECTED_GROUP');
      if (envGroup.isNotEmpty) return envGroup;

      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_selectedGroupKey) ?? '';
    } catch (e) {
      debugPrint('Ошибка получения выбранной группы из настроек: $e');
      return '';
    }
  }

  String _getTodayInRussian() {
    final now = DateTime.now();
    const weekdays = [
      'ПОНЕДЕЛЬНИК',
      'ВТОРНИК',
      'СРЕДА',
      'ЧЕТВЕРГ',
      'ПЯТНИЦА',
      'СУББОТА',
      'ВОСКРЕСЕНЬЕ',
    ];
    return weekdays[now.weekday - 1];
  }

  String _getTomorrowInRussian() {
    final now = DateTime.now().add(const Duration(days: 1));
    const weekdays = [
      'ПОНЕДЕЛЬНИК',
      'ВТОРНИК',
      'СРЕДА',
      'ЧЕТВЕРГ',
      'ПЯТНИЦА',
      'СУББОТА',
      'ВОСКРЕСЕНЬЕ',
    ];
    return weekdays[now.weekday - 1];
  }
}
