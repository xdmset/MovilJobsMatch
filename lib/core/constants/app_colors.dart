import 'package:flutter/material.dart';

class AppColors {
  // Colores Primarios
  static const Color primaryPurple = Color(0xFF6C5CE7);
  static const Color primaryPurpleLight = Color(0xFF8B7FF5);
  static const Color primaryPurpleDark = Color(0xFF5847C7);

  // Colores Secundarios
  static const Color accentBlue = Color(0xFF5B8DEF);
  static const Color accentGreen = Color(0xFF00D9A5);
  static const Color accentRed = Color(0xFFFF6B9D);
  static const Color accentOrange = Color(0xFFFFB347);

  // Neutrales
  static const Color background = Color(0xFFF8F9FE);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color surfaceGray = Color(0xFFF5F6FA);

  // Textos
  static const Color textPrimary = Color(0xFF2D3748);
  static const Color textSecondary = Color(0xFF718096);
  static const Color textTertiary = Color(0xFFA0AEC0);

  // Bordes
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color borderMedium = Color(0xFFCBD5E0);

  // Estados
  static const Color success = Color(0xFF48BB78);
  static const Color warning = Color(0xFFED8936);
  static const Color error = Color(0xFFF56565);
  static const Color info = Color(0xFF4299E1);

  // Overlays
  static const Color overlay = Color(0x80000000);
  static const Color overlayLight = Color(0x40000000);

  // Status de aplicación
  static const Color statusSent = Color(0xFF5B8DEF);
  static const Color statusViewed = Color(0xFF00D9A5);
  static const Color statusInProcess = Color(0xFFFFB347);
  static const Color statusRejected = Color(0xFFFF6B9D);
  static const Color statusExpired = Color(0xFFA0AEC0);

  // Gradientes
  static const LinearGradient purpleGradient = LinearGradient(
    colors: [primaryPurple, primaryPurpleLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient blueGradient = LinearGradient(
    colors: [accentBlue, Color(0xFF7BA5F5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}