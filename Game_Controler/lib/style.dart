import 'package:flutter/material.dart';

// ----------------- COLORS -----------------
class AppColors {
  static const background = Color(0xFF212121); // dark grey
  static const cardBackground = Color(0xFF2A2A2A); // slightly lighter grey

  static const joyStick = Color.fromARGB(255, 88, 88, 88);

  static const buttonDisabled = Color.fromARGB(255, 56, 56, 56);
  
  static const textPrimary = Colors.white;
  static const textSecondary = Colors.grey;

  static const icon = Colors.white;
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
