import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:game_controler/Elements/buttons.dart';
import 'package:game_controler/Elements/dpad.dart';
import 'package:game_controler/Elements/joystick.dart';
import 'package:game_controler/Elements/middlebutton.dart';
import 'package:provider/provider.dart';
import 'package:game_controler/Settings/settingsProvider.dart';
import 'package:game_controler/Models/custom_layout_model.dart';
import 'package:game_controler/Controllers/controllerProvider.dart';
import 'package:game_controler/Elements/status_indicator.dart';
import '../style.dart';
import 'package:vibration/vibration.dart';

class CustomController extends StatefulWidget {
  static const routeName = '/custom_controller';
  const CustomController({super.key});

  @override
  State<CustomController> createState() => _CustomControllerState();
}

class _CustomControllerState extends State<CustomController> {
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

  @override
  void dispose() {
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

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<ControllerProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final layout = settings.customLayout;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: controller.isConnected
            ? LayoutBuilder(builder: (context, constraints) {
                return Stack(
                  children: [
                    if (settings.showConnectionStatus)
                      Positioned(
                        top: 10,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: ConnectionStatusIndicator(isConnected: controller.isConnected),
                        ),
                      ),
                    ...layout.elements.map((element) {
                      return Positioned(
                        left: element.x * constraints.maxWidth,
                        top: element.y * constraints.maxHeight,
                        child: _buildElement(controller, element),
                      );
                    }).toList(),
                  ],
                );
              })
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildElement(ControllerProvider controller, ControlElement element) {
    switch (element.type) {
      case ControlType.joystick:
        return JoystickWidget(
          side: element.side,
          size: element.size,
          onMove: (x, y) => controller.sendMove(element.side, x, y),
        );
      case ControlType.dpad:
        return DPad(
          size: element.size,
          pressedButtons: _pressedButtons,
          onPressed: (index, pressed) => sendButton(controller, element.side, index, pressed),
        );
      case ControlType.faceButtons:
        return FaceButtons(
          size: element.size,
          pressedButtons: _pressedButtons,
          onPressed: (index, pressed) => sendButton(controller, element.side, index, pressed),
        );
      case ControlType.middleButtons:
        return MiddleButtons(
          pressedButtons: _pressedButtons,
          onPressed: (index, pressed) => sendButton(controller, index < 9 ? 'left' : 'right', index, pressed),
        );
      case ControlType.bumper:
        return _buildBumper(controller, element);
    }
  }

  Widget _buildBumper(ControllerProvider controller, ControlElement element) {
    final index = element.side == 'left' ? 4 : 5;
    final key = "${element.side}_$index";
    final isPressed = _pressedButtons.contains(key);

    return GestureDetector(
      onTapDown: (_) => sendButton(controller, element.side, index, true),
      onTapUp: (_) => sendButton(controller, element.side, index, false),
      onTapCancel: () => sendButton(controller, element.side, index, false),
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