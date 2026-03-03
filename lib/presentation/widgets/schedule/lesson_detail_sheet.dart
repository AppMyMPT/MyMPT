import 'package:flutter/material.dart';
import 'package:my_mpt/core/utils/teacher_full_name_resolver.dart';
import 'package:my_mpt/domain/entities/schedule.dart';

/// Нижняя панель с информацией о паре: название, время, преподаватель
/// и кнопка «Посмотреть расписание преподавателя».
/// [startTime] и [endTime] — время с карточки (из расписания звонков); если не переданы, берутся из [lesson].
void showLessonDetailSheet(
  BuildContext context, {
  required Schedule lesson,
  required VoidCallback onViewTeacherSchedule,
  String? startTime,
  String? endTime,
}) {
  final displayStart = startTime ?? lesson.startTime;
  final displayEnd = endTime ?? lesson.endTime;
  final timeText = (displayStart.isNotEmpty && displayEnd.isNotEmpty)
      ? '$displayStart – $displayEnd'
      : (displayStart.isNotEmpty ? displayStart : (displayEnd.isNotEmpty ? displayEnd : '—'));
  final teacherDisplayName = resolveTeacherFullName(lesson.teacher);

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF1A1A1A),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              lesson.subject,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.access_time, size: 18, color: Colors.white70),
                const SizedBox(width: 8),
                Text(
                  timeText,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person_outline, size: 18, color: Colors.white70),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    teacherDisplayName,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                onViewTeacherSchedule();
              },
              icon: const Icon(Icons.calendar_today_outlined, size: 20),
              label: const Text('Посмотреть расписание преподавателя'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF333333),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
