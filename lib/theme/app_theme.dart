import 'package:flutter/material.dart';

/// Aurora Glass tema sabitleri — tum ekranlar renkleri buradan alir.
abstract final class AppTheme {
  // Zemin degradesi
  static const Color bgTop = Color(0xFF1B2743);
  static const Color bgMid = Color(0xFF0D1321);
  static const Color bgBottom = Color(0xFF090D18);

  // Aurora isik kumeleri
  static const Color auroraPurple = Color(0xFF7C3AED);
  static const Color auroraBlue = Color(0xFF38BDF8);

  // Vurgu degradesi
  static const Color accentStart = Color(0xFF38BDF8);
  static const Color accentEnd = Color(0xFF818CF8);
  static const LinearGradient accentGradient =
      LinearGradient(colors: [accentStart, accentEnd]);

  // Durum renkleri
  static const Color online = Color(0xFF34D399);
  static const Color offline = Color(0xFFF87171);
  static const Color textPrimary = Colors.white;
  static const Color textMuted = Color(0xFF8B96B5);

  // Cam yuzeyler (withValues const olamadigi icin final)
  static final Color glassFill = Colors.white.withValues(alpha: 0.07);
  static final Color glassBorder = Colors.white.withValues(alpha: 0.14);
  static final Color glassFillSubtle = Colors.white.withValues(alpha: 0.05);

  // Alt navigasyon zemini
  static const Color navBg = Color(0xFF0D1321);
}
