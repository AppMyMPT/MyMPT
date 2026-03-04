import 'package:flutter/material.dart';

class BreakIndicator extends StatelessWidget {
  final String startTime;
  final String endTime;

  const BreakIndicator({
    super.key,
    required this.startTime,
    required this.endTime,
  });

  int _calculateMinutes(String start, String end) {
    try {
      final sParts = start.split(':');
      final eParts = end.split(':');
      final sMin = int.parse(sParts[0]) * 60 + int.parse(sParts[1]);
      final eMin = int.parse(eParts[0]) * 60 + int.parse(eParts[1]);
      return eMin - sMin;
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final diff = _calculateMinutes(startTime, endTime);
    final showIcon = diff >= 20;

    final color = isDark ? Colors.white30 : cs.onSurfaceVariant.withOpacity(0.4);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const SizedBox(width: 80),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 1,
                    color: color.withOpacity(0.5),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showIcon) ...[
                        Icon(
                          Icons.restaurant_outlined,
                          size: 14,
                          color: color,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        '$diff мин',
                        style: TextStyle(
                          fontSize: 12,
                          color: color,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 1,
                    color: color.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
