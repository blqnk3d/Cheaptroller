import 'package:flutter/material.dart';
import 'package:game_controler/Controller_Layouts/Playstation_Controller.dart';
import 'package:game_controler/Controller_Layouts/XBox_Controller.dart';
import 'package:game_controler/Controller_Layouts/Custom_Controller.dart';
import 'package:game_controler/Controller_Layouts/Custom_Controller_Editor.dart';
import 'package:game_controler/Settings/settingsProvider.dart';
import 'package:provider/provider.dart';

import 'startpage.dart';
import 'style.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => SettingsProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
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
