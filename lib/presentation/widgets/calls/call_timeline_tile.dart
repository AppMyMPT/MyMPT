import 'package:flutter/material.dart';

class CallTimelineTile extends StatelessWidget {
  final String period;
  final String startTime;
  final String endTime;
  final String description;
  final bool showConnector;
  final bool isCurrent;
  final bool isBreakCurrent;
  final Color currentAccentColor;

  const CallTimelineTile({
    super.key,
    required this.period,
    required this.startTime,
    required this.endTime,
    required this.description,
    this.showConnector = true,
    this.isCurrent = false,
    this.isBreakCurrent = false,
    required this.currentAccentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final dotColor = isCurrent ? currentAccentColor : (isDark ? Colors.white24 : cs.onSurface.withOpacity(0.2));
    final connectorColor = isBreakCurrent
        ? currentAccentColor
        : (isDark ? Colors.white12 : cs.onSurface.withOpacity(0.1));

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const SizedBox(height: 6),
                Text(
                  startTime,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                    color: isCurrent ? currentAccentColor : (isDark ? Colors.white : cs.onSurface),
                  ),
                ),
                Text(
                  endTime,
                  style: TextStyle(
                    fontSize: 13,
                    color: isCurrent ? currentAccentColor.withOpacity(0.8) : (isDark ? Colors.white54 : cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  border: isCurrent
                      ? Border.all(
                          color: currentAccentColor.withOpacity(0.3),
                          width: 4,
                        )
                      : null,
                ),
              ),
              if (showConnector)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: connectorColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isCurrent
                    ? currentAccentColor.withOpacity(0.1)
                    : (isDark ? Colors.white.withOpacity(0.05) : cs.onSurfaceVariant.withOpacity(0.1)),
                borderRadius: BorderRadius.circular(16),
                border: isCurrent
                    ? Border.all(
                        color: currentAccentColor.withOpacity(0.3),
                        width: 1,
                      )
                    : Border.all(
                        color: Colors.transparent,
                        width: 1,
                      ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? currentAccentColor.withOpacity(0.2)
                              : (isDark ? Colors.white12 : cs.onSurfaceVariant.withOpacity(0.2)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$period пара',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isCurrent ? currentAccentColor : (isDark ? Colors.white70 : cs.onSurface),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white70 : cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
