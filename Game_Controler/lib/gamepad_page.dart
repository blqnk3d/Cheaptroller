import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import 'package:game_controler/settingsProvider.dart';
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
  InternetAddress? serverAddress; // Make this nullable
  bool _isSocketReady = false; // State to track if socket is ready

  static const int port = 8080;
  static const double deadzone = 0.1;

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
      print("Socket bound successfully to IP: ${serverAddress?.address}");
    } catch (e) {
      print("Failed to bind socket: $e");
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initSocket();
  }

  @override
  void dispose() {
    socket?.close();
    idleTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void sendUDP(Map<String, dynamic> data) {

    if (!_isSocketReady || socket == null || serverAddress == null) {
      print("Socket not ready or address is null, cannot send data.");
      return;
    }
    final bytes = utf8.encode(jsonEncode(data));
    socket!.send(bytes, serverAddress!, port);
  }

  void sendMove(String side, double x, double y) {
    print(x);
    print(y);
    sendUDP({"type": "move", "side": side, "x": x, "y": y});
  }

  void sendButton(String side, int index, bool pressed) {
    sendUDP({
      "type": pressed ? "button_down" : "button_up",
      "side": side,
      "index": index,
    });
  }

  // buildJoystick method remains the same
  Widget buildJoystick(String side) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final joystickSize = constraints.maxHeight * 0.5;
        final List<String> buttonLabels =
            side == 'left'
                ? ['Left Click', 'Right Click', 'Middle Mouse']
                : ['R1', 'R2', 'R3'];
        bool hasMoved = false;

        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Buttons row
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
                                color: AppColors.textPrimary,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.circle,
                              color: AppColors.textSecondary,
                              size: 32,
                            ),
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

              // Joystick area
              SizedBox(
                width: joystickSize,
                height: joystickSize,
                child:
                    side == 'left'
                        ? GestureDetector(
                          onPanDown: (_) {
                            hasMoved = false;
                          },
                          onPanEnd: (_) {
                            if (!hasMoved) {
                              sendButton("left", 0, true);
                              Future.delayed(
                                const Duration(milliseconds: 100),
                                () {
                                  sendButton("left", 0, false);
                                },
                              );
                            }
                          },
                          child: Joystick(
                            mode: JoystickMode.all,
                            stick: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: AppColors.joyStick,
                                shape: BoxShape.circle,
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                    offset: Offset(2, 2),
                                  ),
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
                              hasMoved = true; // Set flag on move
                              double x =
                                  (details.x.abs() < deadzone) ? 0 : details.x;
                              double y =
                                  (details.y.abs() < deadzone) ? 0 : details.y;

                              joystickPositions[side] = Offset(x, y);
                              lastSentTime[side] = DateTime.now();

                              if (x != 0 || y != 0) {
                                sendMove(side, x, y);
                              }
                            },
                          ),
                        )
                        : Joystick(
                          mode: JoystickMode.all,
                          stick: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: AppColors.joyStick,
                              shape: BoxShape.circle,
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  offset: Offset(2, 2),
                                ),
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
                            double x =
                                (details.x.abs() < deadzone) ? 0 : details.x;
                            double y =
                                (details.y.abs() < deadzone) ? 0 : details.y;

                            joystickPositions[side] = Offset(x, y);
                            lastSentTime[side] = DateTime.now();
                            print(x);
                            print(y);

                            if (x.abs() > deadzone || y.abs() > deadzone) {
                              sendMove(side, x, y);
                            }
                          },
                        ),
              ),
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
      child:
          _isSocketReady
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