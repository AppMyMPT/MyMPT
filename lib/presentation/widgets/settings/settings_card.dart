import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Виджет карточки настроек
class SettingsCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final bool isRefreshing;

  const SettingsCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
    this.isRefreshing = false,
  });

  @override
  State<SettingsCard> createState() => _SettingsCardState();
}

class _SettingsCardState extends State<SettingsCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 360,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SettingsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRefreshing && !oldWidget.isRefreshing) {
      _controller.repeat();
    } else if (!widget.isRefreshing && oldWidget.isRefreshing) {
      _controller.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final bg = cs.surface;
    final iconBg = isDark ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.06);
    final iconColor = isDark ? Colors.white : Colors.black87;

    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: isDark ? Colors.white : cs.onSurface,
    );
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: isDark ? Colors.white70 : cs.onSurfaceVariant,
    );

    final chevronColor = isDark ? Colors.white54 : cs.onSurfaceVariant.withOpacity(0.8);
    final progressColor = isDark ? Colors.white : cs.onSurface.withOpacity(0.7);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap != null
            ? () {
                if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
                  HapticFeedback.lightImpact();
                }
                widget.onTap!();
              }
            : null,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: widget.isRefreshing
                    ? RotationTransition(
                        turns: _rotationAnimation,
                        child: Icon(widget.icon, color: iconColor),
                      )
                    : Icon(widget.icon, color: iconColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title, style: titleStyle),
                    const SizedBox(height: 6),
                    Text(widget.subtitle, style: subtitleStyle),
                  ],
                ),
              ),
              widget.isRefreshing
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: progressColor,
                      ),
                    )
                  : Icon(
                      widget.onTap != null ? Icons.arrow_forward_ios : null,
                      size: 16,
                      color: chevronColor,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
