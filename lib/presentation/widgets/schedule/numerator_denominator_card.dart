import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:my_mpt/domain/entities/schedule.dart';

/// Виджет карточки пары с числителем и знаменателем
///
/// Этот виджет отображает информацию о паре, которая может отличаться
/// в зависимости от типа недели (числитель или знаменатель)
class NumeratorDenominatorCard extends StatelessWidget {
  /// Урок числителя (может быть null)
  final Schedule? numeratorLesson;

  /// Урок знаменателя (может быть null)
  final Schedule? denominatorLesson;

  /// Номер пары
  final String lessonNumber;

  /// Время начала пары
  final String startTime;

  /// Время окончания пары
  final String endTime;

  /// При нажатии на пару (для студента). Если null, карточка не кликабельна.
  /// [startTime] и [endTime] — время с карточки для отображения в окне детали.
  final void Function(Schedule lesson, {String? startTime, String? endTime})? onLessonTap;

  const NumeratorDenominatorCard({
    super.key,
    required this.numeratorLesson,
    required this.denominatorLesson,
    required this.lessonNumber,
    required this.startTime,
    required this.endTime,
    this.onLessonTap,
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

    final isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Левая часть - номер пары
        Container(
          width: 60,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Center(child: _NumberBadge(number: lessonNumber)),
        ),

        // Центральная часть - пары с разделителем
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Числитель
                Expanded(
                  child: numeratorLesson != null
                      ? _wrapIfTappable(
                          _buildLessonItem(
                            numeratorLesson!,
                            true,
                            singleLineSubject: isIOS,
                            titleColor: titleColor,
                            subColor: subColor,
                          ),
                          numeratorLesson!,
                        )
                      : _buildEmptyLessonItem(true, isDark: isDark),
                ),

                // Разделитель
                Container(
                  height: 1,
                  color: borderColor,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                ),

                // Знаменатель
                Expanded(
                  child: denominatorLesson != null
                      ? _wrapIfTappable(
                          _buildLessonItem(
                            denominatorLesson!,
                            false,
                            singleLineSubject: isIOS,
                            titleColor: titleColor,
                            subColor: subColor,
                          ),
                          denominatorLesson!,
                        )
                      : _buildEmptyLessonItem(false, isDark: isDark),
                ),
              ],
            ),
          ),
        ),

        // Правая часть - время
        Container(
          width: 60,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
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
          ),
        ),
      ],
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0),
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
      child: isIOS
          // На iOS IntrinsicHeight часто добавляет микролаги в списках из-за
          // двойного прохода layout, поэтому даем фиксированную высоту.
          ? SizedBox(height: 104, child: row)
          : IntrinsicHeight(child: row),
    );
  }

  Widget _wrapIfTappable(Widget child, Schedule lesson) {
    if (onLessonTap == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onLessonTap!(lesson, startTime: startTime, endTime: endTime),
        borderRadius: BorderRadius.circular(8),
        child: child,
      ),
    );
  }

  /// Создает виджет для отображения урока
  ///
  /// Параметры:
  /// - [lesson]: Урок для отображения
  /// - [isNumerator]: Флаг, указывающий является ли урок числителем
  ///
  /// Возвращает:
  /// - Widget: Виджет урока
  Widget _buildLessonItem(
    Schedule lesson,
    bool isNumerator, {
    required bool singleLineSubject,
    required Color titleColor,
    required Color subColor,
  }) {
    final color = isNumerator
        ? const Color(0xFFFF8C00) // Оранжевый для числителя
        : const Color(0xFF4FC3F7); // Голубой для знаменателя;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Индикатор типа (числитель/знаменатель)
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),

        // Основной контент
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                lesson.subject,
                maxLines: singleLineSubject ? 1 : null,
                overflow: singleLineSubject ? TextOverflow.ellipsis : null,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                lesson.teacher,
                style: TextStyle(
                  fontSize: 12,
                  color: subColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Создает виджет для отображения пустого урока
  ///
  /// Параметры:
  /// - [isNumerator]: Флаг, указывающий является ли урок числителем
  ///
  /// Возвращает:
  /// - Widget: Виджет пустого урока
  Widget _buildEmptyLessonItem(bool isNumerator, {required bool isDark}) {
    final color = isNumerator
        ? const Color(0xFFFF8C00) // Оранжевый для числителя
        : const Color(0xFF4FC3F7); // Голубой для знаменателя;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Индикатор типа (числитель/знаменатель)
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),

        // Основной контент
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Нет пары',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Виджет бейджа с номером пары
class _NumberBadge extends StatelessWidget {
  /// Номер пары
  final String number;

  const _NumberBadge({required this.number});

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
