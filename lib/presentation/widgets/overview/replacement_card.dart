import 'package:flutter/material.dart';
import 'package:my_mpt/core/utils/lesson_details_parser.dart';
import 'package:my_mpt/core/utils/calls_util.dart';

/// Виджет карточки изменения в расписании
///
/// Этот виджет отображает информацию об изменениях в расписании,
/// таких как замены предметов или дополнительные занятия
class ReplacementCard extends StatelessWidget {
  /// Номер пары, к которой применяется изменение
  final String lessonNumber;

  /// Исходный предмет (до изменения)
  final String replaceFrom;

  /// Новый предмет (после изменения)
  final String replaceTo;

  const ReplacementCard({
    super.key,
    required this.lessonNumber,
    required this.replaceFrom,
    required this.replaceTo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cs = theme.colorScheme;

    final sanitizedReplaceFrom = (replaceFrom == '\u00A0' ? '' : replaceFrom)
        .trim();
    final sanitizedReplaceTo = replaceTo.replaceAll('\u00A0', ' ').trim();
    final LessonDetails newLessonDetails = parseLessonDetails(
      sanitizedReplaceTo,
    );
    final LessonDetails previousLessonDetails = parseLessonDetails(
      sanitizedReplaceFrom,
    );
    final bool hasPreviousLesson = previousLessonDetails.hasData;

    final bool isAdditionalClass =
        sanitizedReplaceFrom.isEmpty ||
        sanitizedReplaceTo.toLowerCase().startsWith('дополнительное занятие');

    final _LessonTimes lessonTimes = _lessonTimesForNumber(lessonNumber);
    final Color accentColor = isAdditionalClass
        ? const Color(0xFFFF8C00).withValues(alpha: 0.5)
        : const Color(0xFFFF8C00);

    final String subjectText = newLessonDetails.subject.isNotEmpty
        ? newLessonDetails.subject
        : (isAdditionalClass
              ? 'Дополнительное занятие'
              : 'Замена в расписании');

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _NumberBadge(number: lessonNumber, accentColor: accentColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subjectText,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isAdditionalClass
                              ? titleColor.withValues(alpha: 0.85)
                              : titleColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (newLessonDetails.teacher.isNotEmpty)
                        Text(
                          newLessonDetails.teacher,
                          style: TextStyle(
                            fontSize: 12,
                            color: isAdditionalClass
                                ? subColor.withValues(alpha: 0.7)
                                : subColor,
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
                      lessonTimes.start,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lessonTimes.end,
                      style: TextStyle(
                        fontSize: 12,
                        color: subColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (hasPreviousLesson) ...[
              const SizedBox(height: 12),
              _PreviousLessonInfo(details: previousLessonDetails),
            ],
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

/// Блок с зачеркнутой оригинальной парой
class _PreviousLessonInfo extends StatelessWidget {
  final LessonDetails details;

  const _PreviousLessonInfo({required this.details});

  bool get _isAdditionalLesson =>
      details.subject.trim().toLowerCase() == 'дополнительное занятие';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? Colors.white.withValues(alpha: 0.5) : Colors.black45;
    final colorSub = isDark ? Colors.white.withValues(alpha: 0.4) : Colors.black38;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (details.subject.isNotEmpty)
          Text(
            details.subject,
            style: TextStyle(
              fontSize: 14,
              color: color,
              decoration: _isAdditionalLesson
                  ? TextDecoration.none
                  : TextDecoration.lineThrough,
            ),
          ),
        if (details.teacher.isNotEmpty) ...[
          if (details.subject.isNotEmpty) const SizedBox(height: 2),
          Text(
            details.teacher,
            style: TextStyle(
              fontSize: 12,
              color: colorSub,
              decoration: _isAdditionalLesson
                  ? TextDecoration.none
                  : TextDecoration.lineThrough,
            ),
          ),
        ],
      ],
    );
  }
}

class _LessonTimes {
  final String start;
  final String end;

  const _LessonTimes({required this.start, required this.end});
}

_LessonTimes _lessonTimesForNumber(String lessonNumber) {
  final sanitizedNumber = lessonNumber.trim();
  String start = '--:--';
  String end = '--:--';

  for (final call in CallsUtil.getCalls()) {
    if (call.period == sanitizedNumber) {
      start = call.startTime;
      end = call.endTime;
      break;
    }
  }

  return _LessonTimes(start: start, end: end);
}
