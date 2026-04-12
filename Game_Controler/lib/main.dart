import 'package:flutter/material.dart';
import 'package:game_controler/Controller_Layouts/Playstation_Controller.dart';
import 'package:game_controler/Controller_Layouts/Xbox_Controller.dart'; // Corrected import
import 'package:game_controler/Controller_Layouts/Custom_Controller.dart';
import 'package:game_controler/Controller_Layouts/Custom_Controller_Editor.dart';
import 'package:game_controler/Settings/settingsProvider.dart';
import 'package:provider/provider.dart';

import 'startpage.dart';
import 'style.dart';
import 'utils/udp_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProxyProvider<SettingsProvider, UdpService>(
          create: (_) => UdpService(),
          update: (context, settingsProvider, udpService) {
            udpService?.updateSettings(
              settingsProvider.gyroSteeringEnabled,
              settingsProvider.hapticFeedbackEnabled,
              settingsProvider.showConnectionStatus,
            );
            return udpService!;
          },
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Access UdpService and SettingsProvider here to initialize connection and settings
    final udpService = Provider.of<UdpService>(context, listen: false);
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);

    // Connect to the server IP from settings when the app starts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (settingsProvider.ipAddress.isNotEmpty) {
        udpService.connect(settingsProvider.ipAddress);
      }
      udpService.updateSettings(
        settingsProvider.gyroSteeringEnabled,
        settingsProvider.hapticFeedbackEnabled,
        settingsProvider.showConnectionStatus,
      );
    });

    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness:
                settings.isDarkMode ? Brightness.dark : Brightness.light,
            scaffoldBackgroundColor: AppColors.background,
            appBarTheme: AppBarTheme(
              backgroundColor: AppColors.cardBackground,
              foregroundColor: AppColors.textPrimary,
            ),
            iconTheme: const IconThemeData(color: AppColors.icon),
            textTheme: TextTheme(
              bodyMedium: AppTextStyles.body,
              bodySmall: AppTextStyles.label,
              titleMedium: AppTextStyles.heading,
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: AppColors.cardBackground,
              labelStyle: AppTextStyles.label,
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.textSecondary),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.textPrimary),
              ),
            ),
          ),
          initialRoute: StartPage.routeName,
          routes: {
            StartPage.routeName: (_) => const StartPage(),
            Playstation_Controller.routeName:
                (_) => const Playstation_Controller(),
            Xbox_Controller.routeName: (_) => const Xbox_Controller(),
            CustomController.routeName: (_) => const CustomController(),
            CustomControllerEditor.routeName: (_) => const CustomControllerEditor(),
          },
        );
      },
    );
  }
}
