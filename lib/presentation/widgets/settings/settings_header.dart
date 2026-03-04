import 'package:flutter/material.dart';

/// Виджет заголовка экрана настроек
class SettingsHeader extends StatelessWidget {
  const SettingsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final gradientColors = isDark
        ? const [Color(0xFF333333), Color(0xFF111111)]
        : const [Color(0xFFFFFFFF), Color(0xFFF5F5F5)];

    final titleColor = isDark ? Colors.white : cs.onSurface;
    final subtitleColor = isDark ? Colors.white70 : cs.onSurfaceVariant;

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 0),
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Настройки',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: titleColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Персонализируйте расписание и связь с техникумом',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: subtitleColor,
            ),
          ),
        ],
      ),
    );
  }
}
