import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/constants.dart';

class BackgroundOrbs extends StatelessWidget {
  const BackgroundOrbs({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Stack(
      children: [
        _Orb(
          color: AppColors.orb1,
          size: size.width * 0.8,
          top: -size.height * 0.1,
          left: -size.width * 0.2,
          delay: 0,
        ),
        _Orb(
          color: AppColors.orb2,
          size: size.width * 0.7,
          top: size.height * 0.4,
          right: -size.width * 0.2,
          delay: 2000,
        ),
        _Orb(
          color: AppColors.orb3,
          size: size.width * 0.9,
          bottom: -size.height * 0.1,
          left: size.width * 0.1,
          delay: 4000,
        ),
      ],
    );
  }
}

class _Orb extends StatelessWidget {
  final Color color;
  final double size;
  final double? top;
  final double? bottom;
  final double? left;
  final double? right;
  final int delay;

  const _Orb({
    required this.color,
    required this.size,
    this.top,
    this.bottom,
    this.left,
    this.right,
    this.delay = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
      )
      .animate(onPlay: (controller) => controller.repeat(reverse: true))
      .scale(
        duration: 20.seconds,
        begin: const Offset(1, 1),
        end: const Offset(1.2, 1.2),
        curve: Curves.easeInOut,
        delay: delay.ms,
      )
      .move(
        duration: 25.seconds,
        begin: Offset.zero,
        end: const Offset(30, 40),
        curve: Curves.easeInOut,
      )
      .blur(begin: const Offset(80, 80), end: const Offset(100, 100)),
    );
  }
}
