import 'package:flutter/material.dart';

/// Виджет карточки урока
///
/// Этот виджет отображает информацию об одном уроке в расписании,
/// включая номер пары, название предмета, преподавателя и время проведения
class LessonCard extends StatelessWidget {
  /// Номер пары
  final String number;

  /// Название предмета
  final String subject;

  /// Преподаватель
  final String teacher;

  /// Время начала пары
  final String startTime;

  /// Время окончания пары
  final String endTime;

  /// Акцентный цвет для номера пары
  final Color accentColor;

  const LessonCard({
    super.key,
    required this.number,
    required this.subject,
    required this.teacher,
    required this.startTime,
    required this.endTime,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final bg = cs.surface;
    final borderColor = isDark ? const Color(0xFF333333) : Colors.black.withValues(alpha: 0.06);
    final shadowColor = isDark ? Colors.black.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.04);
    
    final titleColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white.withValues(alpha: 0.7) : Colors.black54;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _NumberBadge(number: number, accentColor: accentColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subject,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    teacher,
                    style: TextStyle(
                      fontSize: 12,
                      color: subColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  startTime,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  endTime,
                  style: TextStyle(
                    fontSize: 12,
                    color: subColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Виджет бейджа с номером пары
class _NumberBadge extends StatelessWidget {
  /// Номер пары
  final String number;

  /// Акцентный цвет бейджа
  final Color accentColor;

  const _NumberBadge({required this.number, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF333333) : const Color(0xFFE5E5EA);
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          number,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
