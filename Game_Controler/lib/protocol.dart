import 'dart:typed_data';

class MsgTypes {
  static const int move = 0x01;
  static const int buttonDown = 0x02;
  static const int buttonUp = 0x03;
  static const int heartbeat = 0x04;
}

class Sides {
  static const int left = 0;
  static const int right = 1;
}

ByteData _createByteData(int length) {
  return ByteData(length);
}

int _swap16(int value) {
  return ((value & 0xFF) << 8) | ((value >> 8) & 0xFF);
}

int _swap32(int value) {
  return ((value & 0xFF) << 24) |
      ((value & 0xFF00) << 8) |
      ((value >> 8) & 0xFF00) |
      ((value >> 24) & 0xFF);
}

Uint8List encodeMove(String side, double x, double y, [int? timestamp]) {
  final data = _createByteData(11);
  data.setUint8(0, MsgTypes.move);
  data.setUint8(1, side == 'left' ? Sides.left : Sides.right);
  data.setInt16(2, (x * 32767).round(), Endian.big);
  data.setInt16(4, (y * 32767).round(), Endian.big);
  data.setUint32(
      6, timestamp ?? DateTime.now().millisecondsSinceEpoch, Endian.big);
  return data.buffer.asUint8List();
}

Uint8List encodeButton(String side, int index, bool pressed, [int? timestamp]) {
  final data = _createByteData(7);
  data.setUint8(0, pressed ? MsgTypes.buttonDown : MsgTypes.buttonUp);
  data.setUint8(1, side == 'left' ? Sides.left : Sides.right);
  data.setUint8(2, index);
  data.setUint32(
      3, timestamp ?? DateTime.now().millisecondsSinceEpoch, Endian.big);
  return data.buffer.asUint8List();
}

Uint8List encodeHeartbeat([int? timestamp]) {
  final data = _createByteData(5);
  data.setUint8(0, MsgTypes.heartbeat);
  data.setUint32(
      1, timestamp ?? DateTime.now().millisecondsSinceEpoch, Endian.big);
  return data.buffer.asUint8List();
}
