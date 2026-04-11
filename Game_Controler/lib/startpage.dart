import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:game_controler/Controller_Layouts/Playstation_Controller.dart';
import 'package:game_controler/Controller_Layouts/XBox_Controller.dart';
import 'package:game_controler/Controller_Layouts/Custom_Controller.dart';
import 'package:game_controler/Controller_Layouts/Custom_Controller_Editor.dart';
import 'package:game_controler/Elements/qrScanner.dart';
import 'package:game_controler/style.dart';
import 'package:provider/provider.dart';
import 'package:game_controler/Settings/settingsProvider.dart';

// RouteObserver to detect returning from other pages
final RouteObserver<ModalRoute> routeObserver = RouteObserver<ModalRoute>();

class StartPage extends StatefulWidget {
  static const routeName = '/';
  const StartPage({super.key});

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> with RouteAware {
  late TextEditingController _ipController;

  @override
  void initState() {
    super.initState();

    _ipController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentIp = context.read<SettingsProvider>().ipAddress;
      _ipController.text = currentIp;
    });
  }

  @override
  void dispose() {
    _ipController.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values); // reset
    routeObserver.unsubscribe(this);
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

  void _custom_controller(String ip) {
    Navigator.pushNamed(context, CustomController.routeName, arguments: ip);
  }

  void _layout_editor() {
    Navigator.pushNamed(context, CustomControllerEditor.routeName);
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

  Future<void> _settingsDialog() async {
    final settings = context.read<SettingsProvider>();
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.grey[850],
          title: const Text('Settings', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Haptic Feedback', style: TextStyle(color: Colors.white)),
                value: settings.hapticFeedbackEnabled,
                onChanged: (val) {
                  settings.setHapticFeedback(val);
                  setState(() {});
                },
              ),
              SwitchListTile(
                title: const Text('Gyro Steering', style: TextStyle(color: Colors.white)),
                value: settings.gyroSteeringEnabled,
                onChanged: (val) {
                  settings.setGyroSteering(val);
                  setState(() {});
                },
              ),
              SwitchListTile(
                title: const Text('Show Connection Status', style: TextStyle(color: Colors.white)),
                value: settings.showConnectionStatus,
                onChanged: (val) {
                  settings.setShowConnectionStatus(val);
                  setState(() {});
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: _settingsDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: _editIpDialog,
                    child: Text(
                      ip.isEmpty ? '(Keine IP gesetzt)' : ip,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _scanQRCode,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan QR code to connect'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.background,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 24,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
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
                      minimumSize: const Size(double.infinity, 50),
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
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Start XBox Controller',
                      style: AppTextStyles.body,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: ip.isEmpty ? null : () => _custom_controller(ip),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.cardBackground,
                      foregroundColor: AppColors.textPrimary,
                      disabledBackgroundColor: AppColors.buttonDisabled,
                      disabledForegroundColor: Colors.grey[500],
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 24,
                      ),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Start Custom Controller',
                      style: AppTextStyles.body,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _layout_editor,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey[800],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 24,
                      ),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Edit Custom Layout',
                      style: AppTextStyles.body,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
