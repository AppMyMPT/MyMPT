import 'package:flutter/material.dart';

/// Виджет индикатора страниц
class PageIndicator extends StatelessWidget {
  final int currentPageIndex;

  const PageIndicator({super.key, required this.currentPageIndex});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        PageDot(isActive: currentPageIndex == 0),
        const SizedBox(width: 8),
        PageDot(isActive: currentPageIndex == 1),
      ],
    );
  }
}

/// Виджет точки индикатора страниц
class PageDot extends StatelessWidget {
  final bool isActive;

  const PageDot({super.key, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final activeColor = isDark ? Colors.white : Colors.grey.shade600;
    final inactiveColor = isDark 
        ? Colors.white.withValues(alpha: 0.3) 
        : Colors.grey.shade300;

    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? activeColor : inactiveColor,
        shape: BoxShape.circle,
      ),
    );
  }
}
