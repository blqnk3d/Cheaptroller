import 'package:flutter/material.dart';

class ConnectionStatusIndicator extends StatefulWidget {
  final bool isConnected;
  const ConnectionStatusIndicator({super.key, required this.isConnected});

  @override
  State<ConnectionStatusIndicator> createState() => _ConnectionStatusIndicatorState();
}

class _ConnectionStatusIndicatorState extends State<ConnectionStatusIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isConnected ? Colors.greenAccent : Colors.redAccent;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: widget.isConnected ? _pulseAnimation.value : 1.0),
                  shape: BoxShape.circle,
                  boxShadow: [
                    if (widget.isConnected)
                      BoxShadow(
                        color: color.withValues(alpha: 0.4 * _pulseAnimation.value),
                        blurRadius: 8 * _pulseAnimation.value,
                        spreadRadius: 2 * _pulseAnimation.value,
                      )
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 10),
          Text(
            widget.isConnected ? "CONNECTED" : "OFFLINE",
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
