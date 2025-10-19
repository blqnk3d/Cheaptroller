import 'package:flutter/material.dart';
import '../style.dart';

class MiddleButtons extends StatelessWidget {
  final Set<String> pressedButtons;
  final Function(int index, bool pressed) onPressed;
  final double scaleFactor; // <-- neu

  const MiddleButtons({
    super.key,
    required this.pressedButtons,
    required this.onPressed,
    this.scaleFactor = 1.0,
  });

  Widget _topButton(String label, int index, String side) {
    final key = "${side}_$index";
    final isPressed = pressedButtons.contains(key);

    return GestureDetector(
      onTapDown: (_) => onPressed(index, true),
      onTapUp: (_) => onPressed(index, false),
      onTapCancel: () => onPressed(index, false),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 5 * scaleFactor, horizontal: 12 * scaleFactor),
        decoration: BoxDecoration(
          color: isPressed ? Colors.greenAccent.withOpacity(0.5) : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(10 * scaleFactor),
          border: Border.all(color: AppColors.textPrimary, width: 1.5 * scaleFactor),
        ),
        child: Text(label, style: AppTextStyles.body.copyWith(fontSize: 13 * scaleFactor)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _topButton('View', 8, 'left'),
        SizedBox(width: 12 * scaleFactor),
        Container(
          width: 35 * scaleFactor,
          height: 35 * scaleFactor,
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.green, width: 2 * scaleFactor),
          ),
          child: Icon(Icons.home, color: Colors.green, size: 20 * scaleFactor),
        ),
        SizedBox(width: 12 * scaleFactor),
        _topButton('Menu', 9, 'right'),
      ],
    );
  }
}

