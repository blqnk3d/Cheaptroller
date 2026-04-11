import 'package:flutter/material.dart';
import '../style.dart';

class DPad extends StatefulWidget {
  final Set<String> pressedButtons;
  final Function(int index, bool pressed) onPressed;
  final double size;
  final double scaleFactor;

  const DPad({
    super.key,
    required this.pressedButtons,
    required this.onPressed,
    required this.size,
    this.scaleFactor = 1.0,
  });

  @override
  State<DPad> createState() => _DPadState();
}

class _DPadState extends State<DPad> {
  final Set<int> _locallyPressed = {};

  void _handleTouch(Offset localPosition) {
    final double center = (widget.size * widget.scaleFactor) / 2;
    final double dx = localPosition.dx - center;
    final double dy = localPosition.dy - center;
    
    // Normalize coordinates relative to center
    final double nx = dx / center;
    final double ny = dy / center;
    final double distance = Offset(nx, ny).distance;

    final Set<int> newIndices = {};

    // Only detect if outside a small deadzone and within the dpad area
    if (distance > 0.15 && distance < 1.2) {
      // Sensitivity threshold for diagonal detection
      const double threshold = 0.25;

      if (ny < -threshold) newIndices.add(10); // Up
      if (ny > threshold) newIndices.add(11);  // Down
      if (nx < -threshold) newIndices.add(12); // Left
      if (nx > threshold) newIndices.add(13);  // Right
    }

    // Release buttons that are no longer active
    for (final int index in _locallyPressed.toList()) {
      if (!newIndices.contains(index)) {
        widget.onPressed(index, false);
        _locallyPressed.remove(index);
      }
    }

    // Press buttons that became active
    for (final int index in newIndices) {
      if (!_locallyPressed.contains(index)) {
        widget.onPressed(index, true);
        _locallyPressed.add(index);
      }
    }
  }

  void _handleRelease() {
    for (final int index in _locallyPressed.toList()) {
      widget.onPressed(index, false);
      _locallyPressed.remove(index);
    }
  }

  Widget _dpadButtonVisual(String dir, int index) {
    final key = "left_$index";
    final isPressed = widget.pressedButtons.contains(key);
    final btnSize = widget.size * 0.32 * widget.scaleFactor;

    return Container(
      width: btnSize,
      height: btnSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isPressed ? Colors.greenAccent.withValues(alpha: 0.4) : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(8 * widget.scaleFactor),
        border: Border.all(color: isPressed ? Colors.greenAccent : Colors.white10, width: 1.5 * widget.scaleFactor),
        boxShadow: [
          if (isPressed)
            BoxShadow(color: Colors.greenAccent.withValues(alpha: 0.2), blurRadius: 10, spreadRadius: 1),
        ],
      ),
      child: Icon(
        dir == 'up'
            ? Icons.keyboard_arrow_up
            : dir == 'down'
                ? Icons.keyboard_arrow_down
                : dir == 'left'
                    ? Icons.keyboard_arrow_left
                    : Icons.keyboard_arrow_right,
        color: isPressed ? Colors.greenAccent : AppColors.textPrimary,
        size: btnSize * 0.7,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fullSize = widget.size * widget.scaleFactor;

    return GestureDetector(
      onPanStart: (details) => _handleTouch(details.localPosition),
      onPanUpdate: (details) => _handleTouch(details.localPosition),
      onPanEnd: (_) => _handleRelease(),
      onTapDown: (details) => _handleTouch(details.localPosition),
      onTapUp: (_) => _handleRelease(),
      onTapCancel: () => _handleRelease(),
      child: SizedBox(
        width: fullSize,
        height: fullSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(top: 0, child: _dpadButtonVisual('up', 10)),
            Positioned(bottom: 0, child: _dpadButtonVisual('down', 11)),
            Positioned(left: 0, child: _dpadButtonVisual('left', 12)),
            Positioned(right: 0, child: _dpadButtonVisual('right', 13)),
          ],
        ),
      ),
    );
  }
}
