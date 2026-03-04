import 'package:flutter/material.dart';

class ReplacementCard extends StatelessWidget {
  final String lessonNumber;
  final String replaceFrom;
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
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final isCancel = replaceTo.toLowerCase().contains('занятие отменено');
    final accentColor = isCancel ? Colors.redAccent : const Color(0xFF4FC3F7);

    final bg = cs.surface;
    final titleColor = isDark ? Colors.white : cs.onSurface;
    final strikeColor = isDark ? Colors.white30 : cs.onSurfaceVariant.withOpacity(0.5);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: isDark ? null : [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Text(
              lessonNumber,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? accentColor : accentColor.withOpacity(0.9),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (replaceFrom.isNotEmpty) ...[
                  Text(
                    replaceFrom,
                    style: TextStyle(
                      fontSize: 14,
                      color: strikeColor,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                Text(
                  replaceTo,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                    height: 1.3,
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
