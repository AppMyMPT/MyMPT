import 'package:flutter/material.dart';

class LessonCard extends StatelessWidget {
  final String number;
  final String subject;
  final String teacher;
  final String startTime;
  final String endTime;
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
    final dotColor = accentColor;
    final timeColor = isDark ? Colors.white70 : cs.onSurfaceVariant;
    final titleColor = isDark ? Colors.white : cs.onSurface;
    final subtitleColor = isDark ? Colors.white54 : cs.onSurfaceVariant.withOpacity(0.8);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            alignment: Alignment.center,
            child: Column(
              children: [
                Text(
                  startTime,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  endTime,
                  style: TextStyle(
                    fontSize: 12,
                    color: timeColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: dotColor.withOpacity(0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: dotColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$number пара',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? dotColor : dotColor.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  subject,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  teacher,
                  style: TextStyle(
                    fontSize: 13,
                    color: subtitleColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
