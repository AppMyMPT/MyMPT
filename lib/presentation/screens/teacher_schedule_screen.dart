import 'package:flutter/material.dart';
import 'package:my_mpt/core/utils/date_formatter.dart';
import 'package:my_mpt/data/repositories/schedule_repository.dart';
import 'package:my_mpt/domain/entities/schedule.dart';
import 'package:my_mpt/presentation/widgets/schedule/day_section.dart';

/// Экран расписания преподавателя (открывается из расписания студента по кнопке «Посмотреть расписание преподавателя»).
/// По жесту «назад» возвращает на расписание студента.
class TeacherScheduleScreen extends StatefulWidget {
  const TeacherScheduleScreen({super.key, required this.teacherName});

  final String teacherName;

  @override
  State<TeacherScheduleScreen> createState() => _TeacherScheduleScreenState();
}

class _TeacherScheduleScreenState extends State<TeacherScheduleScreen> {
  final ScheduleRepository _repository = ScheduleRepository();
  Map<String, List<Schedule>> _weeklySchedule = {};
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final weekly = await _repository.getWeeklyScheduleForTeacher(widget.teacherName);
      if (!mounted) return;
      setState(() {
        _weeklySchedule = weekly;
        _isLoading = false;
        if (weekly.isEmpty) _loadError = 'Расписание не найдено';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Ошибка загрузки';
      });
    }
  }

  String _primaryBuilding(List<Schedule> schedule) {
    if (schedule.isEmpty) return '';
    final Map<String, int> counts = {};
    for (final lesson in schedule) {
      counts[lesson.building] = (counts[lesson.building] ?? 0) + 1;
    }
    String primary = schedule.first.building;
    int maxCount = 0;
    counts.forEach((building, count) {
      if (count > maxCount) {
        maxCount = count;
        primary = building;
      }
    });
    return primary;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekType = DateFormatter.getWeekType(now) ?? '';
    final days = _weeklySchedule.entries.toList();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final bgColor = theme.scaffoldBackgroundColor;
    final fgColor = isDark ? Colors.white : Colors.black87;
    final errorColor = isDark ? Colors.white.withValues(alpha: 0.8) : Colors.black87;
    final hintColor = isDark ? Colors.white70 : Colors.black54;

    // Use primary color of the theme as accent for the teacher's schedule lessons
    final accentColor = isDark ? Colors.grey : Colors.grey.shade400;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          widget.teacherName,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: fgColor,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: fgColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: theme.colorScheme.primary),
            )
          : _loadError != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _loadError!,
                        style: TextStyle(
                          color: errorColor,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: _loadSchedule,
                        icon: Icon(Icons.refresh, color: hintColor),
                        label: Text('Повторить', style: TextStyle(color: hintColor)),
                      ),
                    ],
                  ),
                )
              : days.isEmpty
                  ? Center(
                      child: Text(
                        'Нет занятий',
                        style: TextStyle(
                          color: hintColor,
                          fontSize: 16,
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadSchedule,
                      color: theme.colorScheme.primary,
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: days.length,
                        itemBuilder: (context, index) {
                          final day = days[index];
                          return DaySection(
                            title: day.key,
                            building: _primaryBuilding(day.value),
                            lessons: day.value,
                            accentColor: accentColor,
                            weekType: weekType,
                          );
                        },
                      ),
                    ),
    );
  }
}
