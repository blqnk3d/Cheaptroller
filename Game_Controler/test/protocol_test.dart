import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_controler/protocol.dart';

void main() {
  group('MsgTypes constants', () {
    test('should have correct values', () {
      expect(MsgTypes.move, 0x01);
      expect(MsgTypes.buttonDown, 0x02);
      expect(MsgTypes.buttonUp, 0x03);
      expect(MsgTypes.heartbeat, 0x04);
      expect(MsgTypes.batch, 0x05);
    });
  });

  group('Sides constants', () {
    test('should have correct values', () {
      expect(Sides.left, 0);
      expect(Sides.right, 1);
    });
  });

  group('Priority constants', () {
    test('should have correct values', () {
      expect(Priority.high, 2);
      expect(Priority.medium, 1);
      expect(Priority.low, 0);
    });
  });

  group('InputEvent.move', () {
    test('should create move event with correct properties', () {
      final event = InputEvent.move(
        side: 'left',
        x: 0.5,
        y: -0.3,
        timestamp: 1000,
      );

      expect(event.type, InputType.move);
      expect(event.side, 'left');
      expect(event.x, 0.5);
      expect(event.y, -0.3);
      expect(event.timestamp, 1000);
      expect(event.index, 0);
      expect(event.priority, Priority.low);
    });

    test('should have correct byteSize for move', () {
      final event = InputEvent.move(
        side: 'left',
        x: 0.5,
        y: -0.3,
        timestamp: 1000,
      );

      expect(event.byteSize, 11);
    });
  });

  group('InputEvent.button', () {
    test('should create button pressed event', () {
      final event = InputEvent.button(
        side: 'right',
        index: 0,
        pressed: true,
        timestamp: 2000,
      );

      expect(event.type, InputType.button);
      expect(event.side, 'right');
      expect(event.index, 0);
      expect(event.pressed, true);
      expect(event.timestamp, 2000);
      expect(event.priority, Priority.high);
    });

    test('should create button released event', () {
      final event = InputEvent.button(
        side: 'left',
        index: 3,
        pressed: false,
        timestamp: 3000,
      );

      expect(event.pressed, false);
      expect(event.index, 3);
    });

    test('should have correct byteSize for button', () {
      final event = InputEvent.button(
        side: 'right',
        index: 0,
        pressed: true,
        timestamp: 2000,
      );

      expect(event.byteSize, 7);
    });
  });

  group('encodeMove', () {
    test('should encode move event with correct byte length', () {
      final bytes = encodeMove('left', 0.5, -0.3, 1000);

      expect(bytes.length, 11);
    });

    test('should set correct message type', () {
      final bytes = encodeMove('left', 0.5, -0.3, 1000);

      expect(bytes[0], MsgTypes.move);
    });

    test('should set correct side for left', () {
      final bytes = encodeMove('left', 0.5, -0.3, 1000);

      expect(bytes[1], Sides.left);
    });

    test('should set correct side for right', () {
      final bytes = encodeMove('right', 0.5, -0.3, 1000);

      expect(bytes[1], Sides.right);
    });

    test('should encode x value as int16 big endian', () {
      final bytes = encodeMove('left', 1.0, 0.0, 1000);
      final expectedX = (1.0 * 32767).round();

      final data = ByteData.sublistView(bytes, 2, 4);
      expect(data.getInt16(0, Endian.big), expectedX);
    });

    test('should encode y value as int16 big endian', () {
      final bytes = encodeMove('left', 0.0, -1.0, 1000);
      final expectedY = (-1.0 * 32767).round();

      final data = ByteData.sublistView(bytes, 4, 6);
      expect(data.getInt16(0, Endian.big), expectedY);
    });

    test('should encode timestamp at correct offset', () {
      final bytes = encodeMove('left', 0.5, -0.3, 12345678);

      final data = ByteData.sublistView(bytes, 6, 10);
      expect(data.getUint32(0, Endian.big), 12345678);
    });
  });

  group('encodeButton', () {
    test('should encode button down with correct length', () {
      final bytes = encodeButton('left', 0, true, 1000);

      expect(bytes.length, 7);
    });

    test('should set buttonDown message type for pressed', () {
      final bytes = encodeButton('left', 0, true, 1000);

      expect(bytes[0], MsgTypes.buttonDown);
    });

    test('should set buttonUp message type for released', () {
      final bytes = encodeButton('left', 0, false, 1000);

      expect(bytes[0], MsgTypes.buttonUp);
    });

    test('should set correct side byte', () {
      final bytes = encodeButton('right', 5, true, 1000);

      expect(bytes[1], Sides.right);
    });

    test('should set button index at correct offset', () {
      final bytes = encodeButton('left', 7, true, 1000);

      expect(bytes[2], 7);
    });

    test('should encode timestamp at correct offset', () {
      final bytes = encodeButton('left', 0, true, 9876543);

      final data = ByteData.sublistView(bytes, 3, 7);
      expect(data.getUint32(0, Endian.big), 9876543);
    });
  });

  group('encodeHeartbeat', () {
    test('should encode heartbeat with correct length', () {
      final bytes = encodeHeartbeat(1000);

      expect(bytes.length, 5);
    });

    test('should set heartbeat message type', () {
      final bytes = encodeHeartbeat(1000);

      expect(bytes[0], MsgTypes.heartbeat);
    });

    test('should encode timestamp at correct offset', () {
      final bytes = encodeHeartbeat(5555555);

      final data = ByteData.sublistView(bytes, 1, 5);
      expect(data.getUint32(0, Endian.big), 5555555);
    });
  });

  group('encodeBatch', () {
    test('should encode empty batch as empty Uint8List', () {
      final bytes = encodeBatch([]);

      expect(bytes.length, 0);
    });

    test('should set batch message type', () {
      final bytes = encodeBatch([
        InputEvent.move(side: 'left', x: 0.5, y: 0.0, timestamp: 1000),
      ]);

      expect(bytes[0], MsgTypes.batch);
    });

    test('should set correct event count', () {
      final bytes = encodeBatch([
        InputEvent.move(side: 'left', x: 0.5, y: 0.0, timestamp: 1000),
        InputEvent.button(
            side: 'right', index: 0, pressed: true, timestamp: 1001),
      ]);

      expect(bytes[1], 2);
    });

    test('should encode multiple events correctly', () {
      final events = [
        InputEvent.move(side: 'left', x: 0.5, y: 0.0, timestamp: 1000),
        InputEvent.button(
            side: 'right', index: 0, pressed: true, timestamp: 1001),
      ];
      final bytes = encodeBatch(events);

      final expectedLength = 2 + 11 + 7;
      expect(bytes.length, expectedLength);
    });

    test('should preserve event order in batch', () {
      final events = [
        InputEvent.move(side: 'left', x: 0.1, y: 0.2, timestamp: 1000),
        InputEvent.move(side: 'right', x: 0.3, y: 0.4, timestamp: 1001),
      ];
      final bytes = encodeBatch(events);

      expect(bytes[2], MsgTypes.move);
      expect(bytes[13], MsgTypes.move);
    });
  });

  group('InputEvent.toBytes', () {
    test('should convert move event to bytes', () {
      final event = InputEvent.move(
        side: 'left',
        x: 0.5,
        y: -0.3,
        timestamp: 1000,
      );

      final bytes = event.toBytes();

      expect(bytes.length, 11);
      expect(bytes[0], MsgTypes.move);
      expect(bytes[1], Sides.left);
    });

    test('should convert pressed button event to bytes', () {
      final event = InputEvent.button(
        side: 'right',
        index: 5,
        pressed: true,
        timestamp: 2000,
      );

      final bytes = event.toBytes();

      expect(bytes.length, 7);
      expect(bytes[0], MsgTypes.buttonDown);
      expect(bytes[2], 5);
    });

    test('should convert released button event to bytes', () {
      final event = InputEvent.button(
        side: 'left',
        index: 3,
        pressed: false,
        timestamp: 3000,
      );

      final bytes = event.toBytes();

      expect(bytes[0], MsgTypes.buttonUp);
    });
  });

  group('round trip encoding', () {
    test('should encode and decode move values correctly', () {
      final originalX = 0.5;
      final originalY = -0.75;

      final bytes = encodeMove('left', originalX, originalY, 1000);

      final data = ByteData.sublistView(bytes, 2, 6);
      final decodedX = data.getInt16(0, Endian.big) / 32767;
      final decodedY = data.getInt16(2, Endian.big) / 32767;

      expect(decodedX, closeTo(originalX, 0.001));
      expect(decodedY, closeTo(originalY, 0.001));
    });

    test('should encode max values correctly', () {
      final bytes = encodeMove('left', 1.0, 1.0, 1000);

      final data = ByteData.sublistView(bytes, 2, 6);
      expect(data.getInt16(0, Endian.big), 32767);
      expect(data.getInt16(2, Endian.big), 32767);
    });

    test('should encode min values correctly', () {
      final bytes = encodeMove('left', -1.0, -1.0, 1000);

      final data = ByteData.sublistView(bytes, 2, 6);
      expect(data.getInt16(0, Endian.big), -32767);
      expect(data.getInt16(2, Endian.big), -32767);
    });

    test('should encode zero values correctly', () {
      final bytes = encodeMove('left', 0.0, 0.0, 1000);

      final data = ByteData.sublistView(bytes, 2, 6);
      expect(data.getInt16(0, Endian.big), 0);
      expect(data.getInt16(2, Endian.big), 0);
    });
  });
}