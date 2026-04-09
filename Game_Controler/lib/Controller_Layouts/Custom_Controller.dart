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
import 'package:game_controler/Models/custom_layout_model.dart';
import '../style.dart';
import 'package:vibration/vibration.dart';

class CustomController extends StatefulWidget {
  static const routeName = '/custom_controller';
  const CustomController({super.key});

  @override
  State<CustomController> createState() => _CustomControllerState();
}

class _CustomControllerState extends State<CustomController> {
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
    data['timestamp'] = DateTime.now().millisecondsSinceEpoch;
    final bytes = utf8.encode(jsonEncode(data));
    socket!.send(bytes, serverAddress!, port);
  }

  void sendMove(String side, double x, double y) {
    sendUDP({"type": "move", "side": side, "x": x, "y": y});
  }

  void sendButton(String side, int index, bool pressed) {
    if (pressed) {
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      if (settings.hapticFeedbackEnabled) {
        Vibration.vibrate(duration: 15, amplitude: 128);
      }
    }

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

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final layout = settings.customLayout;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isSocketReady
            ? LayoutBuilder(builder: (context, constraints) {
                return Stack(
                  children: layout.elements.map((element) {
                    return Positioned(
                      left: element.x * constraints.maxWidth,
                      top: element.y * constraints.maxHeight,
                      child: _buildElement(element),
                    );
                  }).toList(),
                );
              })
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildElement(ControlElement element) {
    switch (element.type) {
      case ControlType.joystick:
        return JoystickWidget(
          side: element.side,
          size: element.size,
          onMove: (x, y) => sendMove(element.side, x, y),
        );
      case ControlType.dpad:
        return DPad(
          size: element.size,
          pressedButtons: _pressedButtons,
          onPressed: (index, pressed) => sendButton(element.side, index, pressed),
        );
      case ControlType.faceButtons:
        return FaceButtons(
          size: element.size,
          pressedButtons: _pressedButtons,
          onPressed: (index, pressed) => sendButton(element.side, index, pressed),
        );
      case ControlType.middleButtons:
        return MiddleButtons(
          pressedButtons: _pressedButtons,
          onPressed: (index, pressed) => sendButton(index < 9 ? 'left' : 'right', index, pressed),
        );
      default:
        return const SizedBox();
    }
  }
}
