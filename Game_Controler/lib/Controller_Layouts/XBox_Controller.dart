// lib/Xbox_Controller.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:game_controler/Elements/buttons.dart';
import 'package:game_controler/Elements/dpad.dart';
import 'package:game_controler/Elements/joystick.dart';
import 'package:game_controler/Elements/middlebutton.dart';
import 'package:game_controler/Elements/status_indicator.dart';
import 'package:game_controler/Settings/settingsProvider.dart';
import 'package:game_controler/protocol.dart';
import 'package:provider/provider.dart';
import '../style.dart';

import 'package:sensors_plus/sensors_plus.dart';
import 'package:vibration/vibration.dart';

class Xbox_Controller extends StatefulWidget {
  static const routeName = '/xbox_controller';
  const Xbox_Controller({super.key});

  @override
  State<Xbox_Controller> createState() => _Xbox_ControllerState();
}

class _Xbox_ControllerState extends State<Xbox_Controller> {
  static const double scaleFactor = 1.128;

  RawDatagramSocket? socket;
  InternetAddress? serverAddress;
  bool _isSocketReady = false;
  bool _didInitSocket = false;

  static const int port = 8080;
  final Set<String> _pressedButtons = {};
  
  // Gesture debouncing - prevent rapid fire updates
  final Map<String, DateTime> _lastButtonTime = {};
  static const int _gestureDebounceMs = 16;  // 16ms = 60fps safe

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  double _lastGyroX = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initGyro();
  }

  void _initGyro() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (settings.gyroSteeringEnabled) {
      _accelerometerSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
        // In landscape, we use Y-axis for left/right steering (tilt)
        // Adjust sensitivity and range
        double steering = (event.y / 7.0).clamp(-1.0, 1.0);
        
        // Only send if it changed significantly to reduce UDP traffic
        if ((steering - _lastGyroX).abs() > 0.02) {
          _lastGyroX = steering;
          sendMove('left', steering, 0); // Steering usually maps to Left Stick X
        }
      });
    }
  }

  Future<void> _initSocket() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final newIp = settings.ipAddress;

    // Only reinitialize if IP changed
    if (newIp == serverAddress?.address && socket != null && _isSocketReady) {
      return;
    }

    setState(() => _isSocketReady = false);
    socket?.close();

    try {
      serverAddress = InternetAddress(newIp);
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      setState(() => _isSocketReady = true);
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
    _accelerometerSubscription?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  void sendUDP(Uint8List data) {
    if (!_isSocketReady || socket == null || serverAddress == null) return;
    socket!.send(data, serverAddress!, port);
  }

  void sendMove(String side, double x, double y) {
    sendUDP(encodeMove(side, x, y));
  }

  void sendButton(String side, int index, bool pressed) {
    final key = "${side}_$index";
    
    final now = DateTime.now();
    final lastTime = _lastButtonTime[key] ?? DateTime.now().subtract(const Duration(seconds: 1));
    if (now.difference(lastTime).inMilliseconds < _gestureDebounceMs) {
      return;
    }
    _lastButtonTime[key] = now;
    
    if (pressed) {
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      if (settings.hapticFeedbackEnabled) {
        Vibration.vibrate(duration: 15, amplitude: 128);
      }
    }

    sendUDP(encodeButton(side, index, pressed));

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
        onMove: (x, y) => sendMove(side, x, y),
        scaleFactor: scaleFactor ,
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
        padding: EdgeInsets.symmetric(vertical: 6 * scale, horizontal: 14 * scale),
        decoration: BoxDecoration(
          color: isPressed ? Colors.greenAccent.withValues(alpha: 0.5) : AppColors.cardBackground,
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

  Widget _buildTopBumpers(double width) {
    final settings = Provider.of<SettingsProvider>(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: width * 0, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _topButton('LB', 4, 'left'),
          if (settings.showConnectionStatus) ConnectionStatusIndicator(isConnected: _isSocketReady),
          _topButton('RB', 5, 'right'),
        ],
      ),
    );
  }

  Widget _centerButtons() {
    return MiddleButtons(
      pressedButtons: _pressedButtons,
      onPressed: (index, pressed) => sendButton(index < 9 ? 'left' : 'right', index, pressed),
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
                                  buildJoystick('left', height * 0.34),
                                  const SizedBox(height: 25),
                                  Padding(
                                    padding: EdgeInsets.only(left: width * 0.15),
                                    child: DPad(
                                      size: height * 0.32,
                                      pressedButtons: _pressedButtons,
                                      onPressed: (index, pressed) => sendButton('left', index, pressed),
                                      scaleFactor: scaleFactor,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [_centerButtons()],
                              ),
                              Column(
                                children: [
                                  FaceButtons(
                                    size: height * 0.32,
                                    scaleFactor: scaleFactor,
                                    pressedButtons: _pressedButtons,
                                    onPressed: (index, pressed) => sendButton('right', index, pressed),
                                  ),
                                  const SizedBox(height: 28),
                                  Padding(
                                    padding: EdgeInsets.only(right: width * 0.15),
                                    child: buildJoystick('right', height * 0.34),
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
