// lib/Xbox_Controller.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:game_controler/Elements/buttons.dart';
import 'package:game_controler/Elements/dpad.dart';
import 'package:game_controler/Elements/joystick.dart';
import 'package:game_controler/Elements/middlebutton.dart';
import 'package:game_controler/Elements/status_indicator.dart';
import 'package:game_controler/Settings/settingsProvider.dart';
import 'package:game_controler/Controllers/controllerProvider.dart';
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

  final Set<String> _pressedButtons = {};
  final Map<String, DateTime> _lastButtonTime = {};
  static const int _gestureDebounceMs = 16;

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
  }

  void _initGyro(ControllerProvider controller) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (settings.gyroSteeringEnabled) {
      _accelerometerSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
        double steering = (event.y / 7.0).clamp(-1.0, 1.0);
        
        if ((steering - _lastGyroX).abs() > 0.02) {
          _lastGyroX = steering;
          controller.sendMove('left', steering, 0);
        }
      });
    }
  }

  @override
  void dispose() {
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

  void sendButton(ControllerProvider controller, String side, int index, bool pressed) {
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

    controller.sendButton(side, index, pressed);

    setState(() {
      if (pressed) {
        _pressedButtons.add(key);
      } else {
        _pressedButtons.remove(key);
      }
    });
  }

  Widget buildJoystick(ControllerProvider controller, String side, double size) {
    final int bottomBumperIndex = side == 'left' ? 6 : 7;
    return GestureDetector(
      onDoubleTap: () {
        Future.delayed(const Duration(milliseconds: 150), () {
          sendButton(controller, side, bottomBumperIndex, true);
          Future.delayed(const Duration(milliseconds: 100), () {
            sendButton(controller, side, bottomBumperIndex, false);
          });
        });
      },
      child: JoystickWidget(
        side: side,
        size: size,
        onMove: (x, y) => controller.sendMove(side, x, y),
        scaleFactor: scaleFactor,
      ),
    );
  }

  Widget _topButton(ControllerProvider controller, String label, int index, String side) {
    final key = "${side}_$index";
    final isPressed = _pressedButtons.contains(key);
    final bool isCenterButton = label == "View" || label == "Menu";
    final double scale = isCenterButton ? 1.0 : scaleFactor;

    return GestureDetector(
      onTapDown: (_) => sendButton(controller, side, index, true),
      onTapUp: (_) => sendButton(controller, side, index, false),
      onTapCancel: () => sendButton(controller, side, index, false),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 6 * scale, horizontal: 14 * scale),
        decoration: BoxDecoration(
          color: isPressed ? Colors.greenAccent.withValues(alpha: 0.5) : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(10 * scale),
          border: Border.all(color: AppColors.textPrimary, width: 1.5 * scale),
        ),
        child: Text(label, style: AppTextStyles.body.copyWith(fontSize: 14 * scale)),
      ),
    );
  }

  Widget _buildTopBumpers(ControllerProvider controller, double width) {
    final settings = Provider.of<SettingsProvider>(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: width * 0, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _topButton(controller, 'LB', 4, 'left'),
          if (settings.showConnectionStatus) ConnectionStatusIndicator(isConnected: controller.isConnected),
          _topButton(controller, 'RB', 5, 'right'),
        ],
      ),
    );
  }

  Widget _centerButtons(ControllerProvider controller) {
    return MiddleButtons(
      pressedButtons: _pressedButtons,
      onPressed: (index, pressed) => sendButton(controller, index < 9 ? 'left' : 'right', index, pressed),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<ControllerProvider>(context);
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final size = MediaQuery.of(context).size;
    final height = size.height;
    final width = size.width;

    if (_accelerometerSubscription == null && settings.gyroSteeringEnabled) {
      _initGyro(controller);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: controller.isConnected
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildTopBumpers(controller, width),
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
                                  buildJoystick(controller, 'left', height * 0.34),
                                  const SizedBox(height: 25),
                                  Padding(
                                    padding: EdgeInsets.only(left: width * 0.15),
                                    child: DPad(
                                      size: height * 0.32,
                                      pressedButtons: _pressedButtons,
                                      onPressed: (index, pressed) => sendButton(controller, 'left', index, pressed),
                                      scaleFactor: scaleFactor,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [_centerButtons(controller)],
                              ),
                              Column(
                                children: [
                                  FaceButtons(
                                    size: height * 0.32,
                                    scaleFactor: scaleFactor,
                                    pressedButtons: _pressedButtons,
                                    onPressed: (index, pressed) => sendButton(controller, 'right', index, pressed),
                                  ),
                                  const SizedBox(height: 28),
                                  Padding(
                                    padding: EdgeInsets.only(right: width * 0.15),
                                    child: buildJoystick(controller, 'right', height * 0.34),
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