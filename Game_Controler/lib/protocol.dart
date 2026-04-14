import 'dart:typed_data';

class MsgTypes {
  static const int move = 0x01;
  static const int buttonDown = 0x02;
  static const int buttonUp = 0x03;
  static const int heartbeat = 0x04;
  static const int batch = 0x05;
}

class Priority {
  static const int high = 2;
  static const int medium = 1;
  static const int low = 0;
}

class Sides {
  static const int left = 0;
  static const int right = 1;
}

enum InputType { move, button }

class InputEvent {
  final InputType type;
  final String side;
  final double x;
  final double y;
  final int index;
  final bool pressed;
  final int priority;
  final int timestamp;

  const InputEvent.move({
    required this.side,
    required this.x,
    required this.y,
    required this.timestamp,
  })  : type = InputType.move,
        index = 0,
        pressed = false,
        priority = Priority.low;

  const InputEvent.button({
    required this.side,
    required this.index,
    required this.pressed,
    required this.timestamp,
  })  : type = InputType.button,
        x = 0,
        y = 0,
        priority = Priority.high;

  int get byteSize => type == InputType.move ? 11 : 7;

  Uint8List toBytes() {
    if (type == InputType.move) {
      return encodeMove(side, x, y, timestamp);
    } else {
      return encodeButton(side, index, pressed, timestamp);
    }
  }
}

Uint8List encodeMove(String side, double x, double y, [int? timestamp]) {
  final data = ByteData(11);
  data.setUint8(0, MsgTypes.move);
  data.setUint8(1, side == 'left' ? Sides.left : Sides.right);
  data.setInt16(2, (x * 32767).round(), Endian.big);
  data.setInt16(4, (y * 32767).round(), Endian.big);
  data.setUint32(
      6, timestamp ?? DateTime.now().millisecondsSinceEpoch, Endian.big);
  return data.buffer.asUint8List();
}

Uint8List encodeButton(String side, int index, bool pressed, [int? timestamp]) {
  final data = ByteData(7);
  data.setUint8(0, pressed ? MsgTypes.buttonDown : MsgTypes.buttonUp);
  data.setUint8(1, side == 'left' ? Sides.left : Sides.right);
  data.setUint8(2, index);
  data.setUint32(
      3, timestamp ?? DateTime.now().millisecondsSinceEpoch, Endian.big);
  return data.buffer.asUint8List();
}

Uint8List encodeHeartbeat([int? timestamp]) {
  final data = ByteData(5);
  data.setUint8(0, MsgTypes.heartbeat);
  data.setUint32(
      1, timestamp ?? DateTime.now().millisecondsSinceEpoch, Endian.big);
  return data.buffer.asUint8List();
}

Uint8List encodeBatch(List<InputEvent> events) {
  if (events.isEmpty) return Uint8List(0);

  int totalSize = 1 + events.fold(0, (sum, e) => sum + e.byteSize);
  final buffer = ByteData(totalSize);

  buffer.setUint8(0, MsgTypes.batch);
  buffer.setUint8(1, events.length);

  int offset = 2;
  for (var event in events) {
    final bytes = event.toBytes();
    for (int i = 0; i < bytes.length; i++) {
      buffer.setUint8(offset + i, bytes[i]);
    }
    offset += bytes.length;
  }

  return buffer.buffer.asUint8List();
}
