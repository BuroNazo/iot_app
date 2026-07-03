import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Koyu lacivert zemin + iki aurora isik kumesi. Ekran icerigi [child]
/// olarak verilir; SafeArea'yi ekranin kendisi ekler.
class AuroraBackground extends StatelessWidget {
  final Widget child;

  const AuroraBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.6, -1.0),
          radius: 1.8,
          colors: [AppTheme.bgTop, AppTheme.bgMid, AppTheme.bgBottom],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Stack(
        children: [
          const Positioned(
            top: -80,
            right: -80,
            child: _AuroraBlob(color: AppTheme.auroraPurple, size: 320),
          ),
          const Positioned(
            bottom: -60,
            left: -70,
            child: _AuroraBlob(color: AppTheme.auroraBlue, size: 280),
          ),
          child,
        ],
      ),
    );
  }
}

class _AuroraBlob extends StatelessWidget {
  final Color color;
  final double size;

  const _AuroraBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}
