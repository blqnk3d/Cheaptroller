import 'package:flutter/material.dart';

// ----------------- COLORS -----------------
class AppColors {
  static const background = Color(0xFF0F0F0F); // deeper black
  static const cardBackground = Color(0xFF1A1A1A); // card grey

  static const joyStick = Color(0xFF333333);
  static const joyStickGlow = Colors.blueAccent;

  static const buttonDisabled = Color(0xFF1A1A1A);
  
  static const textPrimary = Colors.white;
  static const textSecondary = Colors.white38;

  static const icon = Colors.white70;
}

// ----------------- TEXT STYLES -----------------
class AppTextStyles {
  static const heading = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );

  static const body = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 14,
  );

  static const label = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 14,
  );
}

// ----------------- BUTTON STYLES -----------------
class AppButtonStyles {
  static final whiteIconButton = IconButton.styleFrom(
    foregroundColor: AppColors.icon, // icon color
  );
}

// ----------------- INPUT DECORATION -----------------
class AppInputDecorations {
  static InputDecoration textField(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: AppTextStyles.label,
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.textSecondary),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.textPrimary),
      ),
      fillColor: AppColors.cardBackground,
      filled: true,
    );
  }
}
