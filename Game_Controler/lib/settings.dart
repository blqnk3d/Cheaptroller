import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:game_controler/settingsProvider.dart';
import 'dart:convert';
import 'dart:io';
import 'package:provider/provider.dart';

class SettingsPage extends StatefulWidget {
  static const routeName = '/settings';
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final Map<String, List<String>> fixedConfig = {
    'left': ['mouse_left', 'shift', 'space'],
    'right': ['mouse_right', 'enter', 'tab'],
  };

  late TextEditingController _ipController;
  late TextEditingController _maxSpeedController;
  late TextEditingController _deadzoneController;
  late TextEditingController _smoothFactorController;
  late TextEditingController _moveThrottleController;

  @override
  void initState() {
    super.initState();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    final settings = context.read<SettingsProvider>();
    _ipController = TextEditingController(text: settings.ipAddress);
    _maxSpeedController = TextEditingController(text: settings.maxSpeed);
    _deadzoneController = TextEditingController(text: settings.deadzone);
    _smoothFactorController = TextEditingController(text: settings.smoothFactor);
    _moveThrottleController = TextEditingController(text: settings.moveThrottle);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _ipController.dispose();
    _maxSpeedController.dispose();
    _deadzoneController.dispose();
    _smoothFactorController.dispose();
    _moveThrottleController.dispose();
    super.dispose();
  }

  Widget _buildButtonDisplay(BuildContext context, String side, int index) {
    final buttonName = fixedConfig[side]![index];
    final isDarkMode = context.watch<SettingsProvider>().isDarkMode;

    return ListTile(
      title: Text(
        '$side Button ${index + 1}',
        style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
      ),
      trailing: Text(
        buttonName,
        style: TextStyle(
          color: isDarkMode ? Colors.white70 : Colors.black54,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _buildNumericField(
      BuildContext context,
      String label,
      TextEditingController controller,
      Function(String) onChanged,
      ) {
    final isDarkMode = context.watch<SettingsProvider>().isDarkMode;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black54),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: isDarkMode ? Colors.white54 : Colors.black54),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: isDarkMode ? Colors.white : Colors.black),
          ),
        ),
        controller: controller,
        onChanged: onChanged,
      ),
    );
  }

  void _sendSettingsToServer(BuildContext context) async {
    final settings = context.read<SettingsProvider>();

    try {
      final constants = {
        'MAX_SPEED': double.tryParse(settings.maxSpeed) ?? 100,
        'DEADZONE': double.tryParse(settings.deadzone) ?? 0.1,
        'SMOOTH_FACTOR': double.tryParse(settings.smoothFactor) ?? 0.3,
        'MOVE_THROTTLE': double.tryParse(settings.moveThrottle) ?? (1000 / 60),
      };

      final data = jsonEncode({
        'type': 'config',
        'left': fixedConfig['left'],
        'right': fixedConfig['right'],
        'constants': constants,
      });

      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      final targetIp = InternetAddress(settings.ipAddress);
      socket.send(data.codeUnits, targetIp, 8080);
      socket.close();

      print('📤 Einstellungen gesendet: $data');

      if (context.mounted) Navigator.pop(context, settings.ipAddress);
    } catch (e) {
      print('⚠️ Fehler beim Senden: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isDarkMode = settings.isDarkMode;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false, // Kein Zurück-Pfeil
        title: const Text('Settings'),
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              final settings = context.read<SettingsProvider>();
              settings.setIpAddress(_ipController.text); // IP speichern
              _sendSettingsToServer(context);            // senden
            },
            tooltip: 'Einstellungen speichern',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: Text(
              'Dark Mode',
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
            ),
            value: isDarkMode,
            onChanged: (val) => settings.setDarkMode(val),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _ipController,
            decoration: InputDecoration(
              labelText: 'Server IP-Adresse',
              labelStyle: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black54),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: isDarkMode ? Colors.white54 : Colors.black54),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: isDarkMode ? Colors.white : Colors.black),
              ),
            ),
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
            keyboardType: TextInputType.number,
            onChanged: (val) => settings.setIpAddress(val),
          ),
          const SizedBox(height: 30),
          Text(
            'Konstanten anpassen',
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontSize: 18),
            textAlign: TextAlign.center,
          ),
          _buildNumericField(context, 'MAX_SPEED', _maxSpeedController, settings.setMaxSpeed),
          _buildNumericField(context, 'DEADZONE', _deadzoneController, settings.setDeadzone),
          _buildNumericField(context, 'SMOOTH_FACTOR', _smoothFactorController, settings.setSmoothFactor),
          _buildNumericField(context, 'MOVE_THROTTLE (ms)', _moveThrottleController, settings.setMoveThrottle),
          const Divider(),
          Text(
            'Linke Buttons',
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontSize: 18),
            textAlign: TextAlign.center,
          ),
          ...List.generate(fixedConfig['left']!.length, (i) => _buildButtonDisplay(context, 'left', i)),
          const Divider(),
          Text(
            'Rechte Buttons',
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontSize: 18),
            textAlign: TextAlign.center,
          ),
          ...List.generate(fixedConfig['right']!.length, (i) => _buildButtonDisplay(context, 'right', i)),
        ],
      ),
    );
  }
}
