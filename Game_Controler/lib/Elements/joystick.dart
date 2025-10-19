import 'package:flutter/material.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import '../style.dart';

class JoystickWidget extends StatelessWidget {
  final String side;
  final double size;
  final double scaleFactor;
  final Function(double x, double y) onMove;

  const JoystickWidget({
    super.key,
    required this.side,
    required this.size,
    required this.onMove,
    this.scaleFactor = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Joystick(
      mode: JoystickMode.all,
      stick: Container(
        width: size * 0.28 * scaleFactor,
        height: size * 0.28 * scaleFactor,
        decoration: BoxDecoration(
          color: AppColors.joyStick,
          shape: BoxShape.circle,
        ),
      ),
      base: Container(
        width: size * scaleFactor,
        height: size * scaleFactor,
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          shape: BoxShape.circle,
        ),
      ),
      listener: (details) {
        double x = details.x.abs() < 0.01 ? 0 : details.x;
        double y = details.y.abs() < 0.01 ? 0 : details.y;
        onMove(x, y);
      },
    );
  }
}
