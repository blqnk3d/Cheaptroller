// lib/Playstation_controler.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:game_controler/Elements/buttons.dart';
import 'package:game_controler/Elements/dpad.dart';
import 'package:game_controler/Elements/joystick.dart';
import 'package:game_controler/Elements/middlebutton.dart';
import 'package:game_controler/Elements/status_indicator.dart';
import 'package:provider/provider.dart';
import 'package:game_controler/Settings/settingsProvider.dart';
import 'package:game_controler/Controllers/controllerProvider.dart';
import '../style.dart';

import 'package:sensors_plus/sensors_plus.dart';
import 'package:vibration/vibration.dart';

class Playstation_Controller extends StatefulWidget {
  static const routeName = '/playstation_controller';
  const Playstation_Controller({super.key});

  @override
  State<Playstation_Controller> createState() => _Playstation_ControllerState();
}

class _Playstation_ControllerState extends State<Playstation_Controller> {
  static const double scaleFactor = 1.10;

  final Set<String> _pressedButtons = {};

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
    if (pressed) {
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      if (settings.hapticFeedbackEnabled) {
        Vibration.vibrate(duration: 15, amplitude: 128);
      }
    }

    controller.sendButton(side, index, pressed);

    final key = "${side}_$index";
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
        scaleFactor: scaleFactor,
        onMove: (x, y) => controller.sendMove(side, x, y),
      ),
    );
  }

  Widget _buildTopBumpers(ControllerProvider controller, double width) {
    final settings = Provider.of<SettingsProvider>(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTapDown: (_) => sendButton(controller, 'left', 4, true),
            onTapUp: (_) => sendButton(controller, 'left', 4, false),
            onTapCancel: () => sendButton(controller, 'left', 4, false),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 5 * scaleFactor, horizontal: 12 * scaleFactor),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(10 * scaleFactor),
                border: Border.all(color: AppColors.textPrimary, width: 1.5 * scaleFactor),
              ),
              child: Text('LB', style: AppTextStyles.body.copyWith(fontSize: 13 * scaleFactor)),
            ),
          ),
          if (settings.showConnectionStatus) ConnectionStatusIndicator(isConnected: controller.isConnected),
          GestureDetector(
            onTapDown: (_) => sendButton(controller, 'right', 5, true),
            onTapUp: (_) => sendButton(controller, 'right', 5, false),
            onTapCancel: () => sendButton(controller, 'right', 5, false),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 5 * scaleFactor, horizontal: 12 * scaleFactor),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(10 * scaleFactor),
                border: Border.all(color: AppColors.textPrimary, width: 1.5 * scaleFactor),
              ),
              child: Text('RB', style: AppTextStyles.body.copyWith(fontSize: 13 * scaleFactor)),
            ),
          ),
        ],
      ),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Padding(
                                padding: EdgeInsets.only(left: width * 0.04),
                                child: DPad(
                                  size: height * 0.34,
                                  scaleFactor: scaleFactor,
                                  pressedButtons: _pressedButtons,
                                  onPressed: (index, pressed) => sendButton(controller, 'left', index, pressed),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.only(right: width * 0.04),
                                child: FaceButtons(
                                  size: height * 0.36,
                                  scaleFactor: scaleFactor,
                                  pressedButtons: _pressedButtons,
                                  onPressed: (index, pressed) => sendButton(controller, 'right', index, pressed),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Padding(
                                padding: EdgeInsets.only(left: width * 0.10),
                                child: buildJoystick(controller, 'left', height * 0.38),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  MiddleButtons(
                                    scaleFactor: scaleFactor,
                                    pressedButtons: _pressedButtons,
                                    onPressed: (index, pressed) => sendButton(
                                      controller,
                                      index < 9 ? 'left' : 'right',
                                      index,
                                      pressed,
                                    ),
                                  ),
                                ],
                              ),
                              Padding(
                                padding: EdgeInsets.only(right: width * 0.10),
                                child: buildJoystick(controller, 'right', height * 0.38),
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