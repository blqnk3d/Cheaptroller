// lib/Xbox_Controller.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import 'package:game_controler/Settings/settingsProvider.dart';
import 'package:provider/provider.dart';
import '../style.dart';

class Xbox_Controller extends StatefulWidget {
  static const routeName = '/xbox_controller';
  const Xbox_Controller({super.key});

  @override
  State<Xbox_Controller> createState() => _Xbox_ControllerState();
}

class _Xbox_ControllerState extends State<Xbox_Controller> {
  // ---------- SCALING CONSTANT ----------
  static const double scaleFactor = 1.10; // Change this to resize buttons/joysticks

  RawDatagramSocket? socket;
  InternetAddress? serverAddress;
  bool _isSocketReady = false;

  static const int port = 8080;
  static const double deadzone = 0.01;
  final Set<String> _pressedButtons = {};

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _initSocket() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final newIp = settings.ipAddress;

    if (newIp == serverAddress?.address && socket != null) return;

    setState(() => _isSocketReady = false);
    socket?.close();

    try {
      serverAddress = InternetAddress(newIp);
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      setState(() => _isSocketReady = true);
    } catch (e) {
      print("Socket error: $e");
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
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void sendUDP(Map<String, dynamic> data) {
    if (!_isSocketReady || socket == null || serverAddress == null) return;
    final bytes = utf8.encode(jsonEncode(data));
    socket!.send(bytes, serverAddress!, port);
  }

  void sendMove(String side, double x, double y) {
    sendUDP({"type": "move", "side": side, "x": x, "y": y});
  }

  void sendButton(String side, int index, bool pressed) {
    sendUDP({
      "type": pressed ? "button_down" : "button_up",
      "side": side,
      "index": index,
    });

    final key = "${side}_$index";
    setState(() {
      if (pressed) {
        _pressedButtons.add(key);
      } else {
        _pressedButtons.remove(key);
      }
    });
  }

  Widget _dpadButton(String dir, double btnSize) {
    int index;
    switch (dir) {
      case 'up':
        index = 6;
        break;
      case 'down':
        index = 7;
        break;
      case 'left':
        index = 4;
        break;
      case 'right':
        index = 5;
        break;
      default:
        index = 0;
    }

    final key = "left_$index";
    final isPressed = _pressedButtons.contains(key);

    return GestureDetector(
      onTapDown: (_) => sendButton('left', index, true),
      onTapUp: (_) => sendButton('left', index, false),
      onTapCancel: () => sendButton("left", index, false),
      child: Container(
        width: btnSize * scaleFactor,
        height: btnSize * scaleFactor,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isPressed
              ? Colors.greenAccent.withOpacity(0.6)
              : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(6 * scaleFactor),
          border: Border.all(color: AppColors.textPrimary, width: 1.3 * scaleFactor),
        ),
        child: Icon(
          dir == 'up'
              ? Icons.keyboard_arrow_up
              : dir == 'down'
                  ? Icons.keyboard_arrow_down
                  : dir == 'left'
                      ? Icons.keyboard_arrow_left
                      : Icons.keyboard_arrow_right,
          color: AppColors.textPrimary,
          size: btnSize * 0.6 * scaleFactor,
        ),
      ),
    );
  }

  Widget _faceButton(String label, int index, double size, Color color) {
    final key = "right_$index";
    final isPressed = _pressedButtons.contains(key);

    return GestureDetector(
      onTapDown: (_) => sendButton('right', index, true),
      onTapUp: (_) => sendButton('right', index, false),
      onTapCancel: () => sendButton("right", index, false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: size * scaleFactor,
        height: size * scaleFactor,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isPressed ? color.withOpacity(0.7) : AppColors.cardBackground,
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2 * scaleFactor),
        ),
        child: Text(
          label,
          style: AppTextStyles.body.copyWith(
            fontSize: size * 0.4 * scaleFactor,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _topButton(String label, int index, String side) {
    final key = "${side}_$index";
    final isPressed = _pressedButtons.contains(key);

    // Keep View/Menu buttons unchanged
    final bool isCenterButton = label == "View" || label == "Menu";
    final double scale = isCenterButton ? 1.0 : scaleFactor;

    return GestureDetector(
      onTapDown: (_) => sendButton(side, index, true),
      onTapUp: (_) => sendButton(side, index, false),
      onTapCancel: () => sendButton(side, index, false),
      child: Container(
        padding: EdgeInsets.symmetric(
            vertical: 6 * scale, horizontal: 14 * scale),
        decoration: BoxDecoration(
          color: isPressed
              ? Colors.greenAccent.withOpacity(0.5)
              : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(10 * scale),
          border: Border.all(color: AppColors.textPrimary, width: 1.5 * scale),
        ),
        child: Text(label,
            style: AppTextStyles.body.copyWith(
              fontSize: 14 * scale,
            )),
      ),
    );
  }

  Widget _buildDPad(double size) {
    final btnSize = size * 0.34;
    return SizedBox(
      width: size * scaleFactor,
      height: size * scaleFactor,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(top: 0, child: _dpadButton('up', btnSize)),
          Positioned(bottom: 0, child: _dpadButton('down', btnSize)),
          Positioned(left: 0, child: _dpadButton('left', btnSize)),
          Positioned(right: 0, child: _dpadButton('right', btnSize)),
        ],
      ),
    );
  }

  Widget _buildFaceButtons(double size) {
    final b = size * 0.34;
    return SizedBox(
      width: size * scaleFactor,
      height: size * scaleFactor,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(bottom: 0, child: _faceButton('A', 0, b, Colors.green)),
          Positioned(right: 0, child: _faceButton('B', 1, b, Colors.red)),
          Positioned(left: 0, child: _faceButton('X', 2, b, Colors.blue)),
          Positioned(top: 0, child: _faceButton('Y', 3, b, Colors.yellow)),
        ],
      ),
    );
  }

  Widget _buildTopBumpers(double width) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: width * 0, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _topButton('LB', 4, 'left'),
          _topButton('RB', 5, 'right'),
        ],
      ),
    );
  }

  Widget _centerButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _topButton('View', 8, 'left'),
        const SizedBox(width: 14),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.green, width: 2),
          ),
          child: Icon(Icons.home, color: Colors.green, size: 22),
        ),
        const SizedBox(width: 14),
        _topButton('Menu', 9, 'right'),
      ],
    );
  }

  Widget buildJoystick(String side, double size) {
    final int bottomBumperIndex = side == 'left' ? 6 : 7;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onDoubleTap: () {
            Future.delayed(const Duration(milliseconds: 150), () {
              sendButton(side, bottomBumperIndex, true);
              Future.delayed(const Duration(milliseconds: 100), () {
                sendButton(side, bottomBumperIndex, false);
              });
            });
          },
          child: Joystick(
            mode: JoystickMode.all,
            stick: Container(
              width: size * 0.32 * scaleFactor,
              height: size * 0.32 * scaleFactor,
              decoration: BoxDecoration(
                color: AppColors.joyStick,
                shape: BoxShape.circle,
              ),
            ),
            base: Container(
              width: size * 1.05 * scaleFactor,
              height: size * 1.05 * scaleFactor,
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
          ),
        ),
        
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final height = size.height;
    final width = size.width;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isSocketReady
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildTopBumpers(width),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                children: [
                                  buildJoystick('left', height * 0.32),
                                  const SizedBox(height: 25),
                                  Padding(
                                    padding: EdgeInsets.only(left: width * 0.15),
                                    child: _buildDPad(height * 0.3),
                                  ),
                                ],
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [_centerButtons()],
                              ),
                              Column(
                                children: [
                                  _buildFaceButtons(height * 0.34),
                                  const SizedBox(height: 28),
                                  Padding(
                                    padding: EdgeInsets.only(right: width * 0.15),
                                    child: buildJoystick('right', height * 0.32),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            : const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text("Connecting..."),
                  ],
                ),
              ),
      ),
    );
  }
}
