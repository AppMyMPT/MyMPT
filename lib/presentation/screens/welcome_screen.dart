import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_mpt/data/repositories/specialty_repository.dart';
import 'package:my_mpt/data/repositories/group_repository.dart';
import 'package:my_mpt/data/repositories/teacher_repository.dart';
import 'package:my_mpt/data/models/group.dart';
import 'package:my_mpt/data/models/teacher.dart';
import 'package:my_mpt/data/models/specialty.dart' as data_model;
import 'package:my_mpt/domain/repositories/specialty_repository_interface.dart';
import 'package:my_mpt/domain/repositories/group_repository_interface.dart';
import 'package:my_mpt/core/services/fcm_firestore_service.dart';
import 'package:my_mpt/core/services/preload_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Экран приветствия и настройки приложения
class WelcomeScreen extends StatefulWidget {
  final VoidCallback onSetupComplete;

  const WelcomeScreen({super.key, required this.onSetupComplete});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final PreloadService _preloadService = PreloadService();

  List<data_model.Specialty> _specialties = [];
  List<Group> _groups = [];
  List<Teacher> _teachers = [];

  data_model.Specialty? _selectedSpecialty;
  Group? _selectedGroup;
  Teacher? _selectedTeacher;
  
  // Роль: 'student' или 'teacher'
  String _selectedRole = 'student';

  bool _isLoading = false;
  bool _isGroupsLoading = false;
  bool _isTeachersLoading = false;

  /// Текущая страница: 
  /// 0: приветствие, 
  /// 1: выбор роли (студент/преподаватель), 
  /// 2: (Студент) выбор специальности, 
  /// 3: (Студент) выбор группы / (Преподаватель) выбор преподавателя
  int _currentPage = 0;

  static const _selectedRoleKey = 'selected_role';
  static const _selectedSpecialtyKey = 'selected_specialty';
  static const _selectedGroupKey = 'selected_group';
  // В ScheduleRepository используется ключ 'teacher', а не 'selected_teacher'
  static const _teacherNameKey = 'teacher'; 
  static const _firstLaunchKey = 'first_launch';

  late SpecialtyRepositoryInterface _specialtyRepository;
  late GroupRepositoryInterface _groupRepository;
  late TeacherRepository _teacherRepository;

  @override
  void initState() {
    super.initState();
    _specialtyRepository = SpecialtyRepository();
    _groupRepository = GroupRepository();
    _teacherRepository = TeacherRepository();
    _preloadAllData();
  }

  void _triggerHaptic() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      HapticFeedback.lightImpact();
    }
  }

  Future<void> _preloadAllData() async {
    _preloadService.preloadAllData();
  }

  Future<void> _loadSpecialties() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final specialties = await _specialtyRepository.getSpecialties();
      final dataSpecialties = specialties
          .map((s) => data_model.Specialty(code: s.code, name: s.name))
          .toList();

      setState(() {
        _specialties = dataSpecialties.cast<data_model.Specialty>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка загрузки специальностей')),
        );
      }
    }
  }

  Future<void> _loadGroups(String specialtyCode) async {
    setState(() {
      _isGroupsLoading = true;
      _groups = [];
    });

    try {
      final groups = await _groupRepository.getGroupsBySpecialty(specialtyCode);
      final sortedGroups = List<Group>.from(groups);

      setState(() {
        _groups = sortedGroups;
        _isGroupsLoading = false;

        if (_selectedGroup != null) {
          final previouslySelected = sortedGroups.firstWhere(
            (group) => group.code == _selectedGroup!.code,
            orElse: () => Group(code: '', specialtyCode: '', specialtyName: ''),
          );

          if (previouslySelected.code.isNotEmpty) {
            _selectedGroup = previouslySelected;
          } else {
            _selectedGroup = null;
          }
        }
      });
    } catch (e) {
      setState(() {
        _isGroupsLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка загрузки групп'))
        );
      }
    }
  }

  Future<void> _loadTeachers() async {
    setState(() {
      _isTeachersLoading = true;
      _teachers = [];
    });

    try {
      final teachers = await _teacherRepository.getTeachers();
      setState(() {
        _teachers = teachers;
        _isTeachersLoading = false;
        
        if (_selectedTeacher != null) {
          final previouslySelected = teachers.firstWhere(
            (t) => t.teacherName == _selectedTeacher!.teacherName,
            orElse: () => Teacher(teacherName: ''),
          );

          if (previouslySelected.teacherName.isNotEmpty) {
            _selectedTeacher = previouslySelected;
          } else {
            _selectedTeacher = null;
          }
        }
      });
    } catch (e) {
      setState(() {
        _isTeachersLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка загрузки преподавателей'))
        );
      }
    }
  }

  Future<void> _saveSelectionAndProceed() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setString(_selectedRoleKey, _selectedRole);

    if (_selectedRole == 'student') {
      if (_selectedSpecialty == null || _selectedGroup == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Пожалуйста, выберите специальность и группу')),
          );
        }
        return;
      }
      await prefs.setString(_selectedSpecialtyKey, _selectedSpecialty!.code);
      await prefs.setString('${_selectedSpecialtyKey}_name', _selectedSpecialty!.name);
      await prefs.setString(_selectedGroupKey, _selectedGroup!.code);
      
      // Сбрасываем преподавателя, если он был выбран
      await prefs.remove(_teacherNameKey);

      try {
        await FcmFirestoreService().syncTokenWithGroup();
      } catch (_) {}
      
    } else {
      if (_selectedTeacher == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Пожалуйста, выберите преподавателя')),
          );
        }
        return;
      }
      await prefs.setString(_teacherNameKey, _selectedTeacher!.teacherName);
      
      // Сбрасываем группу, если она была выбрана
      await prefs.remove(_selectedSpecialtyKey);
      await prefs.remove('${_selectedSpecialtyKey}_name');
      await prefs.remove(_selectedGroupKey);
    }

    await prefs.setBool(_firstLaunchKey, false);

    if (mounted) {
      widget.onSetupComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    
    return Scaffold(
      backgroundColor: bg,
      body: Container(
        color: bg,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: _buildPageContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildPageContent() {
    switch (_currentPage) {
      case 0:
        return _buildWelcomePage();
      case 1:
        return _buildRoleSelectionPage();
      case 2:
        return _selectedRole == 'student' 
          ? _buildSpecialtySelectionPage() 
          : _buildTeacherSelectionPage();
      case 3:
        return _buildGroupSelectionPage();
      default:
        return _buildWelcomePage();
    }
  }

  Widget _buildWelcomePage() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.white70 : Colors.black54;
    final iconBgColor = isDark ? Colors.white : Colors.black;
    final iconColor = isDark ? Colors.black : Colors.white;
    final btnBg = isDark ? Colors.white : Colors.black;
    final btnFg = isDark ? Colors.black : Colors.white;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: iconBgColor.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Center(
              child: Icon(Icons.school, size: 60, color: iconColor),
            ),
          ),
          const SizedBox(height: 40),
          Text(
            'Добро пожаловать в',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w300,
              color: primaryTextColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '"Мой МПТ"',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: primaryTextColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          Text(
            'Мы рады, что вы выбрали именно этот техникум. Мы разработали это приложение, чтобы вам было более комфортно смотреть расписание.',
            style: TextStyle(fontSize: 16, color: secondaryTextColor, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 50),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                _triggerHaptic();
                setState(() {
                  _currentPage = 1;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: btnBg,
                foregroundColor: btnFg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                elevation: 5,
              ),
              child: Text(
                'Отлично',
                style: TextStyle(
                  color: btnFg,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSelectionPage() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.white70 : Colors.black54;
    final btnBg = isDark ? Colors.white : Colors.black;
    final btnFg = isDark ? Colors.black : Colors.white;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Кто вы?',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: primaryTextColor,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          'Выберите версию для отображения расписания',
          style: TextStyle(fontSize: 16, color: secondaryTextColor),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        
        _buildRoleOption(
          title: 'Студент',
          icon: Icons.person_outline,
          value: 'student',
        ),
        const SizedBox(height: 20),
        _buildRoleOption(
          title: 'Преподаватель',
          icon: Icons.work_outline,
          value: 'teacher',
        ),

        const SizedBox(height: 50),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () {
              _triggerHaptic();
              setState(() {
                _currentPage = 2;
              });
              if (_selectedRole == 'student') {
                _loadSpecialties();
              } else {
                _loadTeachers();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: btnBg,
              foregroundColor: btnFg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              elevation: 5,
            ),
            child: Text(
              'Продолжить',
              style: TextStyle(
                color: btnFg,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: () {
            _triggerHaptic();
            setState(() {
              _currentPage = 0;
            });
          },
          style: ButtonStyle(
            overlayColor: WidgetStateProperty.all<Color>(isDark ? Colors.white30 : Colors.black12),
          ),
          child: Text(
            'Назад',
            style: TextStyle(color: secondaryTextColor, fontSize: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleOption({required String title, required IconData icon, required String value}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _selectedRole == value;
    
    final unselectedBg = isDark ? const Color(0xFF111111) : const Color(0xFFF5F5F5);
    final selectedBg = isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.05);
    
    final unselectedBorder = isDark ? Colors.white24 : Colors.black12;
    final selectedBorder = isDark ? Colors.white : Colors.black;
    
    final unselectedText = isDark ? Colors.white70 : Colors.black54;
    final selectedText = isDark ? Colors.white : Colors.black87;

    return GestureDetector(
      onTap: () {
        _triggerHaptic();
        setState(() {
          _selectedRole = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 80,
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : unselectedBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? selectedBorder : unselectedBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 20),
            Icon(
              icon, 
              color: isSelected ? selectedText : unselectedText,
              size: 32,
            ),
            const SizedBox(width: 20),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? selectedText : unselectedText,
              ),
            ),
            const Spacer(),
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(right: 20),
                child: Icon(Icons.check_circle, color: selectedText),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecialtySelectionPage() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.white70 : Colors.black54;
    final btnBg = isDark ? Colors.white : Colors.black;
    final btnFg = isDark ? Colors.black : Colors.white;
    final dropdownBg = isDark ? const Color(0xFF111111) : const Color(0xFFF5F5F5);
    final borderColor = isDark ? Colors.white24 : Colors.black12;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Выберите свою специальность',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: primaryTextColor,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 30),
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: dropdownBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: _isLoading
              ? Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(primaryTextColor),
                      strokeWidth: 2,
                    ),
                  ),
                )
              : DropdownButtonHideUnderline(
                  child: DropdownButton<data_model.Specialty>(
                    value: _selectedSpecialty,
                    hint: Text(
                      'Выберите специальность',
                      style: TextStyle(color: secondaryTextColor),
                    ),
                    items: _specialties.map((data_model.Specialty specialty) {
                      return DropdownMenuItem<data_model.Specialty>(
                        value: specialty,
                        child: Text(
                          specialty.name,
                          style: TextStyle(color: primaryTextColor),
                        ),
                      );
                    }).toList(),
                    onChanged: (data_model.Specialty? newValue) {
                      _triggerHaptic();
                      setState(() {
                        _selectedSpecialty = newValue;
                      });
                    },
                    isExpanded: true,
                    dropdownColor: dropdownBg,
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: primaryTextColor,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _selectedSpecialty != null
                ? () {
                    _triggerHaptic();
                    setState(() {
                      _currentPage = 3;
                    });
                    _loadGroups(_selectedSpecialty!.code);
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: btnBg,
              foregroundColor: btnFg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              elevation: 5,
              disabledBackgroundColor: btnBg.withValues(alpha: 0.5),
              disabledForegroundColor: btnFg.withValues(alpha: 0.5),
            ),
            child: Text(
              'Продолжить',
              style: TextStyle(
                color: btnFg,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: () {
            _triggerHaptic();
            setState(() {
              _currentPage = 1;
            });
          },
          style: ButtonStyle(
            overlayColor: WidgetStateProperty.all<Color>(isDark ? Colors.white30 : Colors.black12),
          ),
          child: Text(
            'Назад',
            style: TextStyle(color: secondaryTextColor, fontSize: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildGroupSelectionPage() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.white70 : Colors.black54;
    final btnBg = isDark ? Colors.white : Colors.black;
    final btnFg = isDark ? Colors.black : Colors.white;
    final dropdownBg = isDark ? const Color(0xFF111111) : const Color(0xFFF5F5F5);
    final borderColor = isDark ? Colors.white24 : Colors.black12;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Выберите свою группу',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: primaryTextColor,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 30),
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: dropdownBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: _isGroupsLoading
              ? Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(primaryTextColor),
                      strokeWidth: 2,
                    ),
                  ),
                )
              : DropdownButtonHideUnderline(
                  child: DropdownButton<Group>(
                    value: _selectedGroup,
                    hint: Text(
                      'Выберите группу',
                      style: TextStyle(color: secondaryTextColor),
                    ),
                    items: _groups.map((Group group) {
                      return DropdownMenuItem<Group>(
                        value: group,
                        child: Text(
                          group.code,
                          style: TextStyle(color: primaryTextColor),
                        ),
                      );
                    }).toList(),
                    onChanged: (Group? newValue) {
                      _triggerHaptic();
                      setState(() {
                        _selectedGroup = newValue;
                      });
                    },
                    isExpanded: true,
                    dropdownColor: dropdownBg,
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: primaryTextColor,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 20),
        Text(
          'Поменять группу можно в настройках',
          textAlign: TextAlign.center,
          style: TextStyle(color: secondaryTextColor, fontSize: 14),
        ),
        const SizedBox(height: 30),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _selectedGroup != null ? () {
              _triggerHaptic();
              _saveSelectionAndProceed();
            } : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: btnBg,
              foregroundColor: btnFg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              elevation: 5,
              disabledBackgroundColor: btnBg.withValues(alpha: 0.5),
              disabledForegroundColor: btnFg.withValues(alpha: 0.5),
            ),
            child: Text(
              'Готово',
              style: TextStyle(
                color: btnFg,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: () {
            _triggerHaptic();
            setState(() {
              _currentPage = 2; // Возврат к выбору специальности
            });
          },
          style: ButtonStyle(
            overlayColor: WidgetStateProperty.all<Color>(isDark ? Colors.white30 : Colors.black12),
          ),
          child: Text(
            'Назад',
            style: TextStyle(color: secondaryTextColor, fontSize: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildTeacherSelectionPage() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.white70 : Colors.black54;
    final btnBg = isDark ? Colors.white : Colors.black;
    final btnFg = isDark ? Colors.black : Colors.white;
    final dropdownBg = isDark ? const Color(0xFF111111) : const Color(0xFFF5F5F5);
    final borderColor = isDark ? Colors.white24 : Colors.black12;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Выберите преподавателя',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: primaryTextColor,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 30),
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: dropdownBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: _isTeachersLoading
              ? Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(primaryTextColor),
                      strokeWidth: 2,
                    ),
                  ),
                )
              : DropdownButtonHideUnderline(
                  child: DropdownButton<Teacher>(
                    value: _selectedTeacher,
                    hint: Text(
                      'Выберите преподавателя',
                      style: TextStyle(color: secondaryTextColor),
                    ),
                    items: _teachers.map((Teacher teacher) {
                      return DropdownMenuItem<Teacher>(
                        value: teacher,
                        child: Text(
                          teacher.teacherName,
                          style: TextStyle(color: primaryTextColor),
                        ),
                      );
                    }).toList(),
                    onChanged: (Teacher? newValue) {
                      _triggerHaptic();
                      setState(() {
                        _selectedTeacher = newValue;
                      });
                    },
                    isExpanded: true,
                    dropdownColor: dropdownBg,
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: primaryTextColor,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 20),
        Text(
          'Изменить версию и преподавателя можно в настройках',
          textAlign: TextAlign.center,
          style: TextStyle(color: secondaryTextColor, fontSize: 14),
        ),
        const SizedBox(height: 30),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _selectedTeacher != null ? () {
              _triggerHaptic();
              _saveSelectionAndProceed();
            } : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: btnBg,
              foregroundColor: btnFg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              elevation: 5,
              disabledBackgroundColor: btnBg.withValues(alpha: 0.5),
              disabledForegroundColor: btnFg.withValues(alpha: 0.5),
            ),
            child: Text(
              'Готово',
              style: TextStyle(
                color: btnFg,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: () {
            _triggerHaptic();
            setState(() {
              _currentPage = 1; // Возврат к выбору роли
            });
          },
          style: ButtonStyle(
            overlayColor: WidgetStateProperty.all<Color>(isDark ? Colors.white30 : Colors.black12),
          ),
          child: Text(
            'Назад',
            style: TextStyle(color: secondaryTextColor, fontSize: 16),
          ),
        ),
      ],
    );
  }
}
