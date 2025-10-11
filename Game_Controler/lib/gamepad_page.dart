import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import 'style.dart'; // <-- import your style.dart

class GamepadPage extends StatefulWidget {
  static const routeName = '/gamepad';
  const GamepadPage({super.key});

  @override
  State<GamepadPage> createState() => _GamepadPageState();
}

class _GamepadPageState extends State<GamepadPage> {
  RawDatagramSocket? socket;
  late InternetAddress serverAddress;
  static const int port = 8080;

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

    idleTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      for (var side in ['left', 'right']) {
        final pos = joystickPositions[side]!;
        final last = lastSentTime[side]!;
        final now = DateTime.now();
        if ((pos.dx != 0 || pos.dy != 0) || now.difference(last).inMilliseconds > 500) {
          sendMove(side, pos.dx, pos.dy);
          lastSentTime[side] = now;
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ip = ModalRoute.of(context)!.settings.arguments as String;
    serverAddress = InternetAddress(ip);
    RawDatagramSocket.bind(InternetAddress.anyIPv4, 0).then((s) {
      socket = s;
      setState(() {});
    });
  }

  @override
  void dispose() {
    socket?.close();
    idleTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void sendUDP(Map<String, dynamic> data) {
    if (socket == null) return;
    final bytes = utf8.encode(jsonEncode(data));
    socket!.send(bytes, serverAddress, port);
  }

  void sendMove(String side, double x, double y) {
    sendUDP({
      "type": "move",
      "side": side,
      "x": x,
      "y": y,
    });
  }

  void sendButton(String side, int index, bool pressed) {
    sendUDP({
      "type": pressed ? "button_down" : "button_up",
      "side": side,
      "index": index,
    });
  }

  Widget buildJoystick(String side) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final joystickSize = constraints.maxHeight * 0.5;
        final List<String> buttonLabels = side == 'left'
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
                              border: Border.all(color: AppColors.textPrimary, width: 2),
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
                        Text(
                          buttonLabels[i],
                          style: AppTextStyles.body,
                        ),
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
                child: side == 'left'
                    ? GestureDetector(
                        onPanDown: (_) {
                          hasMoved = false;
                        },
                        onPanEnd: (_) {
                          if (!hasMoved) {
                            sendButton("left", 0, true);
                            Future.delayed(const Duration(milliseconds: 100), () {
                              sendButton("left", 0, false);
                            });
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
                            if (details.x.abs() > 0.2 || details.y.abs() > 0.2) {
                              hasMoved = true;
                            }
                            joystickPositions[side] = Offset(details.x, details.y);
                            lastSentTime[side] = DateTime.now();
                            sendMove(side, details.x, details.y);
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
                          joystickPositions[side] = Offset(details.x, details.y);
                          lastSentTime[side] = DateTime.now();
                          sendMove(side, details.x, details.y);
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
          child: socket == null
              ? const Center(child: CircularProgressIndicator())
              : Row(
                  children: [
                    Expanded(child: buildJoystick("left")),
                    SizedBox(width: 150),
                    Expanded(child: buildJoystick("right")),
                  ],
                ),
        ),
      );
}
