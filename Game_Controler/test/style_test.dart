import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_controler/style.dart';

void main() {
  group('AppColors', () {
    test('should have valid background color', () {
      expect(AppColors.background, isA<Color>());
      expect(AppColors.background.value, 0xFF0F0F0F);
    });

    test('should have valid card background color', () {
      expect(AppColors.cardBackground, isA<Color>());
      expect(AppColors.cardBackground.value, 0xFF1A1A1A);
    });

    test('should have valid joystick color', () {
      expect(AppColors.joyStick, isA<Color>());
      expect(AppColors.joyStick.value, 0xFF333333);
    });

    test('should have valid joystick glow color', () {
      expect(AppColors.joyStickGlow, isA<Color>());
      expect(AppColors.joyStickGlow.value, 0xFFE0E0E0);
    });

    test('should have valid text primary color', () {
      expect(AppColors.textPrimary, Colors.white);
    });

    test('should have valid text secondary color', () {
      expect(AppColors.textSecondary, Colors.white38);
    });

    test('should have valid icon color', () {
      expect(AppColors.icon, Colors.white70);
    });
  });

  group('AppTextStyles', () {
    test('should have valid heading style', () {
      expect(AppTextStyles.heading.color, AppColors.textPrimary);
      expect(AppTextStyles.heading.fontSize, 18);
      expect(AppTextStyles.heading.fontWeight, FontWeight.bold);
    });

    test('should have valid body style', () {
      expect(AppTextStyles.body.color, AppColors.textPrimary);
      expect(AppTextStyles.body.fontSize, 14);
    });

    test('should have valid label style', () {
      expect(AppTextStyles.label.color, AppColors.textSecondary);
      expect(AppTextStyles.label.fontSize, 14);
    });
  });

  group('AppButtonStyles', () {
    test('should create valid white icon button style', () {
      final style = AppButtonStyles.whiteIconButton;
      expect(style.foregroundColor, isA<WidgetStateProperty<Color?>>());
    });
  });

  group('AppInputDecorations', () {
    test('should create text field decoration', () {
      final decoration = AppInputDecorations.textField('Test Label');

      expect(decoration.labelText, 'Test Label');
      expect(decoration.labelStyle, AppTextStyles.label);
      expect(decoration.filled, true);
      expect(decoration.fillColor, AppColors.cardBackground);
    });

    test('should have correct enabled border', () {
      final decoration = AppInputDecorations.textField('Test');

      expect(decoration.enabledBorder, isA<OutlineInputBorder>());
    });

    test('should have correct focused border', () {
      final decoration = AppInputDecorations.textField('Test');

      expect(decoration.focusedBorder, isA<OutlineInputBorder>());
    });
  });
}