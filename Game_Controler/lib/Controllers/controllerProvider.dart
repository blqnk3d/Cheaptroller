import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:game_controler/Settings/settingsProvider.dart';
import 'package:game_controler/protocol.dart';

class ControllerProvider extends ChangeNotifier {
  RawDatagramSocket? _socket;
  InternetAddress? _serverAddress;
  bool _isSocketReady = false;
  SettingsProvider? _settings;

  static const int _port = 8080;
  static const double _deadzone = 0.05;
  static const int _batchWindowMs = 5;
  static const int _maxBatchSize = 10;
  static const int _joystickRateMs = 16;

  final Queue<InputEvent> _inputQueue = Queue();
  Timer? _batchTimer;
  Timer? _joystickTimer;

  final Map<String, Offset> _joystickPositions = {
    'left': const Offset(0, 0),
    'right': const Offset(0, 0),
  };
  final Map<String, bool> _joystickChanged = {
    'left': false,
    'right': false,
  };
  final Map<String, DateTime> _lastJoystickSend = {
    'left': DateTime.now(),
    'right': DateTime.now(),
  };

  bool get isConnected => _isSocketReady;

  Future<void> init(SettingsProvider settings) async {
    _settings = settings;
    settings.addListener(_onSettingsChanged);
    await _initSocket(settings);
  }

  void _onSettingsChanged() {
    if (_settings != null) {
      _initSocket(_settings!);
    }
  }

  Future<void> _initSocket(SettingsProvider settings) async {
    if (settings.ipAddress.isEmpty) {
      _socket?.close();
      _serverAddress = null;
      setSocketReady(false);
      return;
    }

    if (_socket != null && _serverAddress?.address == settings.ipAddress) {
      return;
    }

    _socket?.close();
    _serverAddress = null;
    setSocketReady(false);

    try {
      _serverAddress = InternetAddress(settings.ipAddress);
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      setSocketReady(true);
      _startTimers();
    } catch (e) {
      debugPrint('[ControllerProvider] Init failed: $e');
      setSocketReady(false);
    }
  }

  void setSocketReady(bool ready) {
    _isSocketReady = ready;
    notifyListeners();
  }

  void _startTimers() {
    _batchTimer?.cancel();
    _joystickTimer?.cancel();

    _batchTimer = Timer.periodic(
      const Duration(milliseconds: _batchWindowMs),
      (_) => _flushBatch(),
    );

    _joystickTimer = Timer.periodic(
      const Duration(milliseconds: _joystickRateMs),
      (_) => _sendJoystickUpdates(),
    );
  }

  void _sendJoystickUpdates() {
    final now = DateTime.now();
    for (final side in ['left', 'right']) {
      if (_joystickChanged[side] == true) {
        final pos = _joystickPositions[side]!;
        final last = _lastJoystickSend[side]!;
        if (now.difference(last).inMilliseconds >= _joystickRateMs) {
          queueMove(side, pos.dx, pos.dy);
          _lastJoystickSend[side] = now;
        }
      }
    }
  }

  void queueMove(String side, double x, double y) {
    if (_inputQueue.length >= _maxBatchSize) {
      _inputQueue.removeFirst();
    }
    _inputQueue.addLast(InputEvent.move(
      side: side,
      x: x,
      y: y,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  void _flushBatch() {
    if (_inputQueue.isEmpty || !_isSocketReady || _socket == null || _serverAddress == null) {
      return;
    }

    final events = List<InputEvent>.from(_inputQueue);
    _inputQueue.clear();

    Uint8List data;
    if (events.length == 1) {
      data = events.first.toBytes();
    } else {
      data = encodeBatch(events);
    }

    _socket!.send(data, _serverAddress!, _port);
  }

  void sendMove(String side, double x, double y) {
    final clampedX = x.abs() < _deadzone ? 0.0 : x;
    final clampedY = y.abs() < _deadzone ? 0.0 : y;
    _joystickPositions[side] = Offset(clampedX, clampedY);
    _joystickChanged[side] = true;
  }

  void sendButton(String side, int index, bool pressed) {
    if (!_isSocketReady || _socket == null || _serverAddress == null) {
      return;
    }

    final bytes = encodeButton(
      side,
      index,
      pressed,
      DateTime.now().millisecondsSinceEpoch,
    );
    _socket!.send(bytes, _serverAddress!, _port);
  }

  @override
  void dispose() {
    _settings?.removeListener(_onSettingsChanged);
    _batchTimer?.cancel();
    _joystickTimer?.cancel();
    _socket?.close();
    super.dispose();
  }
}