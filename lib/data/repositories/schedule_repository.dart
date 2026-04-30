import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:my_mpt/data/datasources/cache/schedule_cache_data_source.dart';
import 'package:my_mpt/data/datasources/remote/schedule_remote_datasource.dart';
import 'package:my_mpt/domain/entities/schedule.dart';
import 'package:my_mpt/domain/repositories/schedule_repository_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ScheduleRefreshFailureReason {
  none,
  selectionNotChosen,
  noInternet,
  sourceUnavailable,
  unknown,
}

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
  ScheduleRefreshFailureReason _lastFailureReason = ScheduleRefreshFailureReason.none;

  static const Duration _failedRefreshCooldown = Duration(seconds: 45);

  Future<bool>? _refreshInFlight;
  bool _refreshInFlightForce = false;

  final ValueNotifier<bool> dataUpdatedNotifier = ValueNotifier<bool>(false);

  static final ScheduleRepository _instance = ScheduleRepository._internal();
  factory ScheduleRepository() => _instance;
  ScheduleRepository._internal();

  DateTime? get lastUpdate => _lastUpdate;

  bool get isOfflineBadgeVisible => !_lastRefreshSucceeded && _lastUpdate != null;

  DateTime? get lastFailedRefreshAttempt => _lastFailedRefreshAttempt;
  ScheduleRefreshFailureReason get lastFailureReason => _lastFailureReason;

  @override
  Future<Map<String, List<Schedule>>> getWeeklySchedule() async {
    await _restoreCacheIfNeeded();

    final hasLocalData = _cachedWeeklySchedule != null;
    final needRefresh = _shouldRefreshData() || !hasLocalData;
    final canTryRefresh = !hasLocalData || !_isInFailedCooldown();

    if (needRefresh && canTryRefresh) {
      if (hasLocalData) {
        unawaited(refreshAllDataWithStatus(forceRefresh: false));
      } else {
        await refreshAllDataWithStatus(forceRefresh: false);
      }
    }

    return _cachedWeeklySchedule ?? {};
  }

  @override
  Future<List<Schedule>> getTodaySchedule() async {
    await _restoreCacheIfNeeded();

    final hasLocalData = _cachedTodaySchedule != null;
    final needRefresh = _shouldRefreshData() || !hasLocalData;
    final canTryRefresh = !hasLocalData || !_isInFailedCooldown();

    if (needRefresh && canTryRefresh) {
      if (hasLocalData) {
        unawaited(refreshAllDataWithStatus(forceRefresh: false));
      } else {
        await refreshAllDataWithStatus(forceRefresh: false);
      }
    }

    return _cachedTodaySchedule ?? [];
  }

  @override
  Future<List<Schedule>> getTomorrowSchedule() async {
    await _restoreCacheIfNeeded();

    final hasLocalData = _cachedTomorrowSchedule != null;
    final needRefresh = _shouldRefreshData() || !hasLocalData;
    final canTryRefresh = !hasLocalData || !_isInFailedCooldown();

    if (needRefresh && canTryRefresh) {
      if (hasLocalData) {
        unawaited(refreshAllDataWithStatus(forceRefresh: false));
      } else {
        await refreshAllDataWithStatus(forceRefresh: false);
      }
    }

    return _cachedTomorrowSchedule ?? [];
  }

  Future<Map<String, List<Schedule>>> getWeeklyScheduleForTeacher(String teacherName) async {
    if (teacherName.trim().isEmpty) return {};
    try {
      final parsedSchedule = await _remoteDatasource.fetchWeeklySchedule(
        teacherName.trim(),
        forceRefresh: true,
        isTeacher: true,
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
      return weeklySchedule;
    } catch (e) {
      debugPrint('Ошибка загрузки расписания преподавателя "$teacherName": $e');
      return {};
    }
  }

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
    return DateTime.now().difference(_lastFailedRefreshAttempt!) < _failedRefreshCooldown;
  }

  Future<bool> _refreshAllData({required bool forceRefresh}) {
    final inFlight = _refreshInFlight;
    if (inFlight != null) {
      if (forceRefresh && !_refreshInFlightForce) {
        return inFlight.then((_) => _refreshAllData(forceRefresh: true));
      }
      return inFlight;
    }

    final completer = Completer<bool>();
    _refreshInFlight = completer.future;
    _refreshInFlightForce = forceRefresh;

    () async {
      try {
        final ok = await _refreshAllDataInternal(forceRefresh: forceRefresh);
        completer.complete(ok);
      } catch (_) {
        completer.complete(false);
      } finally {
        _refreshInFlight = null;
        _refreshInFlightForce = false;
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
        await _clearCache();
        _lastRefreshSucceeded = false;
        _lastFailureReason = ScheduleRefreshFailureReason.selectionNotChosen;
        return false;
      }

      final parsedSchedule = await _remoteDatasource.fetchWeeklySchedule(
        targetName,
        forceRefresh: forceRefresh,
        isTeacher: isTeacher,
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
      _lastFailureReason = ScheduleRefreshFailureReason.none;

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
      _lastFailureReason = _classifyRefreshError(e);
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
    _lastFailureReason = ScheduleRefreshFailureReason.none;

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
      _cachedTodaySchedule = (_cachedWeeklySchedule ?? {})[_getTodayInRussian()] ?? [];
      _cachedTomorrowSchedule = (_cachedWeeklySchedule ?? {})[_getTomorrowInRussian()] ?? [];
      _lastUpdate = cache.lastUpdate;

      _lastRefreshSucceeded = true;
      _lastFailureReason = ScheduleRefreshFailureReason.none;
    } catch (_) {
      _cachedWeeklySchedule = null;
      _cachedTodaySchedule = null;
      _cachedTomorrowSchedule = null;
      _lastUpdate = null;
      _lastRefreshSucceeded = false;
      _lastFailureReason = ScheduleRefreshFailureReason.unknown;
    }
  }

  ScheduleRefreshFailureReason _classifyRefreshError(Object error) {
    final text = error.toString().toLowerCase();

    if (text.contains('socketexception') ||
        text.contains('failed host lookup') ||
        text.contains('network is unreachable') ||
        text.contains('connection refused') ||
        text.contains('connection reset') ||
        text.contains('timeoutexception')) {
      return ScheduleRefreshFailureReason.noInternet;
    }

    if (text.contains('httpexception') ||
        text.contains('statuscode') ||
        text.contains('status code') ||
        text.contains('превышено время ожидания') ||
        text.contains('handshakeexception') ||
        text.contains('cert_has_expired') ||
        text.contains('certificate has expired') ||
        text.contains('certificate_verify_failed') ||
        text.contains('x509') ||
        text.contains('технические работы') ||
        text.contains('защита от ботов')) {
      return ScheduleRefreshFailureReason.sourceUnavailable;
    }

    return ScheduleRefreshFailureReason.unknown;
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
