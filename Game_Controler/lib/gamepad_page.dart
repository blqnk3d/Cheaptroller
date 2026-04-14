import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import 'package:game_controler/Settings/settingsProvider.dart';
import 'package:game_controler/protocol.dart';
import 'package:provider/provider.dart';
import 'style.dart';

class GamepadPage extends StatefulWidget {
  static const routeName = '/gamepad';
  const GamepadPage({super.key});

  @override
  State<GamepadPage> createState() => _GamepadPageState();
}

class _GamepadPageState extends State<GamepadPage> {
  RawDatagramSocket? socket;
  InternetAddress? serverAddress;
  bool _isSocketReady = false;
  bool _didInitSocket = false;

  static const int port = 8080;
  static const double deadzone = 0.05;
  static const int batchWindowMs = 5;
  static const int maxBatchSize = 10;
  static const int joystickRateMs = 16;
  static const bool debugProtocol = false;

  final Queue<InputEvent> _inputQueue = Queue();
  Timer? _batchTimer;
  Timer? _joystickTimer;

  Map<String, Offset> _joystickPositions = {
    "left": const Offset(0, 0),
    "right": const Offset(0, 0),
  };

  Map<String, bool> _joystickChanged = {
    "left": false,
    "right": false,
  };

  Map<String, DateTime> _lastJoystickSend = {
    "left": DateTime.now(),
    "right": DateTime.now(),
  };

  void _debugLog(String msg) {
    if (debugProtocol) {
      print("[PROTOCOL] $msg");
    }
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _startBatchTimer();
    _startJoystickTimer();
  }

  void _startBatchTimer() {
    _batchTimer = Timer.periodic(
      Duration(milliseconds: batchWindowMs),
      (_) => _flushBatch(),
    );
  }

  void _startJoystickTimer() {
    _joystickTimer = Timer.periodic(
      Duration(milliseconds: joystickRateMs),
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
      _debugLog(
          "BUTTON ${event.pressed ? 'DOWN' : 'UP'} side=${event.side} index=${event.index} (immediate)");
      sendUDP(event.toBytes());
      return;
    }

    _debugLog(
        "MOVE side=${event.side} x=${event.x.toStringAsFixed(2)} y=${event.y.toStringAsFixed(2)} (queued)");
    if (_inputQueue.length >= maxBatchSize) {
      _inputQueue.removeFirst();
    }
    _inputQueue.addLast(event);
  }

  void _flushBatch() {
    if (_inputQueue.isEmpty) return;

    final List<InputEvent> events = List.from(_inputQueue);
    _inputQueue.clear();

    _debugLog("FLUSH batch with ${events.length} events");
    if (events.length == 1) {
      sendUDP(events.first.toBytes());
    } else {
      sendUDP(encodeBatch(events));
    }
  }

  Future<void> _initSocket() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final newIp = settings.ipAddress;

    if (newIp == serverAddress?.address && socket != null) {
      return;
    }

    setState(() {
      _isSocketReady = false;
    });

    socket?.close();

    try {
      serverAddress = InternetAddress(newIp);
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      setState(() {
        _isSocketReady = true;
      });
    } catch (e) {}
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInitSocket) {
      _initSocket();
      _didInitSocket = true;
    }
  }

  @override
  void dispose() {
    socket?.close();
    _batchTimer?.cancel();
    _joystickTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void sendUDP(Uint8List data) {
    if (!_isSocketReady || socket == null || serverAddress == null) {
      return;
    }
    socket!.send(data, serverAddress!, port);
  }

  void sendMove(String side, double x, double y) {
    final now = DateTime.now();
    _joystickPositions[side] = Offset(x, y);
    _joystickChanged[side] = true;
    _lastJoystickSend[side] = now;
  }

  void sendButton(String side, int index, bool pressed) {
    _queueInput(InputEvent.button(
      side: side,
      index: index,
      pressed: pressed,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  Widget buildJoystick(String side) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final joystickSize = constraints.maxHeight * 0.5;
        final List<String> buttonLabels = side == 'left'
            ? ['Left Click', 'Right Click', 'Middle Mouse']
            : ['R1', 'R2', 'R3'];

        Widget joystickWidget = Joystick(
          mode: JoystickMode.all,
          stick: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.joyStick,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                    color: Colors.black26, blurRadius: 4, offset: Offset(2, 2))
              ],
            ),
          ),
          base: Container(
            width: joystickSize,
            height: joystickSize,
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              shape: BoxShape.circle,
            ),
          ),
          listener: (details) {
            double x = (details.x.abs() < deadzone) ? 0 : details.x;
            double y = (details.y.abs() < deadzone) ? 0 : details.y;
            sendMove(side, x, y);
          },
        );

        if (side == 'left') {
          joystickWidget = GestureDetector(
            onPanEnd: (_) {
              _joystickPositions[side] = const Offset(0, 0);
              _joystickChanged[side] = true;
              sendMove(side, 0, 0);
            },
            child: joystickWidget,
          );
        } else {
          joystickWidget = GestureDetector(
            onPanEnd: (_) {
              _joystickPositions[side] = const Offset(0, 0);
              _joystickChanged[side] = true;
              sendMove(side, 0, 0);
            },
            child: joystickWidget,
          );
        }

        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  return Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTapDown: (_) => sendButton(side, i, true),
                          onTapUp: (_) => sendButton(side, i, false),
                          onTapCancel: () => sendButton(side, i, false),
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              border: Border.all(
                                  color: AppColors.textPrimary, width: 2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.circle,
                                color: AppColors.textSecondary, size: 32),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(buttonLabels[i], style: AppTextStyles.body),
                      ],
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              SizedBox(
                  width: joystickSize,
                  height: joystickSize,
                  child: joystickWidget),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: _isSocketReady
              ? Row(
                  children: [
                    Expanded(child: buildJoystick("left")),
                    const SizedBox(width: 150),
                    Expanded(child: buildJoystick("right")),
                  ],
                )
              : const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text("Connecting..."),
                    ],
                  ),
                ),
        ),
      );
}
