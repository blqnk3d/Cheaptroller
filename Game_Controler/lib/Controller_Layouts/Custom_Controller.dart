import 'dart:async';
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
import 'package:game_controler/Elements/status_indicator.dart';
import '../style.dart';
import 'package:vibration/vibration.dart';
import 'package:msgpack_dart/msgpack_dart.dart' as msgpack;

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

  // UDP Queue for non-blocking sends
  final StreamController<List<int>> _udpQueue = StreamController<List<int>>();
  StreamSubscription? _queueSubscription;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initQueue();
  }

  void _initQueue() {
    _queueSubscription = _udpQueue.stream.listen((bytes) {
      if (_isSocketReady && socket != null && serverAddress != null) {
        socket!.send(bytes, serverAddress!, port);
      }
    });
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
      // ignore
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
    _queueSubscription?.cancel();
    _udpQueue.close();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  void sendUDP(Map<String, dynamic> data) {
    if (!_isSocketReady) return;
    
    // Use binary keys for reduced payload
    final Map<String, dynamic> optimizedData = {
      't': data['type'],
      'ts': DateTime.now().millisecondsSinceEpoch,
    };

    if (data.containsKey('side')) optimizedData['s'] = data['side'];
    if (data.containsKey('index')) optimizedData['i'] = data['index'];
    if (data.containsKey('x')) optimizedData['x'] = data['x'];
    if (data.containsKey('y')) optimizedData['y'] = data['y'];

    final bytes = msgpack.serialize(optimizedData);
    _udpQueue.add(bytes);
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
                  children: [
                    if (settings.showConnectionStatus)
                      Positioned(
                        top: 10,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: ConnectionStatusIndicator(isConnected: _isSocketReady),
                        ),
                      ),
                    ...layout.elements.map((element) {
                      return Positioned(
                        left: element.x * constraints.maxWidth,
                        top: element.y * constraints.maxHeight,
                        child: _buildElement(element),
                      );
                    }).toList(),
                  ],
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
      case ControlType.bumper:
        return _buildBumper(element);
    }
  }

  Widget _buildBumper(ControlElement element) {
    final index = element.side == 'left' ? 4 : 5;
    final key = "${element.side}_$index";
    final isPressed = _pressedButtons.contains(key);

    return GestureDetector(
      onTapDown: (_) => sendButton(element.side, index, true),
      onTapUp: (_) => sendButton(element.side, index, false),
      onTapCancel: () => sendButton(element.side, index, false),
      child: Container(
        width: element.size,
        height: element.size * 0.4,
        decoration: BoxDecoration(
          color: isPressed ? Colors.greenAccent.withValues(alpha: 0.5) : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.textPrimary, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text(
          element.side == 'left' ? 'LB' : 'RB',
          style: AppTextStyles.body.copyWith(fontSize: 14),
        ),
      ),
    );
  }
}
