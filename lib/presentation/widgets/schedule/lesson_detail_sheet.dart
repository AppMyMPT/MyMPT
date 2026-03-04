import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final cs = theme.colorScheme;

  final bgColor = cs.surface;
  final titleColor = isDark ? Colors.white : Colors.black87;
  final subtitleColor = isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87;
  final iconColor = isDark ? Colors.white70 : Colors.black54;

  final buttonBg = isDark ? const Color(0xFF333333) : Colors.black.withOpacity(0.08);
  final buttonFg = isDark ? Colors.white : Colors.black87;

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: bgColor,
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
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.access_time, size: 18, color: iconColor),
                const SizedBox(width: 8),
                Text(
                  timeText,
                  style: TextStyle(
                    fontSize: 15,
                    color: subtitleColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person_outline, size: 18, color: iconColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    teacherDisplayName,
                    style: TextStyle(
                      fontSize: 15,
                      color: subtitleColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
                  HapticFeedback.lightImpact();
                }
                Navigator.of(context).pop();
                onViewTeacherSchedule();
              },
              icon: Icon(Icons.calendar_today_outlined, size: 20, color: buttonFg),
              label: Text('Посмотреть расписание преподавателя', style: TextStyle(color: buttonFg)),
              style: FilledButton.styleFrom(
                backgroundColor: buttonBg,
                foregroundColor: buttonFg,
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
