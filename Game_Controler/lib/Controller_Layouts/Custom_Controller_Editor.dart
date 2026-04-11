import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../Models/custom_layout_model.dart';
import '../Settings/settingsProvider.dart';
import '../style.dart';

class CustomControllerEditor extends StatefulWidget {
  static const routeName = '/custom_controller_editor';
  const CustomControllerEditor({super.key});

  @override
  State<CustomControllerEditor> createState() => _CustomControllerEditorState();
}

class _CustomControllerEditorState extends State<CustomControllerEditor> {
  late CustomLayout _layout;
  ControlElement? _selectedElement;
  static const double gridSize = 0.02; // 2% of screen per grid cell
  
  bool _showAppBar = true;
  Timer? _appBarTimer;

  @override
  void initState() {
    super.initState();
    _layout = context.read<SettingsProvider>().customLayout;
    
    // Force immersive mode
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    
    _startAppBarTimer();
  }

  @override
  void dispose() {
    _appBarTimer?.cancel();
    // Revert immersive mode if needed, though usually handled by page transitions
    super.dispose();
  }

  void _startAppBarTimer() {
    _appBarTimer?.cancel();
    _appBarTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _showAppBar) {
        setState(() => _showAppBar = false);
      }
    });
  }

  void _toggleAppBar(bool show) {
    setState(() => _showAppBar = show);
    if (show) _startAppBarTimer();
  }

  double _snap(double value) {
    return (value / gridSize).round() * gridSize;
  }

  void _saveLayout() {
    context.read<SettingsProvider>().saveCustomLayout(_layout);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Layout saved!')),
    );
  }

  void _addElement(ControlType type) {
    setState(() {
      _layout.elements.add(ControlElement(
        type: type,
        x: 0.4,
        y: 0.4,
        size: 150,
        side: 'left',
      ));
    });
  }

  void _removeElement(ControlElement element) {
    setState(() {
      _layout.elements.remove(element);
      if (_selectedElement == element) _selectedElement = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Canvas
          GestureDetector(
            onTap: () {
              setState(() => _selectedElement = null);
              if (!_showAppBar) _toggleAppBar(true);
            },
            onVerticalDragUpdate: (details) {
              // Swipe down from top detection
              if (details.primaryDelta! > 10 && details.globalPosition.dy < 50) {
                _toggleAppBar(true);
              }
            },
            child: Container(
              color: Colors.transparent,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      // Grid background
                      Positioned.fill(
                        child: CustomPaint(
                          painter: GridPainter(gridSize: gridSize),
                        ),
                      ),
                      ..._layout.elements.map((element) {
                        return Positioned(
                          left: element.x * constraints.maxWidth,
                          top: element.y * constraints.maxHeight,
                          child: _DraggableElement(
                            element: element,
                            isSelected: _selectedElement == element,
                            constraints: constraints,
                            gridSize: gridSize,
                            onTap: () {
                              setState(() => _selectedElement = element);
                              _toggleAppBar(true);
                            },
                            onMove: () {
                              setState(() {}); // Update UI during move
                            },
                          ),
                        );
                      }).toList(),
                    ],
                  );
                },
              ),
            ),
          ),
          
          // Animated AppBar
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            top: _showAppBar ? 0 : -100,
            left: 0,
            right: 0,
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                color: Colors.black87,
                boxShadow: [
                  BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 2))
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Expanded(
                      child: Text(
                        'Layout Editor',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.save, color: Colors.greenAccent),
                      onPressed: _saveLayout,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Toolbar (Only show when selected or when AppBar is visible)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            bottom: _showAppBar || _selectedElement != null ? 20 : -100,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _toolButton(Icons.circle, () => _addElement(ControlType.joystick), 'Joy'),
                  _toolButton(Icons.apps, () => _addElement(ControlType.dpad), 'DPad'),
                  _toolButton(Icons.grid_view, () => _addElement(ControlType.faceButtons), 'Face'),
                  _toolButton(Icons.more_horiz, () => _addElement(ControlType.middleButtons), 'Mid'),
                  _toolButton(Icons.rectangle_outlined, () => _addElement(ControlType.bumper), 'Bump'),
                  if (_selectedElement != null) ...[
                    const VerticalDivider(color: Colors.white24),
                    _toolButton(
                      _selectedElement!.side == 'left' ? Icons.chevron_left : Icons.chevron_right,
                      () => setState(() {
                        _selectedElement!.side = _selectedElement!.side == 'left' ? 'right' : 'left';
                      }),
                      'Side: ${_selectedElement!.side.toUpperCase()}',
                    ),
                    _toolButton(Icons.delete, () => _removeElement(_selectedElement!), 'Del', color: Colors.red),
                  ],
                ],
              ),
            ),
          ),

          // Size Slider
          if (_selectedElement != null)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              right: _showAppBar || _selectedElement != null ? 20 : -100,
              top: 100,
              bottom: 150,
              child: Container(
                width: 50,
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: RotatedBox(
                  quarterTurns: 3,
                  child: Slider(
                    value: _selectedElement!.size,
                    min: 50,
                    max: 400,
                    divisions: 35,
                    label: _selectedElement!.size.toInt().toString(),
                    onChanged: (val) => setState(() => _selectedElement!.size = val),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _toolButton(IconData icon, VoidCallback onPressed, String label, {Color color = Colors.white}) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            Text(label, style: TextStyle(color: color, fontSize: 9)),
          ],
        ),
      ),
    );
  }
}

class _DraggableElement extends StatefulWidget {
  final ControlElement element;
  final bool isSelected;
  final BoxConstraints constraints;
  final double gridSize;
  final VoidCallback onTap;
  final VoidCallback onMove;

  const _DraggableElement({
    required this.element,
    required this.isSelected,
    required this.constraints,
    required this.gridSize,
    required this.onTap,
    required this.onMove,
  });

  @override
  State<_DraggableElement> createState() => _DraggableElementState();
}

class _DraggableElementState extends State<_DraggableElement> {
  late double _dragX;
  late double _dragY;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (_) {
        _dragX = widget.element.x;
        _dragY = widget.element.y;
        widget.onTap();
      },
      onPanUpdate: (details) {
        // Move freely during drag for smoothness
        _dragX += details.delta.dx / widget.constraints.maxWidth;
        _dragY += details.delta.dy / widget.constraints.maxHeight;
        
        // Clamp to screen
        widget.element.x = _dragX.clamp(0.0, 1.0 - (widget.element.size / widget.constraints.maxWidth));
        widget.element.y = _dragY.clamp(0.0, 1.0 - (widget.element.size / widget.constraints.maxHeight));
        
        widget.onMove();
      },
      onPanEnd: (_) {
        // Snap to grid on release
        setState(() {
          widget.element.x = _snap(widget.element.x);
          widget.element.y = _snap(widget.element.y);
        });
        widget.onMove();
      },
      onTap: widget.onTap,
      child: Container(
        width: widget.element.size,
        height: widget.element.size,
        decoration: BoxDecoration(
          border: Border.all(
            color: widget.isSelected ? Colors.blue : Colors.white24,
            width: widget.isSelected ? 3 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: widget.isSelected ? Colors.blue.withOpacity(0.2) : Colors.white10,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getIcon(widget.element.type),
              color: Colors.white70,
              size: widget.element.size * 0.3,
            ),
            const SizedBox(height: 4),
            Text(
              "${widget.element.type.name.toUpperCase()} (${widget.element.side == 'left' ? 'L' : 'R'})",
              style: TextStyle(
                color: Colors.white, 
                fontSize: (widget.element.size * 0.08).clamp(8, 14),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _snap(double value) {
    return (value / widget.gridSize).round() * widget.gridSize;
  }

  IconData _getIcon(ControlType type) {
    switch (type) {
      case ControlType.joystick: return Icons.circle;
      case ControlType.dpad: return Icons.apps;
      case ControlType.faceButtons: return Icons.grid_view;
      case ControlType.middleButtons: return Icons.more_horiz;
      case ControlType.bumper: return Icons.rectangle_outlined;
    }
  }
}

class GridPainter extends CustomPainter {
  final double gridSize;
  GridPainter({required this.gridSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1;

    for (double i = 0; i <= 1.0; i += gridSize) {
      canvas.drawLine(Offset(i * size.width, 0), Offset(i * size.width, size.height), paint);
      canvas.drawLine(Offset(0, i * size.height), Offset(size.width, i * size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
