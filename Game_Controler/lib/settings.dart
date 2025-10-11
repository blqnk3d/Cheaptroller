import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:game_controler/settingsProvider.dart';
import 'dart:convert';
import 'dart:io';
import 'package:provider/provider.dart';
import 'style.dart'; // <-- import your style.dart

class SettingsPage extends StatefulWidget {
  static const routeName = '/settings';
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController _ipController;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    final settings = context.read<SettingsProvider>();
    _ipController = TextEditingController(text: settings.ipAddress);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _ipController.dispose();
    super.dispose();
  }

  void _sendIpToServer(BuildContext context) async {
    final settings = context.read<SettingsProvider>();

    try {
      final data = jsonEncode({
        'type': 'ip_update',
        'ip': settings.ipAddress,
      });

      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      final targetIp = InternetAddress(settings.ipAddress);
      socket.send(data.codeUnits, targetIp, 8080);
      socket.close();

      print('📤 IP gesendet: $data');

      if (context.mounted) Navigator.pop(context, settings.ipAddress);
    } catch (e) {
      print('⚠️ Fehler beim Senden der IP: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Settings',
          style: AppTextStyles.heading,
        ),
        backgroundColor: AppColors.cardBackground,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            style: AppButtonStyles.whiteIconButton,
            onPressed: () {
              context.read<SettingsProvider>().setIpAddress(_ipController.text);
              _sendIpToServer(context);
            },
            tooltip: 'IP speichern',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: _ipController,
          decoration: AppInputDecorations.textField('Server IP-Adresse'),
          style: AppTextStyles.body,
          keyboardType: TextInputType.number,
          onChanged: (val) => context.read<SettingsProvider>().setIpAddress(val),
        ),
      ),
    );
  }
}
