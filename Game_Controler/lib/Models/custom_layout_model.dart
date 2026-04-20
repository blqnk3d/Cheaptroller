import 'dart:convert';

enum ControlType { joystick, dpad, faceButtons, middleButtons, bumper }

class ControlElement {
  final ControlType type;
  double x;
  double y;
  double size;
  String side; // 'left' or 'right'
  final String label;

  ControlElement({
    required this.type,
    required this.x,
    required this.y,
    required this.size,
    required this.side,
    this.label = '',
  });

  Map<String, dynamic> toJson() => {
    'type': type.index,
    'x': x,
    'y': y,
    'size': size,
    'side': side,
    'label': label,
  };

  factory ControlElement.fromJson(Map<String, dynamic> json) => ControlElement(
    type: ControlType.values[json['type'] as int],
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
    size: (json['size'] as num).toDouble(),
    side: json['side'] as String,
    label: json['label'] as String? ?? '',
  );
}

class CustomLayout {
  List<ControlElement> elements;

  CustomLayout({required this.elements});

  String toJson() => jsonEncode(elements.map((e) => e.toJson()).toList());

  factory CustomLayout.fromJson(String jsonStr) {
    if (jsonStr.isEmpty) return CustomLayout(elements: []);
    final List<dynamic> list = jsonDecode(jsonStr);
    return CustomLayout(
      elements: list.map((e) => ControlElement.fromJson(e)).toList(),
    );
  }

  factory CustomLayout.defaultLayout() {
    return CustomLayout(elements: [
      ControlElement(type: ControlType.joystick, x: 0.1, y: 0.5, size: 150, side: 'left'),
      ControlElement(type: ControlType.joystick, x: 0.7, y: 0.5, size: 150, side: 'right'),
      ControlElement(type: ControlType.faceButtons, x: 0.7, y: 0.2, size: 150, side: 'right'),
      ControlElement(type: ControlType.dpad, x: 0.1, y: 0.2, size: 150, side: 'left'),
    ]);
  }
}
