import 'package:flutter/material.dart';
import '../style.dart';

class JoystickWidget extends StatefulWidget {
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
  _JoystickWidgetState createState() => _JoystickWidgetState();
}

class _JoystickWidgetState extends State<JoystickWidget> {
  Offset knobOffset = Offset.zero;

  @override
  void dispose() {
    super.dispose();
  }

  void _updateKnob(Offset localPosition) {
    final center = Offset(widget.size / 2, widget.size / 2);
    final delta = localPosition - center;

    // Limit to radius
    final radius = widget.size / 2;
    final distance = delta.distance;
    final limitedDelta =
        distance > radius ? delta / distance * radius : delta;

    setState(() {
      knobOffset = limitedDelta;
    });

    _reportKnobPosition();
  }

  void _reportKnobPosition() {
    final radius = widget.size / 2;
    final x = (knobOffset.dx / radius).clamp(-1.0, 1.0);
    final y = (knobOffset.dy / radius).clamp(-1.0, 1.0);
    widget.onMove(x, y);
  }

  void _resetKnob() {
    // Instant reset - no animation latency
    setState(() {
      knobOffset = Offset.zero;
    });
    _reportKnobPosition();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        _updateKnob(details.localPosition);
      },
      onPanUpdate: (details) {
        _updateKnob(details.localPosition);
      },
      onTapUp: (_) => _resetKnob(),
      onTapCancel: _resetKnob,
      onPanEnd: (_) => _resetKnob(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer Glow / Ring
          Container(
            width: widget.size * widget.scaleFactor,
            height: widget.size * widget.scaleFactor,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white10, width: 2),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 10, spreadRadius: 2),
              ],
            ),
          ),
          // Base
          Container(
            width: widget.size * 0.95 * widget.scaleFactor,
            height: widget.size * 0.95 * widget.scaleFactor,
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.cardBackground,
                  Colors.black.withValues(alpha: 0.8),
                ],
              ),
            ),
          ),
          // Knob
          Transform.translate(
            offset: knobOffset,
            child: Container(
              width: widget.size * 0.35 * widget.scaleFactor,
              height: widget.size * 0.35 * widget.scaleFactor,
              decoration: BoxDecoration(
                color: AppColors.joyStick,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.joyStickGlow.withValues(alpha: 0.5), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.joyStickGlow.withValues(alpha: 0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.joyStick,
                    Colors.black.withValues(alpha: 0.5),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
