import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _layout = context.read<SettingsProvider>().customLayout;
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
        x: 0.5,
        y: 0.5,
        size: 100,
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
      appBar: AppBar(
        title: const Text('Layout Editor'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveLayout),
        ],
      ),
      body: Stack(
        children: [
          // Canvas
          GestureDetector(
            onTap: () => setState(() => _selectedElement = null),
            child: Container(
              color: Colors.black12,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: _layout.elements.map((element) {
                      return Positioned(
                        left: element.x * constraints.maxWidth,
                        top: element.y * constraints.maxHeight,
                        child: GestureDetector(
                          onPanUpdate: (details) {
                            setState(() {
                              element.x += details.delta.dx / constraints.maxWidth;
                              element.y += details.delta.dy / constraints.maxHeight;
                              _selectedElement = element;
                            });
                          },
                          onTap: () => setState(() => _selectedElement = element),
                          child: Container(
                            width: element.size,
                            height: element.size,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _selectedElement == element ? Colors.blue : Colors.white38,
                                width: 2,
                              ),
                              color: Colors.white10,
                            ),
                            child: Center(
                              child: Text(
                                element.type.name,
                                style: const TextStyle(color: Colors.white, fontSize: 10),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ),
          
          // Toolbar
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _toolButton(Icons.circle, () => _addElement(ControlType.joystick), 'Joy'),
                _toolButton(Icons.apps, () => _addElement(ControlType.dpad), 'DPad'),
                _toolButton(Icons.grid_view, () => _addElement(ControlType.faceButtons), 'Face'),
                _toolButton(Icons.more_horiz, () => _addElement(ControlType.middleButtons), 'Mid'),
                if (_selectedElement != null)
                  _toolButton(Icons.delete, () => _removeElement(_selectedElement!), 'Del', color: Colors.red),
              ],
            ),
          ),

          // Size Slider
          if (_selectedElement != null)
            Positioned(
              right: 20,
              top: 100,
              bottom: 100,
              child: RotatedBox(
                quarterTurns: 3,
                child: Slider(
                  value: _selectedElement!.size,
                  min: 50,
                  max: 300,
                  onChanged: (val) => setState(() => _selectedElement!.size = val),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _toolButton(IconData icon, VoidCallback onPressed, String label, {Color color = Colors.white}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(icon: Icon(icon, color: color), onPressed: onPressed),
        Text(label, style: TextStyle(color: color, fontSize: 10)),
      ],
    );
  }
}
