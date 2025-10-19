import 'package:flutter/material.dart';
import '../style.dart';

class DPad extends StatelessWidget {
  final Set<String> pressedButtons;
  final Function(int index, bool pressed) onPressed;
  final double size;
  final double scaleFactor; // <-- neu

  const DPad({
    super.key,
    required this.pressedButtons,
    required this.onPressed,
    required this.size,
    this.scaleFactor = 1.0,
  });

  Widget _dpadButton(String dir, int index) {
    final key = "left_$index";
    final isPressed = pressedButtons.contains(key);

    return GestureDetector(
      onTapDown: (_) => onPressed(index, true),
      onTapUp: (_) => onPressed(index, false),
      onTapCancel: () => onPressed(index, false),
      child: Container(
        width: size * 0.32 * scaleFactor,
        height: size * 0.32 * scaleFactor,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isPressed ? Colors.greenAccent.withOpacity(0.6) : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(6 * scaleFactor),
          border: Border.all(color: AppColors.textPrimary, width: 1.3 * scaleFactor),
        ),
        child: Icon(
          dir == 'up'
              ? Icons.keyboard_arrow_up
              : dir == 'down'
                  ? Icons.keyboard_arrow_down
                  : dir == 'left'
                      ? Icons.keyboard_arrow_left
                      : Icons.keyboard_arrow_right,
          color: AppColors.textPrimary,
          size: size * 0.2 * scaleFactor,
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
          Positioned(top: 0, child: _dpadButton('up', 10)),
          Positioned(bottom: 0, child: _dpadButton('down', 11)),
          Positioned(left: 0, child: _dpadButton('left', 12)),
          Positioned(right: 0, child: _dpadButton('right', 13)),
        ],
      ),
    );
  }
}
