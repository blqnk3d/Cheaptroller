import 'package:flutter/material.dart';
import '../style.dart';

class MiddleButtons extends StatelessWidget {
  final Set<String> pressedButtons;
  final Function(int index, bool pressed) onPressed;
  final double scaleFactor;

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
          color: isPressed ? Colors.white24 : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(10 * scaleFactor),
          border: Border.all(color: isPressed ? Colors.white : Colors.white10, width: 1.5 * scaleFactor),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isPressed ? Colors.white : Colors.white60,
            fontSize: 13 * scaleFactor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _topButton('View', 8, 'left'),
        SizedBox(width: 20 * scaleFactor),
        Container(
          width: 45 * scaleFactor,
          height: 45 * scaleFactor,
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white10, width: 2 * scaleFactor),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10),
            ],
            gradient: RadialGradient(
              colors: [AppColors.cardBackground, Colors.black.withValues(alpha: 0.5)],
            ),
          ),
          child: Icon(Icons.home, color: Colors.greenAccent, size: 24 * scaleFactor),
        ),
        SizedBox(width: 20 * scaleFactor),
        _topButton('Menu', 9, 'right'),
      ],
    );
  }
}
