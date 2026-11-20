import 'package:flutter/material.dart';

/// App color palette inspired by Linear & Apple Calendar
class AppColors {
  AppColors._();

  // Dark Theme Palette (Default)
  static const Color darkBackground = Color(0xFF0B0F17);
  static const Color darkSurface = Color(0xFF111827);
  static const Color darkSurfaceElevated = Color(0xFF1E293B);
  static const Color darkBorder = Color(0xFF1F2937);
  static const Color darkBorderSubtle = Color(0xFF374151);

  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF64748B);

  // Light Theme Palette
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFF1F5F9);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightBorderSubtle = Color(0xFFCBD5E1);

  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextMuted = Color(0xFF94A3B8);

  // Brand / Semantic Accents
  static const Color primary = Color(0xFF6366F1); // Indigo
  static const Color primaryHover = Color(0xFF4F46E5);
  static const Color primaryGlow = Color(0x336366F1);

  static const Color secondary = Color(0xFF06B6D4); // Cyan
  static const Color accent = Color(0xFF8B5CF6); // Purple

  // Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color successBgDark = Color(0xFF064E3B);
  static const Color successBgLight = Color(0xFFD1FAE5);

  static const Color warning = Color(0xFFF59E0B);
  static const Color warningBgDark = Color(0xFF78350F);
  static const Color warningBgLight = Color(0xFFFEF3C7);

  static const Color error = Color(0xFFEF4444);
  static const Color errorBgDark = Color(0xFF7F1D1D);
  static const Color errorBgLight = Color(0xFFFEE2E2);

  static const Color info = Color(0xFF3B82F6);
  static const Color infoBgDark = Color(0xFF1E3A8A);
  static const Color infoBgLight = Color(0xFFDBEAFE);

  // Priority Specific Badges
  static const Color priorityUrgent = Color(0xFFEF4444);
  static const Color priorityHigh = Color(0xFFF97316);
  static const Color priorityMedium = Color(0xFF3B82F6);
  static const Color priorityLow = Color(0xFF64748B);
}
