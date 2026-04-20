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
import 'package:game_controler/Settings/gamepadProvider.dart';
import '../style.dart';
import 'package:sensors_plus/sensors_plus.dart';

class Playstation_Controller extends StatefulWidget {
  static const routeName = '/playstation_controller';
  const Playstation_Controller({super.key});

  @override
  State<Playstation_Controller> createState() => _Playstation_ControllerState();
}

class _Playstation_ControllerState extends State<Playstation_Controller> {
  static const double scaleFactor = 1.10;
  bool _didInit = false;

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

  void _initGyro() {
    final settings = context.read<SettingsProvider>();
    final gamepad = context.read<GamepadProvider>();
    
    if (settings.gyroSteeringEnabled) {
      _accelerometerSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
        double steering = (event.y / 7.0).clamp(-1.0, 1.0);
        if ((steering - _lastGyroX).abs() > 0.02) {
          _lastGyroX = steering;
          gamepad.sendMove('left', steering, 0);
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInit) {
      final settings = context.read<SettingsProvider>();
      context.read<GamepadProvider>().updateServer(settings.ipAddress);
      _initGyro();
      _didInit = true;
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

  void _handleButton(String side, int index, bool pressed) {
    final settings = context.read<SettingsProvider>();
    final gamepad = context.read<GamepadProvider>();
    
    gamepad.sendButton(side, index, pressed, haptic: settings.hapticFeedbackEnabled);

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
    final gamepad = context.read<GamepadProvider>();

    return GestureDetector(
      onDoubleTap: () {
        Future.delayed(const Duration(milliseconds: 150), () {
          _handleButton(side, bottomBumperIndex, true);
          Future.delayed(const Duration(milliseconds: 100), () {
            _handleButton(side, bottomBumperIndex, false);
          });
        });
      },
      child: JoystickWidget(
        side: side,
        size: size,
        scaleFactor: scaleFactor,
        onMove: (x, y) => gamepad.sendMove(side, x, y),
      ),
    );
  }

  Widget _buildTopBumpers(double width) {
    final settings = context.watch<SettingsProvider>();
    final isReady = context.watch<GamepadProvider>().isSocketReady;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _topButton('LB', 4, 'left'),
          if (settings.showConnectionStatus) ConnectionStatusIndicator(isConnected: isReady),
          _topButton('RB', 5, 'right'),
        ],
      ),
    );
  }

  Widget _topButton(String label, int index, String side) {
    final key = "${side}_$index";
    final isPressed = _pressedButtons.contains(key);
    final bool isCenterButton = label == "View" || label == "Menu";
    final double scale = isCenterButton ? 1.0 : scaleFactor;

    return GestureDetector(
      onTapDown: (_) => _handleButton(side, index, true),
      onTapUp: (_) => _handleButton(side, index, false),
      onTapCancel: () => _handleButton(side, index, false),
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: 5 * scale,
          horizontal: 12 * scale,
        ),
        decoration: BoxDecoration(
          color: isPressed ? Colors.greenAccent.withValues(alpha: 0.5) : AppColors.cardBackground,
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
    final isReady = context.watch<GamepadProvider>().isSocketReady;
    final size = MediaQuery.of(context).size;
    final height = size.height;
    final width = size.width;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: isReady
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Padding(
                                padding: EdgeInsets.only(left: width * 0.04),
                                child: DPad(
                                  size: height * 0.34,
                                  scaleFactor: scaleFactor,
                                  pressedButtons: _pressedButtons,
                                  onPressed: (index, pressed) => _handleButton('left', index, pressed),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.only(right: width * 0.04),
                                child: FaceButtons(
                                  size: height * 0.36,
                                  scaleFactor: scaleFactor,
                                  pressedButtons: _pressedButtons,
                                  onPressed: (index, pressed) => _handleButton('right', index, pressed),
                                ),
                              ),
                            ],
                          ),
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
                                    onPressed: (index, pressed) => _handleButton(
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
