import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import 'package:game_controler/settingsProvider.dart';
import 'package:provider/provider.dart';
import 'style.dart';

class Playstation_Controller extends StatefulWidget {
  static const routeName = '/playstation_controller';
  const Playstation_Controller({super.key});

  @override
  State<Playstation_Controller> createState() => _Playstation_ControllerState();
}

class _Playstation_ControllerState extends State<Playstation_Controller> {
  RawDatagramSocket? socket;
  InternetAddress? serverAddress;
  bool _isSocketReady = false;

  static const int port = 8080;
  static const double deadzone = 0.01;

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
      default:
        index = 5;
    }
    return GestureDetector(
      onTapDown: (_) => sendButton('left', index, true),
      onTapUp: (_) => sendButton('left', index, false),
      child: Container(
        width: btnSize,
        height: btnSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.textPrimary, width: 1.5),
        ),
        child: Text(dir[0].toUpperCase(), style: AppTextStyles.body),
      ),
    );
  }

  Widget _buildDPad(double size) {
    final btnSize = size * 0.32;
    return SizedBox(
      width: size,
      height: size,
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

  Widget _faceButton(String label, int index, double size) {
    return GestureDetector(
      onTapDown: (_) => sendButton('right', index, true),
      onTapUp: (_) => sendButton('right', index, false),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.textPrimary, width: 1.5),
        ),
        child: Text(
          label,
          style: AppTextStyles.body.copyWith(fontSize: size * 0.4),
        ),
      ),
    );
  }

  Widget _buildFaceButtons(double size) {
    final b = size * 0.32;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(top: 0, child: _faceButton('△', 3, b)),
          Positioned(right: 0, child: _faceButton('◯', 1, b)),
          Positioned(left: 0, child: _faceButton('▢', 2, b)),
          Positioned(bottom: 0, child: _faceButton('✖', 0, b)),
        ],
      ),
    );
  }

  Widget _topButton(String label, int index, String side) {
    return GestureDetector(
      onTapDown: (_) => sendButton(side, index, true),
      onTapUp: (_) => sendButton(side, index, false),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.textPrimary, width: 1.5),
        ),
        child: Text(label, style: AppTextStyles.body.copyWith(fontSize: 13)),
      ),
    );
  }

  Widget _buildTopBumpers(double width) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: width * 0.06, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [_topButton('L1', 4, 'left'), _topButton('R1', 5, 'right')],
      ),
    );
  }

  Widget _centerButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _topButton('Select', 8, 'left'),
        const SizedBox(width: 16),
        _topButton('Start', 9, 'right'),
      ],
    );
  }

  Widget buildJoystick(String side, double size) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Joystick(
          mode: JoystickMode.all,
          stick: Container(
            width: size * 0.28,
            height: size * 0.28,
            decoration: BoxDecoration(
              color: AppColors.joyStick,
              shape: BoxShape.circle,
            ),
          ),
          base: Container(
            width: size,
            height: size,
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
        const SizedBox(height: 6),
        Text(
          side == 'left' ? 'L3' : 'R3',
          style: AppTextStyles.body.copyWith(fontSize: 12),
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

                      /// MAIN CONTROLS
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // 🔼 Top section (DPad + FaceButtons)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(left: width * 0.04),
                                  child: _buildDPad(height * 0.34),
                                ),
                                Padding(
                                  padding: EdgeInsets.only(right: width * 0.04),
                                  child: _buildFaceButtons(height * 0.36),
                                ),
                              ],
                            ),

                            // 🔽 Bottom section (Joysticks + Select/Start)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(left: width * 0.13),
                                  child: buildJoystick('left', height * 0.38),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [_centerButtons()],
                                ),
                                Padding(
                                  padding: EdgeInsets.only(right: width * 0.13),
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
