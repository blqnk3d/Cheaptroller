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
import '../style.dart';
import '../utils/udp_service.dart'; // Import UdpService

class Playstation_Controller extends StatefulWidget {
  static const routeName = '/playstation_controller';
  const Playstation_Controller({super.key});

  @override
  State<Playstation_Controller> createState() => _Playstation_ControllerState();
}

class _Playstation_ControllerState extends State<Playstation_Controller> {
  static const double scaleFactor = 1.10;

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

  Widget buildJoystick(String side, double size) {
    final udpService = Provider.of<UdpService>(context, listen: false);
    final settings = Provider.of<SettingsProvider>(context, listen: false);

    return GestureDetector(
      onDoubleTap: () {
        // Example: Map double tap to a specific button, like a bottom bumper
        final int bottomBumperIndex = side == 'left' ? 6 : 7;
        Future.delayed(const Duration(milliseconds: 150), () {
          udpService.sendButton(side, bottomBumperIndex, true);
          Future.delayed(const Duration(milliseconds: 100), () {
            udpService.sendButton(side, bottomBumperIndex, false);
          });
        });
      },
      child: JoystickWidget(
        side: side,
        size: size,
        scaleFactor: scaleFactor,
        onMove: (x, y) => udpService.sendMove(side, x, y),
      ),
    );
  }

  Widget _buildTopBumpers(double width, SettingsProvider settings, UdpService udpService) {
    const int leftBumperIndex = 4; // LB
    const int rightBumperIndex = 5; // RB

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _topButton('LB', leftBumperIndex, 'left', udpService),
          if (settings.showConnectionStatus) ConnectionStatusIndicator(isConnected: udpService.isSocketReady),
          _topButton('RB', rightBumperIndex, 'right', udpService),
        ],
      ),
    );
  }

  Widget _topButton(String label, int index, String side, UdpService udpService) {
    // For UI feedback, we need to know the pressed state.
    // This could be managed by UdpService providing a stream of pressed buttons,
    // or by passing callbacks that update a local state managed by the widget.
    // For simplicity, we'll rely on UdpService's internal state if it exposes it,
    // or manage it locally if UdpService doesn't expose it directly.
    // For now, let's assume no direct UI feedback for pressed buttons on top.
    // Real implementation would query UdpService or manage state locally.
    final bool isPressed = false; 

    return GestureDetector(
      onTapDown: (_) => udpService.sendButton(side, index, true),
      onTapUp: (_) => udpService.sendButton(side, index, false),
      onTapCancel: () => udpService.sendButton(side, index, false),
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: 5 * scaleFactor,
          horizontal: 12 * scaleFactor,
        ),
        decoration: BoxDecoration(
          color: isPressed // Placeholder for actual pressed state feedback
              ? Colors.greenAccent.withValues(alpha: 0.5)
              : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(10 * scaleFactor),
          border: Border.all(color: AppColors.textPrimary, width: 1.5 * scaleFactor),
        ),
        child: Text(
          label,
          style: AppTextStyles.body.copyWith(fontSize: 13 * scaleFactor),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final height = size.height;
    final width = size.width;
    final settings = Provider.of<SettingsProvider>(context); // To access showConnectionStatus
    final udpService = Provider.of<UdpService>(context); // To access isSocketReady and gyro settings

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child:
            udpService.isSocketReady
                ? Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildTopBumpers(width, settings, udpService), // Pass udpService
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
                                    pressedButtons: const {}, // Local state removed, relying on UdpService feedback
                                    onPressed: (index, pressed) => udpService.sendButton('left', index, pressed),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.only(right: width * 0.04),
                                  child: FaceButtons(
                                    size: height * 0.36,
                                    scaleFactor: scaleFactor,
                                    pressedButtons: const {}, // Local state removed
                                    onPressed: (index, pressed) => udpService.sendButton('right', index, pressed),
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
                                      pressedButtons: const {}, // Local state removed
                                      onPressed: (index, pressed) => udpService.sendButton(
                                        index < 9 ? 'left' : 'right', // Simplified logic
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
