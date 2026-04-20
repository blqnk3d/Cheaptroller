import 'package:flutter_test/flutter_test.dart';
import 'package:game_controler/Models/custom_layout_model.dart';

void main() {
  group('ControlElement', () {
    test('should create with required parameters', () {
      final element = ControlElement(
        type: ControlType.joystick,
        x: 0.5,
        y: 0.5,
        size: 100,
        side: 'left',
      );

      expect(element.type, ControlType.joystick);
      expect(element.x, 0.5);
      expect(element.y, 0.5);
      expect(element.size, 100);
      expect(element.side, 'left');
      expect(element.label, '');
    });

    test('should serialize to JSON', () {
      final element = ControlElement(
        type: ControlType.dpad,
        x: 0.1,
        y: 0.2,
        size: 150,
        side: 'right',
        label: 'D-Pad',
      );

      final json = element.toJson();

      expect(json['type'], ControlType.dpad.index);
      expect(json['x'], 0.1);
      expect(json['y'], 0.2);
      expect(json['size'], 150);
      expect(json['side'], 'right');
      expect(json['label'], 'D-Pad');
    });

    test('should deserialize from JSON', () {
      final json = <String, dynamic>{
        'type': ControlType.faceButtons.index,
        'x': 0.7,
        'y': 0.3,
        'size': 120,
        'side': 'left',
        'label': 'ABXY',
      };

      final element = ControlElement.fromJson(json);

      expect(element.type, ControlType.faceButtons);
      expect(0.7, element.x);
      expect(0.3, element.y);
      expect(120.0, element.size);
      expect(element.side, 'left');
      expect(element.label, 'ABXY');
    });

    test('should handle round trip serialization', () {
      final original = ControlElement(
        type: ControlType.bumper,
        x: 0.25,
        y: 0.1,
        size: 80,
        side: 'right',
        label: 'RB',
      );

      final json = original.toJson();
      final restored = ControlElement.fromJson(json);

      expect(restored.type, original.type);
      expect(0.25, restored.x);
      expect(0.1, restored.y);
      expect(80.0, restored.size);
      expect(restored.side, original.side);
      expect(restored.label, original.label);
    });
  });

  group('CustomLayout', () {
    test('should create default layout', () {
      final layout = CustomLayout.defaultLayout();

      expect(layout.elements.length, 4);
      expect(layout.elements[0].type, ControlType.joystick);
      expect(layout.elements[0].side, 'left');
      expect(layout.elements[1].side, 'right');
    });

    test('should serialize to JSON', () {
      final layout = CustomLayout(
        elements: [
          ControlElement(
            type: ControlType.joystick,
            x: 0.1,
            y: 0.5,
            size: 150,
            side: 'left',
          ),
        ],
      );

      final json = layout.toJson();
      expect(json, isA<String>());
      expect(json.contains('type'), true);
    });

    test('should deserialize from JSON', () {
      final json =
          '[{"type":0,"x":0.1,"y":0.5,"size":150,"side":"left","label":""}]';

      final layout = CustomLayout.fromJson(json);

      expect(layout.elements.length, 1);
      expect(layout.elements[0].type, ControlType.joystick);
      expect(layout.elements[0].side, 'left');
    });

    test('should return empty layout for empty string', () {
      final layout = CustomLayout.fromJson('');

      expect(layout.elements, isEmpty);
    });
  });

  group('ControlType', () {
    test('should have all expected values', () {
      expect(ControlType.values.length, 5);
      expect(ControlType.values, contains(ControlType.joystick));
      expect(ControlType.values, contains(ControlType.dpad));
      expect(ControlType.values, contains(ControlType.faceButtons));
      expect(ControlType.values, contains(ControlType.middleButtons));
      expect(ControlType.values, contains(ControlType.bumper));
    });
  });
}