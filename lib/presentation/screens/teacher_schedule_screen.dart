import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_mpt/core/utils/date_formatter.dart';
import 'package:my_mpt/core/utils/teacher_full_name_resolver.dart';
import 'package:my_mpt/data/repositories/schedule_repository.dart';
import 'package:my_mpt/domain/entities/schedule.dart';
import 'package:my_mpt/presentation/widgets/schedule/day_section.dart';

class TeacherScheduleScreen extends StatefulWidget {
  final String teacherName;

  const TeacherScheduleScreen({
    super.key,
    required this.teacherName,
  });

  @override
  State<TeacherScheduleScreen> createState() => _TeacherScheduleScreenState();
}

class _TeacherScheduleScreenState extends State<TeacherScheduleScreen> {
  late final ScheduleRepository _repository;
  Map<String, List<Schedule>> _schedule = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _repository = ScheduleRepository();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    setState(() => _isLoading = true);
    try {
      final schedule = await _repository.getTeacherSchedule(widget.teacherName);
      if (mounted) {
        setState(() {
          _schedule = schedule;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка загрузки расписания')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final primaryColor = isDark ? Colors.white : Colors.black87;
    final now = DateTime.now();
    final weekType = DateFormatter.getWeekType(now);
    
    final progressColor = isDark ? Colors.white : Colors.grey;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: primaryColor, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Расписание преподавателя',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              resolveTeacherFullName(widget.teacherName),
              style: TextStyle(
                color: primaryColor,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: progressColor))
          : _schedule.isEmpty
              ? Center(
                  child: Text(
                    'Расписание не найдено',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                      fontSize: 16,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
                      HapticFeedback.lightImpact();
                    }
                    await _loadSchedule();
                  },
                  color: progressColor,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.only(top: 16, bottom: 40),
                    itemCount: _schedule.length,
                    itemBuilder: (context, index) {
                      final entry = _schedule.entries.elementAt(index);
                      return DaySection(
                        title: entry.key,
                        building: '',
                        lessons: entry.value,
                        accentColor: Colors.grey,
                        weekType: weekType,
                      );
                    },
                  ),
                ),
    );
  }
}
