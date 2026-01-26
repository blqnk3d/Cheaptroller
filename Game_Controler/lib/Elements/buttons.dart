import 'package:flutter/material.dart';
import '../style.dart';

class FaceButtons extends StatelessWidget {
  final Set<String> pressedButtons;
  final Function(int index, bool pressed) onPressed;
  final double size;
  final double scaleFactor;

  const FaceButtons({
    super.key,
    required this.pressedButtons,
    required this.onPressed,
    required this.size,
    this.scaleFactor = 1.0,
  });

  Widget _faceButton(String label, int index, Color color) {
    final key = "right_$index";
    final isPressed = pressedButtons.contains(key);
    final btnSize = size * 0.34 * scaleFactor;

    return GestureDetector(
      onTapDown: (_) => onPressed(index, true),
      onTapUp: (_) => onPressed(index, false),
      onTapCancel: () => onPressed(index, false),
      child: Container(
        width: btnSize,
        height: btnSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isPressed ? color.withOpacity(0.7) : AppColors.cardBackground,
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2 * scaleFactor),
        ),
        child: Text(
          label,
          style: AppTextStyles.body.copyWith(
            fontSize: btnSize * 0.4,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * scaleFactor,
      height: size * scaleFactor,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(bottom: 0, child: _faceButton('A', 0, Colors.green)),
          Positioned(right: 0, child: _faceButton('B', 1, Colors.red)),
          Positioned(left: 0, child: _faceButton('X', 2, Colors.blue)),
          Positioned(top: 0, child: _faceButton('Y', 3, Colors.yellow)),
        ],
      ),
    );
  }
}
