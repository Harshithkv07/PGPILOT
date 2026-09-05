import 'package:flutter/material.dart';

/// Lightweight count-up animation for stat numbers, built on
/// [TweenAnimationBuilder] so no extra animation package is needed.
class AnimatedCount extends StatelessWidget {
  final int value;
  final TextStyle? style;
  final Duration duration;

  const AnimatedCount({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 600),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(animatedValue.round().toString(), style: style),
        );
      },
    );
  }
}
