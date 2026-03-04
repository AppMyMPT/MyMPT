import 'package:flutter/material.dart';

/// Виджет элемента временной шкалы звонков
class CallTimelineTile extends StatelessWidget {
  /// Номер периода/пары
  final String period;

  /// Время начала периода
  final String startTime;

  /// Время окончания периода
  final String endTime;

  /// Описание периода
  final String description;

  /// Флаг отображения соединительной линии
  final bool showConnector;

  /// Идёт ли сейчас эта пара (подсветка номера)
  final bool isCurrent;

  /// Цвет подсветки текущей пары и перемены (числитель/знаменатель)
  final Color currentAccentColor;

  /// Идёт ли сейчас перемена (подсветка соединительной палочки)
  final bool isBreakCurrent;

  const CallTimelineTile({
    super.key,
    required this.period,
    required this.startTime,
    required this.endTime,
    required this.description,
    required this.showConnector,
    this.isCurrent = false,
    this.currentAccentColor = const Color(0xFFFF8C00),
    this.isBreakCurrent = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final titleColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white70 : Colors.black54;

    final periodColor = isCurrent ? currentAccentColor : titleColor;
    final containerColor = isCurrent 
        ? currentAccentColor.withValues(alpha: 0.3) 
        : (isDark ? const Color(0xFF333333) : const Color(0xFFE5E5EA));
        
    final connectorColor = isBreakCurrent 
        ? currentAccentColor 
        : (isDark ? const Color(0xFFFFFFFF).withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.15));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: containerColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  period,
                  style: TextStyle(
                    color: periodColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            if (showConnector)
              Container(
                width: 2,
                height: 48,
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: connectorColor,
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$startTime - $endTime',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(fontSize: 14, color: subColor),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
