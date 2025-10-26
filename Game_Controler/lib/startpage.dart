import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:game_controler/Controller_Layouts/Playstation_Controller.dart';
import 'package:game_controler/Controller_Layouts/XBox_Controller.dart.dart';
import 'package:game_controler/Elements/qrScanner.dart';
import 'package:game_controler/style.dart';
import 'package:provider/provider.dart';
import 'package:game_controler/Settings/settingsProvider.dart';

class StartPage extends StatefulWidget {
  static const routeName = '/';
  const StartPage({super.key});

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {
  late TextEditingController _ipController;

  @override
  void initState() {
    super.initState();
    // Force landscape mode
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _ipController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentIp = context.read<SettingsProvider>().ipAddress;
      _ipController.text = currentIp;
    });
  }

  @override
  void dispose() {
    _ipController.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  void _playstation_controller(String ip) {
    Navigator.pushNamed(
      context,
      Playstation_Controller.routeName,
      arguments: ip,
    );
  }

  void _xbox_controller(String ip) {
    Navigator.pushNamed(context, Xbox_Controller.routeName, arguments: ip);
  }

  void _scanQRCode() async {
    final scannedIp = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => QRScannerPage()),
    );

    if (scannedIp != null && scannedIp.isNotEmpty) {
      context.read<SettingsProvider>().setIpAddress(scannedIp);
      _ipController.text = scannedIp;
    }
  }

  Future<void> _editIpDialog() async {
    final settings = context.read<SettingsProvider>();
    final newIpController = TextEditingController(text: settings.ipAddress);

    await showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: Colors.grey[850],
            title: const Text('Edit IP', style: TextStyle(color: Colors.white)),
            content: TextField(
              controller: newIpController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Enter IP',
                hintStyle: TextStyle(color: Colors.white38),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              TextButton(
                onPressed: () {
                  final ip = newIpController.text.trim();
                  if (ip.isNotEmpty) {
                    settings.setIpAddress(ip);
                    _ipController.text = ip;
                  }
                  Navigator.pop(ctx);
                },
                child: const Text(
                  'Save',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
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
                // IP display
                GestureDetector(
                  onTap: _editIpDialog,
                  child: Text(
                    ip.isEmpty ? '(Keine IP gesetzt)' : ip,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // QR code button and label
                Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _scanQRCode,
                      icon: const Icon(Icons.qr_code_scanner, size: 28),
                      label: const Text('Scan QR Code to connect'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.background,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 20,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                ElevatedButton(
                  onPressed:
                      ip.isEmpty ? null : () => _playstation_controller(ip),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.cardBackground,
                    foregroundColor: AppColors.textPrimary,
                    disabledBackgroundColor: AppColors.buttonDisabled,
                    disabledForegroundColor: Colors.grey[500],
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 24,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Start Playstation Controller',
                    style: AppTextStyles.body,
                  ),
                ),
                const SizedBox(height: 10),

                ElevatedButton(
                  onPressed: ip.isEmpty ? null : () => _xbox_controller(ip),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.cardBackground,
                    foregroundColor: AppColors.textPrimary,
                    disabledBackgroundColor: AppColors.buttonDisabled,
                    disabledForegroundColor: Colors.grey[500],
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 24,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Start XBox Controller',
                    style: AppTextStyles.body,
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
