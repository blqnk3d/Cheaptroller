import 'package:flutter/material.dart';
import '../style.dart';

class FaceButtons extends StatelessWidget {
  final Set<String> pressedButtons;
  final Function(int index, bool pressed) onPressed;
  final double size;
  final double scaleFactor; // <-- neu

  const FaceButtons({
    super.key,
    required this.pressedButtons,
    required this.onPressed,
    required this.size,
    this.scaleFactor = 1.0,
  });

  Widget _faceButton(String label, int index, double btnSize, Color color) {
    final key = "right_$index";
    final isPressed = pressedButtons.contains(key);

    return GestureDetector(
      onTapDown: (_) => onPressed(index, true),
      onTapUp: (_) => onPressed(index, false),
      onTapCancel: () => onPressed(index, false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
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
    final b = size * 0.34; // individuelle Button-Größe
    return SizedBox(
      width: size * scaleFactor,
      height: size * scaleFactor,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(bottom: 0, child: _faceButton('A', 0, b, Colors.green)),
          Positioned(right: 0, child: _faceButton('B', 1, b, Colors.red)),
          Positioned(left: 0, child: _faceButton('X', 2, b, Colors.blue)),
          Positioned(top: 0, child: _faceButton('Y', 3, b, Colors.yellow)),
        ],
      ),
    );
  }
}
