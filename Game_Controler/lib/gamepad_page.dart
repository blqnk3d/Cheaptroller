import 'dart:async';
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
  static const double deadzone = 0.01;

  Map<String, Offset> joystickPositions = {
    "left": const Offset(0, 0),
    "right": const Offset(0, 0),
  };

  Map<String, DateTime> lastSentTime = {
    "left": DateTime.now(),
    "right": DateTime.now(),
  };

  Timer? idleTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    /*
    idleTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      for (var side in ['left', 'right']) {
        final pos = joystickPositions[side]!;
        final last = lastSentTime[side]!;
        final now = DateTime.now();
        if ((pos.dx != 0 || pos.dy != 0) ||
            now.difference(last).inMilliseconds > 500) {
          sendMove(side, pos.dx, pos.dy);
          lastSentTime[side] = now;
        }
      }
    });*/
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
    } catch (e) {
      // Socket initialization failed
    }
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
    idleTimer?.cancel();
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
    sendUDP(encodeMove(side, x, y));
  }

  void sendButton(String side, int index, bool pressed) {
    sendUDP(encodeButton(side, index, pressed));
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

            joystickPositions[side] = Offset(x, y);
            lastSentTime[side] = DateTime.now();
            sendMove(side, x, y);
          },
        );

        if (side == 'left') {
          joystickWidget = GestureDetector(
            onPanEnd: (_) {
              // Send (0,0) when released
              joystickPositions[side] = const Offset(0, 0);
              sendMove(side, 0, 0);
            },
            child: joystickWidget,
          );
        } else {
          joystickWidget = GestureDetector(
            onPanEnd: (_) {
              joystickPositions[side] = const Offset(0, 0);
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
