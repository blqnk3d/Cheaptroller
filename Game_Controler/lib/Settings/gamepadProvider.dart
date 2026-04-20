import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:game_controler/protocol.dart';
import 'package:vibration/vibration.dart';

class GamepadProvider extends ChangeNotifier {
  RawDatagramSocket? _socket;
  InternetAddress? _serverAddress;
  bool _isSocketReady = false;
  
  String _currentIp = '';
  int _port = 8080;

  static const int batchWindowMs = 5;
  static const int maxBatchSize = 10;
  static const int joystickRateMs = 16;
  static const double deadzone = 0.05;

  final Queue<InputEvent> _inputQueue = Queue();
  Timer? _batchTimer;
  Timer? _joystickTimer;

  final Map<String, Offset> _joystickPositions = {
    "left": const Offset(0, 0),
    "right": const Offset(0, 0),
  };

  final Map<String, bool> _joystickChanged = {
    "left": false,
    "right": false,
  };

  final Map<String, DateTime> _lastJoystickSend = {
    "left": DateTime.now(),
    "right": DateTime.now(),
  };

  bool get isSocketReady => _isSocketReady;

  GamepadProvider() {
    _startBatchTimer();
    _startJoystickTimer();
  }

  void updateServer(String ip, {int port = 8080}) {
    if (_currentIp == ip && _port == port && _socket != null) return;
    
    _currentIp = ip;
    _port = port;
    _initSocket();
  }

  Future<void> _initSocket() async {
    _isSocketReady = false;
    notifyListeners();
    
    _socket?.close();
    
    if (_currentIp.isEmpty) return;

    try {
      _serverAddress = InternetAddress(_currentIp);
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _isSocketReady = true;
      notifyListeners();
    } catch (e) {
      debugPrint("Socket error: $e");
    }
  }

  void _startBatchTimer() {
    _batchTimer?.cancel();
    _batchTimer = Timer.periodic(
      const Duration(milliseconds: batchWindowMs),
      (_) => _flushBatch(),
    );
  }

  void _startJoystickTimer() {
    _joystickTimer?.cancel();
    _joystickTimer = Timer.periodic(
      const Duration(milliseconds: joystickRateMs),
      (_) => _sendJoystickUpdates(),
    );
  }

  void _sendJoystickUpdates() {
    final now = DateTime.now();
    for (var side in ['left', 'right']) {
      if (_joystickChanged[side] == true) {
        final pos = _joystickPositions[side]!;
        final last = _lastJoystickSend[side]!;
        if (now.difference(last).inMilliseconds >= joystickRateMs) {
          _queueInput(InputEvent.move(
            side: side,
            x: pos.dx,
            y: pos.dy,
            timestamp: now.millisecondsSinceEpoch,
          ));
          _lastJoystickSend[side] = now;
        }
      }
    }
  }

  void _queueInput(InputEvent event) {
    if (event.type == InputType.button) {
      _sendUDP(event.toBytes());
      return;
    }

    if (_inputQueue.length >= maxBatchSize) {
      _inputQueue.removeFirst();
    }
    _inputQueue.addLast(event);
  }

  void _flushBatch() {
    if (_inputQueue.isEmpty) return;

    final List<InputEvent> events = List.from(_inputQueue);
    _inputQueue.clear();

    if (events.length == 1) {
      _sendUDP(events.first.toBytes());
    } else {
      _sendUDP(encodeBatch(events));
    }
  }

  void _sendUDP(Uint8List data) {
    if (!_isSocketReady || _socket == null || _serverAddress == null) return;
    _socket!.send(data, _serverAddress!, _port);
  }

  void sendMove(String side, double x, double y) {
    double xVal = x.abs() < deadzone ? 0 : x;
    double yVal = y.abs() < deadzone ? 0 : y;
    
    _joystickPositions[side] = Offset(xVal, yVal);
    _joystickChanged[side] = true;
    _lastJoystickSend[side] = DateTime.now();
  }

  void sendButton(String side, int index, bool pressed, {bool haptic = true}) {
    if (pressed && haptic) {
      Vibration.vibrate(duration: 15, amplitude: 128);
    }

    _queueInput(InputEvent.button(
      side: side,
      index: index,
      pressed: pressed,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  @override
  void dispose() {
    _socket?.close();
    _batchTimer?.cancel();
    _joystickTimer?.cancel();
    super.dispose();
  }
}
