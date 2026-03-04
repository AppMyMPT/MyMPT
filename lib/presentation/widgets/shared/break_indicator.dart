import 'package:flutter/material.dart';
import 'package:my_mpt/core/utils/calls_util.dart';

/// Виджет индикатора перемены
///
/// Этот виджет отображает информацию о переменах между парами,
/// включая продолжительность и время начала/окончания перемены
class BreakIndicator extends StatelessWidget {
  /// Время начала перемены
  final String startTime;

  /// Время окончания перемены
  final String endTime;

  const BreakIndicator({
    super.key,
    required this.startTime,
    required this.endTime,
  });

  @override
  Widget build(BuildContext context) {
    final String duration = CallsUtil.getBreakDuration(startTime, endTime);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white54 : Colors.black54;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_run, size: 16, color: textColor),
          const SizedBox(width: 8),
          Text(
            'Перемена $duration',
            style: TextStyle(
              fontSize: 12,
              color: textColor,
              fontWeight: FontWeight.w400,
            ),
          ),
          const Spacer(),
          Text(
            '$startTime - $endTime',
            style: TextStyle(
              fontSize: 12,
              color: textColor,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
