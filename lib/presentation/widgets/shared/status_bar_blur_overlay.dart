import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

class StatusBarBlurOverlay extends StatelessWidget {
  const StatusBarBlurOverlay({super.key, required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    if (topInset <= 0) return const SizedBox.shrink();

    final overlayColor = isDark
        ? Colors.black.withValues(alpha: 0.18)
        : Colors.white.withValues(alpha: 0.24);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.06);

    return IgnorePointer(
      child: ClipRect(
        child: SizedBox(
          height: topInset,
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) {
              return const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Colors.white, Colors.transparent],
                stops: [0.0, 0.68, 1.0],
              ).createShader(bounds);
            },
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: overlayColor,
                  border: Border(
                    bottom: BorderSide(
                      color: borderColor,
                      width: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
