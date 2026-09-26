import 'package:flutter/material.dart';

class AppColors {
  // Brand
  static const Color primary = Color(0xFF6366F1); // Indigo
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primaryDark = Color(0xFF4338CA);
  static const Color secondary = Color(0xFF06B6D4); // Cyan
  
  // Accents
  static const Color success = Color(0xFF10B981); // Emerald
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color danger = Color(0xFFEF4444);  // Red
  static const Color info = Color(0xFF0EA5E9);    // Sky

  // Dark Theme Surfaces
  static const Color darkBackground = Color(0xFF0A0F1D);
  static const Color darkSurface = Color(0xFF141C2E);
  static const Color darkSurfaceElevated = Color(0xFF1E293B);
  static const Color darkBorder = Color(0xFF26334D);

  // Light Theme Surfaces
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFF1F5F9);
  static const Color lightBorder = Color(0xFFE2E8F0);

  // Neutral Text (Light Mode) - High Contrast & Crisp
  static const Color textLightPrimary = Color(0xFF0F172A); // Slate 900
  static const Color textLightSecondary = Color(0xFF334155); // Slate 700
  static const Color textLightMuted = Color(0xFF64748B); // Slate 500
  static const Color textLightDisabled = Color(0xFF94A3B8); // Slate 400

  // Neutral Text (Dark Mode)
  static const Color textDarkPrimary = Color(0xFFF8FAFC); // Slate 50
  static const Color textDarkSecondary = Color(0xFFCBD5E1); // Slate 300
  static const Color textDarkMuted = Color(0xFF94A3B8); // Slate 400
  static const Color textDarkDisabled = Color(0xFF64748B); // Slate 500
}
