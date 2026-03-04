import 'dart:ui';
import 'package:flutter/material.dart';

/// Виджет заголовка экрана звонков
class CallsHeader extends StatelessWidget {
  const CallsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final gradientColors = isDark
        ? [const Color(0xFF333333).withValues(alpha: 0.6), const Color(0xFF111111).withValues(alpha: 0.6)]
        : [Colors.white.withValues(alpha: 0.5), const Color(0xFFF5F5F5).withValues(alpha: 0.5)];

    final titleColor = isDark ? Colors.white : cs.onSurface;
    final subtitleColor = isDark ? Colors.white70 : cs.onSurfaceVariant;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Звонки техникума',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: titleColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Расписание звонков на учебный день',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: subtitleColor),
            ),
          ],
        ),
      ),
    );
  }
}
