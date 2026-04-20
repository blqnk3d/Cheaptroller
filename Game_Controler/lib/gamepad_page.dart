import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import 'package:game_controler/Settings/gamepadProvider.dart';
import 'package:game_controler/Settings/settingsProvider.dart';
import 'package:provider/provider.dart';
import 'style.dart';

class GamepadPage extends StatefulWidget {
  static const routeName = '/gamepad';
  const GamepadPage({super.key});

  @override
  State<GamepadPage> createState() => _GamepadPageState();
}

class _GamepadPageState extends State<GamepadPage> {
  bool _didInit = false;

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInit) {
      final settings = context.read<SettingsProvider>();
      context.read<GamepadProvider>().updateServer(settings.ipAddress);
      _didInit = true;
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Widget buildJoystick(String side) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final joystickSize = constraints.maxHeight * 0.5;
        final List<String> buttonLabels = side == 'left'
            ? ['Left Click', 'Right Click', 'Middle Mouse']
            : ['R1', 'R2', 'R3'];
        
        final gamepad = context.read<GamepadProvider>();

        Widget joystickWidget = Joystick(
          mode: JoystickMode.all,
          stick: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.joyStick,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                    color: Colors.black26, blurRadius: 4, offset: Offset(2, 2))
              ],
            ),
          ),
          base: Container(
            width: joystickSize,
            height: joystickSize,
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              shape: BoxShape.circle,
            ),
          ),
          listener: (details) {
            gamepad.sendMove(side, details.x, details.y);
          },
        );

        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  return Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTapDown: (_) => gamepad.sendButton(side, i, true),
                          onTapUp: (_) => gamepad.sendButton(side, i, false),
                          onTapCancel: () => gamepad.sendButton(side, i, false),
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              border: Border.all(
                                  color: AppColors.textPrimary, width: 2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.circle,
                                color: AppColors.textSecondary, size: 32),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(buttonLabels[i], style: AppTextStyles.body),
                      ],
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              SizedBox(
                  width: joystickSize,
                  height: joystickSize,
                  child: joystickWidget),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isReady = context.watch<GamepadProvider>().isSocketReady;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: isReady
            ? Row(
                children: [
                  Expanded(child: buildJoystick("left")),
                  const SizedBox(width: 150),
                  Expanded(child: buildJoystick("right")),
                ],
              )
            : const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text("Connecting..."),
                  ],
                ),
              ),
      ),
    );
  }
}
