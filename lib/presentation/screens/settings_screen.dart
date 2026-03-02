import 'dart:async';
import 'package:flutter/foundation.dart'; // Добавлен импорт для kDebugMode

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_mpt/core/services/fcm_firestore_service.dart';
import 'package:my_mpt/core/services/notification_service.dart';
import 'package:my_mpt/data/models/group.dart';
import 'package:my_mpt/data/models/specialty.dart' as data_model;
import 'package:my_mpt/data/models/teacher.dart';
import 'package:my_mpt/data/repositories/group_repository.dart';
import 'package:my_mpt/data/repositories/schedule_repository.dart';
import 'package:my_mpt/data/repositories/specialty_repository.dart';
import 'package:my_mpt/data/repositories/teacher_repository.dart';
import 'package:my_mpt/domain/repositories/group_repository_interface.dart';
import 'package:my_mpt/domain/repositories/specialty_repository_interface.dart';
import 'package:my_mpt/presentation/widgets/settings/error_notification.dart';
import 'package:my_mpt/presentation/widgets/settings/info_notification.dart';
import 'package:my_mpt/presentation/widgets/settings/section.dart';
import 'package:my_mpt/presentation/widgets/settings/settings_card.dart';
import 'package:my_mpt/presentation/widgets/settings/settings_header.dart';
import 'package:my_mpt/presentation/widgets/settings/success_notification.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _backgroundColor = Color(0xFF000000);

  late SpecialtyRepositoryInterface _specialtyRepository;
  late GroupRepositoryInterface _groupRepository;
  late TeacherRepository _teacherRepository;
  late ScheduleRepository _repository;

  List<data_model.Specialty> _specialties = [];
  List<Group> _groups = [];
  List<Teacher> _teachers = [];
  data_model.Specialty? _selectedSpecialty;
  Group? _selectedGroup;
  Teacher? _selectedTeacher;
  String? _selectedRole;

  bool _isLoading = false;
  bool _isRefreshing = false;
  DateTime? _lastUpdate;

  Timer? _refreshTimer;
  Duration _refreshElapsed = Duration.zero;

  String _appVersion = '—';

  static const String _selectedGroupKey = 'selected_group';
  static const String _selectedSpecialtyKey = 'selected_specialty';
  static const String _teacherNameKey = 'teacher';
  static const String _selectedRoleKey = 'selected_role';

  @override
  void initState() {
    super.initState();
    _specialtyRepository = SpecialtyRepository();
    _groupRepository = GroupRepository();
    _teacherRepository = TeacherRepository();
    _repository = ScheduleRepository();

    _repository.dataUpdatedNotifier.addListener(_onScheduleDataUpdated);

    _loadSpecialties();
    _loadTeachers();
    _loadSelectedPreferences();
    _loadAppVersion();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _repository.dataUpdatedNotifier.removeListener(_onScheduleDataUpdated);
    super.dispose();
  }

  Future<void> _onScheduleDataUpdated() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUpdateIso = prefs.getString('schedule_cache_last_update');

      DateTime? parsed;
      if (lastUpdateIso != null && lastUpdateIso.isNotEmpty) {
        parsed = DateTime.tryParse(lastUpdateIso);
      }

      if (!mounted) return;

      if (parsed != null) {
        setState(() => _lastUpdate = parsed);
      } else if (_repository.lastUpdate != null) {
        setState(() => _lastUpdate = _repository.lastUpdate);
      }
    } catch (_) {
      // Игнорируем ошибки при обновлении данных
    }
  }

  String _formatElapsed(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _appVersion = info.version;
      });
    } catch (e) {
      // Игнорируем ошибки загрузки версии приложения
    }
  }

  Future<void> _loadSpecialties() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final specialties = await _specialtyRepository.getSpecialties();
      final dataSpecialties = specialties
          .map((s) => data_model.Specialty(code: s.code, name: s.name))
          .toList();

      if (!mounted) return;
      setState(() {
        _specialties = dataSpecialties.cast<data_model.Specialty>();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showErrorNotification(context, 'Ошибка загрузки', 'Не удалось загрузить специальности', Icons.error_outline);
    }
  }

  Future<void> _loadSelectedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString(_selectedRoleKey) ?? 'student';
      
      final lastUpdateIso = prefs.getString('schedule_cache_last_update');
      if (lastUpdateIso != null && lastUpdateIso.isNotEmpty) {
        try { _lastUpdate = DateTime.parse(lastUpdateIso); } catch (_) {}
      }

      if (!mounted) return;

      setState(() {
        _selectedRole = role;

        if (role == 'student') {
          final selectedGroupCode = prefs.getString(_selectedGroupKey);
          final selectedSpecialtyCode = prefs.getString(_selectedSpecialtyKey);
          final selectedSpecialtyName = prefs.getString('${_selectedSpecialtyKey}_name');

          if (selectedGroupCode != null && selectedGroupCode.isNotEmpty) {
            _selectedGroup = Group(
              code: selectedGroupCode,
              specialtyCode: selectedSpecialtyCode ?? '',
              specialtyName: selectedSpecialtyName ?? '',
            );
          }

          if (selectedSpecialtyCode != null && selectedSpecialtyCode.isNotEmpty) {
            if (selectedSpecialtyName != null && selectedSpecialtyName.isNotEmpty) {
              _selectedSpecialty = data_model.Specialty(code: selectedSpecialtyCode, name: selectedSpecialtyName);
            } else if (_specialties.isNotEmpty) {
              _selectedSpecialty = _specialties.firstWhere(
                (s) => s.code == selectedSpecialtyCode,
                orElse: () => data_model.Specialty(code: '', name: ''),
              );
            }
            if (_selectedSpecialty != null && _selectedSpecialty!.code.isNotEmpty) {
              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted) _loadGroups(_selectedSpecialty!.code);
              });
            }
          }
        } else {
           final teacherName = prefs.getString(_teacherNameKey);
           if (teacherName != null && teacherName.isNotEmpty) {
             _selectedTeacher = Teacher(teacherName: teacherName);
           }
        }
      });
    } catch (e) {
      // Игнорируем ошибки при загрузке предпочтений
    }
  }

  String _getLastUpdateText() {
    if (_lastUpdate == null) return 'Расписание еще не обновлялось';
    final difference = DateTime.now().difference(_lastUpdate!);

    if (difference.inDays > 0) {
      return 'Последнее обновление: ${_lastUpdate!.day}.${_lastUpdate!.month.toString().padLeft(2, '0')} в ${_lastUpdate!.hour.toString().padLeft(2, '0')}:${_lastUpdate!.minute.toString().padLeft(2, '0')}';
    } else if (difference.inHours > 0) {
      return 'Последнее обновление: ${difference.inHours} ${_getHoursText(difference.inHours)} назад';
    } else if (difference.inMinutes > 0) {
      return 'Последнее обновление: ${difference.inMinutes} ${_getMinutesText(difference.inMinutes)} назад';
    } else {
      return 'Последнее обновление: только что';
    }
  }

  String _getHoursText(int hours) {
    if (hours % 10 == 1 && hours % 100 != 11) return 'час';
    if (hours % 10 >= 2 && hours % 10 <= 4 && (hours % 100 < 10 || hours % 100 >= 20)) return 'часа';
    return 'часов';
  }

  String _getMinutesText(int minutes) {
    if (minutes % 10 == 1 && minutes % 100 != 11) return 'минуту';
    if (minutes % 10 >= 2 && minutes % 10 <= 4 && (minutes % 100 < 10 || minutes % 100 >= 20)) return 'минуты';
    return 'минут';
  }

  Future<void> _refreshSchedule() async {
    if (!mounted) return;
    setState(() {
      _isRefreshing = true;
      _refreshElapsed = Duration.zero;
    });

    final sw = Stopwatch()..start();
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _refreshElapsed = sw.elapsed);
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      if (_selectedRole == 'student') {
        final selectedGroupCode = prefs.getString(_selectedGroupKey);
        if (selectedGroupCode == null || selectedGroupCode.isEmpty) {
          if (mounted) showInfoNotification(context, 'Выберите группу', 'Сначала выберите специальность и группу', Icons.info_outline);
          return;
        }
      } else {
        final teacherName = prefs.getString(_teacherNameKey);
        if (teacherName == null || teacherName.isEmpty) {
          if (mounted) showInfoNotification(context, 'Выберите преподавателя', 'Сначала выберите преподавателя', Icons.info_outline);
          return;
        }
      }

      final ok = await _repository.refreshAllDataWithStatus(forceRefresh: true);

      final lastUpdateIso = prefs.getString('schedule_cache_last_update');
      DateTime? parsedLastUpdate;
      if (lastUpdateIso != null && lastUpdateIso.isNotEmpty) {
        try { parsedLastUpdate = DateTime.parse(lastUpdateIso); } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _lastUpdate = parsedLastUpdate ?? _repository.lastUpdate ?? _lastUpdate;
      });

      if (mounted) {
        if (ok) {
          showSuccessNotification(context, 'Расписание обновлено', 'Данные успешно загружены', Icons.check_circle_outline);
        } else {
          showInfoNotification(context, 'Нет интернета', 'Показано последнее сохранённое расписание', Icons.wifi_off);
        }
      }
    } catch (_) {
      if (mounted) showErrorNotification(context, 'Ошибка обновления', 'Не удалось обновить расписание', Icons.error_outline);
    } finally {
      sw.stop();
      _refreshTimer?.cancel();
      _refreshTimer = null;

      if (mounted) {
        setState(() {
          _isRefreshing = false;
          _refreshElapsed = Duration.zero;
        });
      }
    }
  }

  Future<void> _changeVersion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String fromToChange = '';

      if (_selectedRole == 'student') {
        await prefs.setString(_selectedRoleKey, 'teacher');
        _selectedRole = 'teacher';
        fromToChange = 'Версия успешно изменена со студента на преподавателя';
      } else {
        await prefs.setString(_selectedRoleKey, 'student');
        _selectedRole = 'student';
        fromToChange = 'Версия успешно изменена с преподавателя на студента';
      }

      if (mounted) setState(() {});
      
      await _repository.refreshAllDataWithStatus(forceRefresh: true);
      _repository.dataUpdatedNotifier.value = !_repository.dataUpdatedNotifier.value;

      if (mounted) {
        showSuccessNotification(context, 'Версия изменена', fromToChange, Icons.check_circle_outline);
      }
    } catch (e) {
      if (mounted) showErrorNotification(context, 'Ошибка', 'Не удалось сменить версию', Icons.error_outline);
    }
  }

  Future<void> _loadGroups(String specialtyCode) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final groups = await _groupRepository.getGroupsBySpecialty(specialtyCode);
      final sortedGroups = List<Group>.from(groups);

      Group? selectedGroup;
      if (_selectedGroup != null) {
        selectedGroup = sortedGroups.firstWhere(
          (group) => group.code == _selectedGroup!.code,
          orElse: () => Group(code: '', specialtyCode: '', specialtyName: ''),
        );
        if (selectedGroup.code.isEmpty) selectedGroup = null;
      } else {
        final prefs = await SharedPreferences.getInstance();
        final savedGroupCode = prefs.getString(_selectedGroupKey);
        if (savedGroupCode != null && savedGroupCode.isNotEmpty) {
          selectedGroup = sortedGroups.firstWhere(
            (group) => group.code == savedGroupCode,
            orElse: () => Group(code: '', specialtyCode: '', specialtyName: ''),
          );
          if (selectedGroup.code.isEmpty) selectedGroup = null;
        }
      }

      if (!mounted) return;
      setState(() {
        _groups = sortedGroups;
        _isLoading = false;
        if (selectedGroup != null) _selectedGroup = selectedGroup;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showErrorNotification(context, 'Ошибка загрузки', 'Не удалось загрузить группы', Icons.error_outline);
    }
  }

  Future<void> _loadTeachers() async {
     if (!mounted) return;
     setState(() => _isLoading = true);
     try {
        final teachers = await _teacherRepository.getTeachers();
        Teacher? selectedTeacher;
        
        if (_selectedTeacher != null) {
          selectedTeacher = teachers.firstWhere(
            (t) => t.teacherName == _selectedTeacher!.teacherName,
            orElse: () => Teacher(teacherName: '')
          );
          if (selectedTeacher.teacherName.isEmpty) selectedTeacher = null;
        } else {
           final prefs = await SharedPreferences.getInstance();
           final savedTeacher = prefs.getString(_teacherNameKey);
           if (savedTeacher != null && savedTeacher.isNotEmpty) {
             selectedTeacher = teachers.firstWhere(
               (t) => t.teacherName == savedTeacher,
               orElse: () => Teacher(teacherName: '')
             );
             if (selectedTeacher.teacherName.isEmpty) selectedTeacher = null;
           }
        }
        
        if (!mounted) return;
        setState(() {
           _teachers = teachers;
           _isLoading = false;
           if (selectedTeacher != null) _selectedTeacher = selectedTeacher;
        });
     } catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        showErrorNotification(context, 'Ошибка', 'Не удалось загрузить преподавателей', Icons.error_outline);
     }
  }

  Future<void> _onSpecialtySelected(data_model.Specialty specialty) async {
    if (!mounted) return;
    setState(() {
      _selectedSpecialty = specialty;
      _groups = [];
      _selectedGroup = null;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedSpecialtyKey, specialty.code);
    await prefs.setString('${_selectedSpecialtyKey}_name', specialty.name);
    await _loadGroups(specialty.code);
  }

  void _onGroupSelected(Group group) async {
    if (!mounted) return;
    setState(() => _selectedGroup = group);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_selectedGroupKey, group.code);
      await prefs.setString(_selectedSpecialtyKey, group.specialtyCode);
      await prefs.setString('${_selectedSpecialtyKey}_name', group.specialtyName);

      try {
        final ok = await _repository.refreshAllDataWithStatus(forceRefresh: true);
        final lastUpdateIso = prefs.getString('schedule_cache_last_update');
        
        if (!mounted) return;
        
        if (lastUpdateIso != null && lastUpdateIso.isNotEmpty) {
          try { setState(() => _lastUpdate = DateTime.parse(lastUpdateIso)); } catch (_) {}
        } else if (_repository.lastUpdate != null) {
          setState(() => _lastUpdate = _repository.lastUpdate);
        }

        if (ok) _repository.dataUpdatedNotifier.value = !_repository.dataUpdatedNotifier.value;
        try { await FcmFirestoreService().syncTokenWithGroup(); } catch (_) {}

        if (mounted) {
          if (ok) {
            showSuccessNotification(context, 'Группа выбрана', 'Выбрана группа ${group.code}. Расписание обновлено.', Icons.check_circle_outline);
          } else {
            showInfoNotification(context, 'Группа выбрана', 'Выбрана группа ${group.code}. Показано сохранённое расписание (офлайн).', Icons.wifi_off);
          }
        }
      } catch (_) {
        if (mounted) showErrorNotification(context, 'Ошибка', 'Не удалось обновить расписание.', Icons.warning);
      }
    } catch (_) {
      if (mounted) showErrorNotification(context, 'Ошибка', 'Произошла ошибка при выборе группы.', Icons.error_outline);
    }
  }
  
  void _onTeacherSelected(Teacher teacher) async {
    if (!mounted) return;
    setState(() => _selectedTeacher = teacher);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_teacherNameKey, teacher.teacherName);

      try {
        final ok = await _repository.refreshAllDataWithStatus(forceRefresh: true);
        if (ok) _repository.dataUpdatedNotifier.value = !_repository.dataUpdatedNotifier.value;

        if (mounted) {
          if (ok) {
            showSuccessNotification(context, 'Преподаватель выбран', '${teacher.teacherName} • Расписание обновлено', Icons.check_circle_outline);
          } else {
            showInfoNotification(context, 'Преподаватель выбран', 'Показано сохранённое расписание (офлайн).', Icons.wifi_off);
          }
        }
      } catch (_) {
        if (mounted) showErrorNotification(context, 'Ошибка', 'Не удалось обновить расписание.', Icons.warning);
      }
    } catch (_) {
      if (mounted) showErrorNotification(context, 'Ошибка', 'Произошла ошибка при выборе преподавателя.', Icons.error_outline);
    }
  }

  Future<void> _testLocalNotification() async {
    try {
      await NotificationService().showNotification(
        'Тестовое уведомление',
        'Если вы видите это, локальные уведомления работают успешно!',
      );
      if (mounted) {
        showSuccessNotification(context, 'Успешно', 'Тестовое уведомление отправлено', Icons.notifications_active);
      }
    } catch (e) {
      if (mounted) {
        showErrorNotification(context, 'Ошибка', 'Не удалось отправить уведомление: $e', Icons.error_outline);
      }
    }
  }

  Future<void> _copyFcmToken() async {
    try {
      final token = await FcmFirestoreService().getTokenSafe();
      if (token != null && token.isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: token));
        if (mounted) {
          showSuccessNotification(
            context, 
            'FCM Токен скопирован', 
            'Вставьте его в Firebase Console для тестовой отправки Push-уведомления', 
            Icons.copy
          );
        }
      } else {
        if (mounted) {
          showErrorNotification(context, 'Ошибка', 'FCM токен недоступен или пуст', Icons.error_outline);
        }
      }
    } catch (e) {
      if (mounted) {
        showErrorNotification(context, 'Ошибка', 'Ошибка получения токена: $e', Icons.error_outline);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SettingsHeader(),
              const SizedBox(height: 28),
              if (_selectedRole == 'student') ...[
                 const Section(title: 'Учебная группа'),
                 const SizedBox(height: 14),
                 SettingsCard(
                   title: 'Выберите свою специальность',
                   subtitle: _selectedSpecialty?.name ?? 'Специальность не выбрана',
                   icon: Icons.book_outlined,
                   onTap: _showSpecialtySelector,
                 ),
                 const SizedBox(height: 14),
                 SettingsCard(
                   title: 'Выберите свою группу',
                   subtitle: _selectedGroup?.code ?? 'Группа не выбрана',
                   icon: Icons.school_outlined,
                   onTap: _selectedSpecialty != null ? _showGroupSelector : null,
                 ),
                 const SizedBox(height: 14),
                 SettingsCard(
                   title: 'Сменить версию',
                   subtitle: 'Изменить версию на преподавателя',
                   icon: Icons.change_circle_outlined,
                   onTap: _changeVersion,
                 ),
              ] else ...[
                 const Section(title: 'Преподаватель'),
                 const SizedBox(height: 14),
                 SettingsCard(
                   title: 'Выберите преподавателя',
                   subtitle: _selectedTeacher?.teacherName ?? 'Преподаватель не выбран',
                   icon: Icons.person_outline,
                   onTap: _showTeacherSelector,
                 ),
                 const SizedBox(height: 14),
                 SettingsCard(
                   title: 'Сменить версию',
                   subtitle: 'Изменить версию на студента',
                   icon: Icons.change_circle_outlined,
                   onTap: _changeVersion,
                 ),
              ],
              const SizedBox(height: 28),
              const Section(title: 'Расписание'),
              const SizedBox(height: 14),
              SettingsCard(
                title: _isRefreshing
                    ? 'Обновление… ${_formatElapsed(_refreshElapsed)}'
                    : 'Обновить расписание',
                subtitle: _getLastUpdateText(),
                icon: Icons.refresh,
                onTap: _refreshSchedule,
                isRefreshing: _isRefreshing,
              ),
              
              if (kDebugMode) ...[
                const SizedBox(height: 28),
                const Section(title: 'Уведомления (Тест)'),
                const SizedBox(height: 14),
                SettingsCard(
                  title: 'Отправить локальное уведомление',
                  subtitle: 'Проверка работы на самом устройстве',
                  icon: Icons.notifications_active_outlined,
                  onTap: _testLocalNotification,
                ),
                const SizedBox(height: 14),
                SettingsCard(
                  title: 'Скопировать FCM Токен',
                  subtitle: 'Для теста пушей через Firebase Console',
                  icon: Icons.cloud_download_outlined,
                  onTap: _copyFcmToken,
                ),
              ],

              const SizedBox(height: 28),
              const Section(title: 'Обратная связь'),
              const SizedBox(height: 14),
              SettingsCard(
                title: 'Связаться с разработчиком',
                subtitle: 'Сообщить об ошибке или предложить улучшение',
                icon: Icons.chat_outlined,
                onTap: _openSupportLink,
              ),
              const SizedBox(height: 28),
              const Section(title: 'Дополнительно'),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: _showAboutDialog,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF111111),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const ListTile(
                    leading: Icon(Icons.info_outline, color: Colors.white),
                    title: Text('О приложении', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white54),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF111111),
          title: const Text('О приложении', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Мой МПТ - Мобильное приложение для студентов и преподавателей Московского приборостроительного техникума.',
                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                const Text('Разработчики:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Студенты группы П50-1-22:', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                const Text('• Себежко Александр Андреевич', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                const Text('• Симернин Матвей Александрович', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                const Text('Студент группы СА-2-24:', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                const Text('• Посёлов Иван Павлович', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 16),
                Text('Версия: $_appVersion', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Закрыть', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openSupportLink() async {
    final Uri supportUri = Uri.parse('https://telegram.me/MptSupportBot');
    if (!await launchUrl(supportUri)) {
      if (mounted) showErrorNotification(context, 'Ошибка', 'Не удалось открыть ссылку поддержки', Icons.error_outline);
    }
  }

  void _showSpecialtySelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: const BoxDecoration(
            color: Color(0xFF111111),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(margin: const EdgeInsets.all(16), height: 4, width: 40, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
              Padding(padding: const EdgeInsets.all(16), child: Text('Выберите специальность', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold))),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Colors.white))
                    : ListView.builder(
                        itemCount: _specialties.length,
                        itemBuilder: (context, index) {
                          final specialty = _specialties[index];
                          return ListTile(
                            title: Text(specialty.name, style: const TextStyle(color: Colors.white)),
                            onTap: () { Navigator.pop(context); _onSpecialtySelected(specialty); },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showGroupSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: const BoxDecoration(
            color: Color(0xFF111111),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(margin: const EdgeInsets.all(16), height: 4, width: 40, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
              Padding(padding: const EdgeInsets.all(16), child: Text('Выберите группу', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold))),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Colors.white))
                    : _groups.isEmpty
                        ? const Center(child: Text('Группы не найдены', style: TextStyle(color: Colors.white70)))
                        : ListView.builder(
                            itemCount: _groups.length,
                            itemBuilder: (context, index) {
                              final group = _groups[index];
                              return ListTile(
                                title: Text(group.code, style: const TextStyle(color: Colors.white)),
                                onTap: () { Navigator.pop(context); _onGroupSelected(group); },
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  void _showTeacherSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: const BoxDecoration(
            color: Color(0xFF111111),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(margin: const EdgeInsets.all(16), height: 4, width: 40, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
              Padding(padding: const EdgeInsets.all(16), child: Text('Выберите преподавателя', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold))),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Colors.white))
                    : _teachers.isEmpty
                        ? const Center(child: Text('Преподаватели не найдены', style: TextStyle(color: Colors.white70)))
                        : ListView.builder(
                            itemCount: _teachers.length,
                            itemBuilder: (context, index) {
                              final teacher = _teachers[index];
                              return ListTile(
                                title: Text(teacher.teacherName, style: const TextStyle(color: Colors.white)),
                                onTap: () { Navigator.pop(context); _onTeacherSelected(teacher); },
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}
