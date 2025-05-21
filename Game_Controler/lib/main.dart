import 'package:flutter/material.dart';
import 'package:game_controler/settings.dart';
import 'package:game_controler/settingsProvider.dart';
import 'package:provider/provider.dart';

import 'startpage.dart';
import 'gamepad_page.dart';

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
          theme: settings.isDarkMode ? ThemeData.dark() : ThemeData.light(),
          initialRoute: StartPage.routeName,
          routes: {
            StartPage.routeName: (_) => const StartPage(),
            SettingsPage.routeName: (_) =>  SettingsPage(),
            GamepadPage.routeName: (_) => const GamepadPage(),
          },
        );
      },
    );
  }
}
