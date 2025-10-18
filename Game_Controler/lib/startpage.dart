import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:game_controler/Playstation_Controller.dart.dart';
import 'package:game_controler/XBox_Controller.dart.dart';
import 'package:game_controler/settings.dart';
import 'package:game_controler/style.dart';
import 'package:provider/provider.dart';
import 'package:game_controler/settingsProvider.dart';

class StartPage extends StatefulWidget {
  static const routeName = '/';
  const StartPage({super.key});

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  void _playstation_controller(String ip) {
    Navigator.pushNamed(context, Playstation_Controller.routeName, arguments: ip);
  }

   void _xbox_controller(String ip) {
    Navigator.pushNamed(context, Xbox_Controller.routeName, arguments: ip);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final ip = settings.ipAddress;

    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Aktuelle IP:', style: TextStyle(color: Colors.white70)),
                Text(
                  ip.isEmpty ? '(Keine IP gesetzt)' : ip,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
                const SizedBox(height: 20),
                
                ElevatedButton(
                  onPressed: ip.isEmpty ? null : () => _playstation_controller(ip),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        AppColors.cardBackground, 
                    foregroundColor: AppColors.textPrimary, 
                    disabledBackgroundColor:
                        AppColors.buttonDisabled, 
                    disabledForegroundColor: Colors.grey[500],
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 24,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Start Playstation Controller', style: AppTextStyles.body),
                ),
                const SizedBox(height: 10),

                ElevatedButton(
                  onPressed: ip.isEmpty ? null : () => _xbox_controller(ip),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        AppColors.cardBackground, 
                    foregroundColor: AppColors.textPrimary, 
                    disabledBackgroundColor:
                        AppColors.buttonDisabled, 
                    disabledForegroundColor: Colors.grey[500],
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 24,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Start XBox Controller', style: AppTextStyles.body),
                ),

                const SizedBox(height: 10),
                TextButton(
                  onPressed:
                      () =>
                          Navigator.pushNamed(context, SettingsPage.routeName),
                  child: const Text(
                    'Settings',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
