import 'package:flutter/material.dart';

class AppBackgroundShell extends StatelessWidget {
  const AppBackgroundShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: AppBackground()),
        child,
      ],
    );
  }
}

class AppBackground extends StatelessWidget {
  const AppBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF9F2E9), Color(0xFFF1E3D3), Color(0xFFE8D5C3)],
        ),
      ),
      child: const Stack(
        children: [
          Positioned(
            top: -120,
            right: -80,
            child: _SoftCircle(
              size: 260,
              color: Color(0xFFC49A6C),
              opacity: 0.18,
            ),
          ),
          Positioned(
            bottom: -140,
            left: -90,
            child: _SoftCircle(
              size: 280,
              color: Color(0xFF543824),
              opacity: 0.1,
            ),
          ),
          Positioned(
            top: 140,
            left: 30,
            child: _SoftCircle(
              size: 120,
              color: Color(0xFF8B6F4E),
              opacity: 0.12,
            ),
          ),
          Positioned(
            bottom: 120,
            right: 40,
            child: _SoftCircle(
              size: 160,
              color: Color(0xFFBFA889),
              opacity: 0.12,
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftCircle extends StatelessWidget {
  const _SoftCircle({
    required this.size,
    required this.color,
    required this.opacity,
  });

  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withAlpha((opacity * 255).round()),
      ),
    );
  }
}
