import 'dart:async';
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
import '../utils/udp_service.dart'; // Import UdpService

class CustomController extends StatefulWidget {
  static const routeName = '/custom_controller';
  const CustomController({super.key});

  @override
  State<CustomController> createState() => _CustomControllerState();
}

class _CustomControllerState extends State<CustomController> {
  @override
  void initState() {
    super.initState();
    // SystemChrome settings are now managed by UdpService on connection
  }

  @override
  void dispose() {
    // UdpService handles its own cleanup
    super.dispose();
  }

  void sendMove(String side, double x, double y, UdpService udpService) {
    udpService.sendMove(side, x, y);
  }

  void sendButton(String side, int index, bool pressed, UdpService udpService) {
    udpService.sendButton(side, index, pressed);
  }

  Widget _buildElement(ControlElement element, UdpService udpService, SettingsProvider settings) {
    switch (element.type) {
      case ControlType.joystick:
        return JoystickWidget(
          side: element.side,
          size: element.size,
          scaleFactor: element.scaleFactor,
          onMove: (x, y) => sendMove(element.side, x, y, udpService),
        );
      case ControlType.dpad:
        return DPad(
          size: element.size,
          scaleFactor: element.scaleFactor,
          pressedButtons: const {}, // UI state management is complex for custom layouts, needs more thought.
          onPressed: (index, pressed) => sendButton(element.side, index, pressed, udpService),
        );
      case ControlType.faceButtons:
        return FaceButtons(
          size: element.size,
          scaleFactor: element.scaleFactor,
          pressedButtons: const {}, // UI state management is complex
          onPressed: (index, pressed) => sendButton(element.side, index, pressed, udpService),
        );
      case ControlType.middleButtons:
        return MiddleButtons(
          scaleFactor: element.scaleFactor,
          pressedButtons: const {}, // UI state management is complex
          onPressed: (index, pressed) => sendButton(index < 9 ? 'left' : 'right', index, pressed, udpService), // Simplified logic
        );
      case ControlType.bumper:
        return _buildBumper(element, udpService, settings);
    }
  }

  Widget _buildBumper(ControlElement element, UdpService udpService, SettingsProvider settings) {
    // Assuming bumper elements have a fixed index for simplicity, or need mapping
    final int bumperIndex = element.side == 'left' ? 4 : 5; // Example indices for LB/RB
    final key = "${element.side}_$bumperIndex"; // This key might not be directly useful if we rely on UdpService state
    final bool isPressed = false; // UI state management needs to be reactive

    return GestureDetector(
      onTapDown: (_) => sendButton(element.side, bumperIndex, true, udpService),
      onTapUp: (_) => sendButton(element.side, bumperIndex, false, udpService),
      onTapCancel: () => sendButton(element.side, bumperIndex, false, udpService),
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

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final udpService = Provider.of<UdpService>(context);
    final layout = settings.customLayout;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: udpService.isSocketReady
            ? LayoutBuilder(builder: (context, constraints) {
                return Stack(
                  children: [
                    if (settings.showConnectionStatus)
                      Positioned(
                        top: 10,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: ConnectionStatusIndicator(isConnected: udpService.isSocketReady),
                        ),
                      ),
                    ...layout.elements.map((element) {
                      return Positioned(
                        left: element.x * constraints.maxWidth,
                        top: element.y * constraints.maxHeight,
                        child: _buildElement(element, udpService, settings),
                      );
                    }).toList(),
                  ],
                );
              })
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
