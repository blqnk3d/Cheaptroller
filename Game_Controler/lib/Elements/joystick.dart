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

class _JoystickWidgetState extends State<JoystickWidget>
    with SingleTickerProviderStateMixin {
  Offset knobOffset = Offset.zero;

  late AnimationController _controller;
  late Animation<Offset> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50),  // Reduced for less latency
    );
    _animation = Tween<Offset>(begin: Offset.zero, end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.linear))  // Linear is faster
      ..addListener(() {
        setState(() {
          knobOffset = _animation.value;
          _reportKnobPosition();
        });
      });
  }

  @override
  void dispose() {
    _controller.dispose();
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
    _animation = Tween<Offset>(begin: knobOffset, end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        _controller.stop();
        _updateKnob(details.localPosition);
      },
      onPanUpdate: (details) {
        _controller.stop();
        _updateKnob(details.localPosition);
      },
      onTapUp: (_) => _resetKnob(),
      onTapCancel: _resetKnob,
      onPanEnd: (_) => _resetKnob(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Base
          Container(
            width: widget.size * widget.scaleFactor,
            height: widget.size * widget.scaleFactor,
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              shape: BoxShape.circle,
            ),
          ),
          // Knob
          Transform.translate(
            offset: knobOffset,
            child: Container(
              width: widget.size * 0.28 * widget.scaleFactor,
              height: widget.size * 0.28 * widget.scaleFactor,
              decoration: BoxDecoration(
                color: AppColors.joyStick,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
