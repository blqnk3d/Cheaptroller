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
import 'package:provider/provider.dart';
import '../style.dart';
import '../utils/udp_service.dart'; // Import UdpService

class Xbox_Controller extends StatefulWidget {
  static const routeName = '/xbox_controller';
  const Xbox_Controller({super.key});

  @override
  State<Xbox_Controller> createState() => _Xbox_ControllerState();
}

class _Xbox_ControllerState extends State<Xbox_Controller> {
  static const double scaleFactor = 1.128;

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
    
    return GestureDetector(
      onDoubleTap: () {
        // Assuming View button is index 8, Menu button is index 9
        if (side == 'left') {
          udpService.sendButton('view', 8, true); // View button
          Future.delayed(const Duration(milliseconds: 100), () => udpService.sendButton('view', 8, false));
        } else { // right joystick
          udpService.sendButton('menu', 9, true); // Menu button
          Future.delayed(const Duration(milliseconds: 100), () => udpService.sendButton('menu', 9, false));
        }
      },
      child: JoystickWidget(
        side: side,
        size: size,
        onMove: (x, y) => udpService.sendMove(side, x, y),
        scaleFactor: scaleFactor,
      ),
    );
  }

  Widget _topButton(String label, int index, String side, UdpService udpService) {
    // UI feedback for pressed state needs to be handled.
    final bool isPressed = false; 
    
    return GestureDetector(
      onTapDown: (_) => udpService.sendButton(side, index, true),
      onTapUp: (_) => udpService.sendButton(side, index, false),
      onTapCancel: () => udpService.sendButton(side, index, false),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 6 * scaleFactor, horizontal: 14 * scaleFactor),
        decoration: BoxDecoration(
          color: isPressed ? Colors.greenAccent.withValues(alpha: 0.5) : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(10 * scaleFactor),
          border: Border.all(color: AppColors.textPrimary, width: 1.5 * scaleFactor),
        ),
        child: Text(label,
            style: AppTextStyles.body.copyWith(
              fontSize: 14 * scaleFactor,
            )),
      ),
    );
  }

  Widget _buildTopBumpers(double width, SettingsProvider settings, UdpService udpService) {
    const int leftBumperIndex = 4; // LB
    const int rightBumperIndex = 5; // RB

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: width * 0, vertical: 6),
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

  Widget _centerButtons(UdpService udpService) {
    // Xbox: View (index 8), Menu (index 9)
    return MiddleButtons(
      pressedButtons: const {}, // UI state management needed
      onPressed: (index, pressed) {
        if (index == 8) { // View button
          udpService.sendButton('view', index, pressed);
        } else if (index == 9) { // Menu button
          udpService.sendButton('menu', index, pressed);
        }
      },
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
        child: udpService.isSocketReady
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildTopBumpers(width, settings, udpService),
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
                                      pressedButtons: const {}, // UI state management needed
                                      onPressed: (index, pressed) => udpService.sendButton('left', index, pressed),
                                      scaleFactor: scaleFactor,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [_centerButtons(udpService)],
                              ),
                              Column(
                                children: [
                                  FaceButtons(
                                    size: height * 0.32,
                                    scaleFactor: scaleFactor,
                                    pressedButtons: const {}, // UI state management needed
                                    onPressed: (index, pressed) => udpService.sendButton('right', index, pressed),
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
