import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  static TextStyle headlineLarge = GoogleFonts.fraunces(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );

  static TextStyle headlineMedium = GoogleFonts.fraunces(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );

  static TextStyle titleMedium = GoogleFonts.manrope(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
  );

  static TextStyle bodyMedium = GoogleFonts.manrope(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.muted,
    height: 1.5,
  );

  static TextStyle labelSmall = GoogleFonts.manrope(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.muted,
    letterSpacing: 0.5,
  );
}
