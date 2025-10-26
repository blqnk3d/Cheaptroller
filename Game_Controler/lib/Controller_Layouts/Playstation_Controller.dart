// lib/Playstation_controler.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:game_controler/Elements/buttons.dart';
import 'package:game_controler/Elements/dpad.dart';
import 'package:game_controler/Elements/joystick.dart';
import 'package:game_controler/Elements/middlebutton.dart';
import 'package:provider/provider.dart';
import 'package:game_controler/Settings/settingsProvider.dart';
import '../style.dart';

class Playstation_Controller extends StatefulWidget {
  static const routeName = '/playstation_controller';
  const Playstation_Controller({super.key});

  @override
  State<Playstation_Controller> createState() => _Playstation_ControllerState();
}

class _Playstation_ControllerState extends State<Playstation_Controller> {
  static const double scaleFactor = 1.10;
  RawDatagramSocket? socket;
  InternetAddress? serverAddress;
  bool _isSocketReady = false;

  static const int port = 8080;

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

  Widget buildJoystick(String side, double size) {
    final int bottomBumperIndex = side == 'left' ? 6 : 7;

    return GestureDetector(
      onDoubleTap: () {
        Future.delayed(const Duration(milliseconds: 150), () {
          sendButton(side, bottomBumperIndex, true);
          Future.delayed(const Duration(milliseconds: 100), () {
            sendButton(side, bottomBumperIndex, false);
          });
        });
      },
      child: JoystickWidget(
        side: side,
        size: size,
        scaleFactor: scaleFactor,
        onMove: (x, y) => sendMove(side, x, y),
      ),
    );
  }

  Widget _buildTopBumpers(double width) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [_topButton('LB', 4, 'left'), _topButton('RB', 5, 'right')],
      ),
    );
  }

  Widget _topButton(String label, int index, String side) {
    final key = "${side}_$index";
    final isPressed = _pressedButtons.contains(key);
    final bool isCenterButton = label == "View" || label == "Menu";
    final double scale = isCenterButton ? 1.0 : scaleFactor;

    return GestureDetector(
      onTapDown: (_) => sendButton(side, index, true),
      onTapUp: (_) => sendButton(side, index, false),
      onTapCancel: () => sendButton(side, index, false),
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: 5 * scale,
          horizontal: 12 * scale,
        ),
        decoration: BoxDecoration(
          color:
              isPressed
                  ? Colors.greenAccent.withOpacity(0.5)
                  : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(10 * scale),
          border: Border.all(color: AppColors.textPrimary, width: 1.5 * scale),
        ),
        child: Text(
          label,
          style: AppTextStyles.body.copyWith(fontSize: 13 * scale),
        ),
      ),
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
        child:
            _isSocketReady
                ? Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildTopBumpers(width),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // DPad + Face Buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(left: width * 0.04),
                                  child: DPad(
                                    size: height * 0.34,
                                    scaleFactor: scaleFactor,
                                    pressedButtons: _pressedButtons,
                                    onPressed:
                                        (index, pressed) =>
                                            sendButton('left', index, pressed),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.only(right: width * 0.04),
                                  child: FaceButtons(
                                    size: height * 0.36,
                                    scaleFactor: scaleFactor,
                                    pressedButtons: _pressedButtons,
                                    onPressed:
                                        (index, pressed) =>
                                            sendButton('right', index, pressed),
                                  ),
                                ),
                              ],
                            ),

                            // Joysticks + Middle Buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(left: width * 0.10),
                                  child: buildJoystick('left', height * 0.38),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    MiddleButtons(
                                      scaleFactor: scaleFactor,
                                      pressedButtons: _pressedButtons,
                                      onPressed:
                                          (index, pressed) => sendButton(
                                            index < 9 ? 'left' : 'right',
                                            index,
                                            pressed,
                                          ),
                                    ),
                                  ],
                                ),
                                Padding(
                                  padding: EdgeInsets.only(right: width * 0.10),
                                  child: buildJoystick('right', height * 0.38),
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
