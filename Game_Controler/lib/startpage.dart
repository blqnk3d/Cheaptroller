import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:game_controler/Controller_Layouts/Playstation_Controller.dart';
import 'package:game_controler/Controller_Layouts/XBox_Controller.dart';
import 'package:game_controler/Controller_Layouts/Custom_Controller.dart';
import 'package:game_controler/Controller_Layouts/Custom_Controller_Editor.dart';
import 'package:game_controler/Elements/qrScanner.dart';
import 'package:provider/provider.dart';
import 'package:game_controler/Settings/settingsProvider.dart';

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
    ]);
  }

  void _navigateTo(String routeName, {Object? arguments}) {
    Navigator.pushNamed(context, routeName, arguments: arguments);
  }

  void _layout_editor() {
    Navigator.pushNamed(context, CustomControllerEditor.routeName);
  }

  void _scanQRCode() async {
    final scannedIp = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QRScannerPage()),
    );

    if (scannedIp != null && scannedIp.isNotEmpty) {
      if (mounted) {
        context.read<SettingsProvider>().setIpAddress(scannedIp);
      }
    }
  }

  Future<void> _settingsDialog() async {
    final settings = context.read<SettingsProvider>();
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.white10),
          ),
          title: const Row(
            children: [
              Icon(Icons.settings, color: Colors.blueAccent),
              SizedBox(width: 10),
              Text('Settings', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogSwitch('Haptic Feedback', settings.hapticFeedbackEnabled, (val) {
                settings.setHapticFeedback(val);
                setState(() {});
              }),
              _dialogSwitch('Gyro Steering', settings.gyroSteeringEnabled, (val) {
                settings.setGyroSteering(val);
                setState(() {});
              }),
              _dialogSwitch('Show Connection Status', settings.showConnectionStatus, (val) {
                settings.setShowConnectionStatus(val);
                setState(() {});
              }),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close', style: TextStyle(color: Colors.blueAccent)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogSwitch(String title, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
      value: value,
      activeColor: Colors.blueAccent,
      onChanged: onChanged,
    );
  }

  Future<void> _editIpDialog() async {
    final settings = context.read<SettingsProvider>();
    final newIpController = TextEditingController(text: settings.ipAddress);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.white10),
        ),
        title: const Text('Server IP Address', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: newIpController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'e.g. 192.168.1.10',
            hintStyle: const TextStyle(color: Colors.white24),
            filled: true,
            fillColor: Colors.black26,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white70))),
          ElevatedButton(
            onPressed: () {
              final ip = newIpController.text.trim();
              if (ip.isNotEmpty) {
                settings.setIpAddress(ip);
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
            child: const Text('Save'),
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
      backgroundColor: const Color(0xFF0F0F0F),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.5,
            colors: [
              Colors.blueAccent.withValues(alpha: 0.05),
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('CHEAPTROLLER', 
                          style: TextStyle(
                            color: Colors.white, 
                            fontSize: 24, 
                            fontWeight: FontWeight.w900, 
                            letterSpacing: 2
                          )
                        ),
                        Text('Mobile Game Controller', 
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5), 
                            fontSize: 12
                          )
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings_outlined, color: Colors.white70),
                      onPressed: _settingsDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                
                // Connection Card
                _buildConnectionCard(ip),
                
                const SizedBox(height: 40),
                const Text('SELECT CONTROLLER', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                const SizedBox(height: 16),
                
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _controllerCard(
                        'Playstation DualShock',
                        'Classic PS layout with DPAD and face buttons',
                        Icons.sports_esports,
                        Colors.blueAccent,
                        ip.isEmpty ? null : () => _navigateTo(Playstation_Controller.routeName, arguments: ip),
                      ),
                      _controllerCard(
                        'Xbox Wireless',
                        'Standard Xbox offset joystick layout',
                        Icons.videogame_asset,
                        Colors.greenAccent,
                        ip.isEmpty ? null : () => _navigateTo(Xbox_Controller.routeName, arguments: ip),
                      ),
                      _controllerCard(
                        'Custom Layout',
                        'Your own personalized controller setup',
                        Icons.dashboard_customize,
                        Colors.orangeAccent,
                        ip.isEmpty ? null : () => _navigateTo(CustomController.routeName, arguments: ip),
                      ),
                      const SizedBox(height: 20),
                      
                      // Editor Button
                      InkWell(
                        onTap: _layout_editor,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.edit_note, color: Colors.white70),
                              SizedBox(width: 10),
                              Text('OPEN LAYOUT EDITOR', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionCard(String ip) {
    bool isConnected = ip.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isConnected ? Colors.blueAccent.withValues(alpha: 0.3) : Colors.white10),
        boxShadow: [
          if (isConnected) BoxShadow(color: Colors.blueAccent.withValues(alpha: 0.1), blurRadius: 20, spreadRadius: -5),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isConnected ? Colors.blueAccent.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(isConnected ? Icons.link : Icons.link_off, color: isConnected ? Colors.blueAccent : Colors.white38),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isConnected ? 'Connected Server' : 'No Server Linked', style: TextStyle(color: isConnected ? Colors.white : Colors.white38, fontSize: 16, fontWeight: FontWeight.bold)),
                    GestureDetector(
                      onTap: _editIpDialog,
                      child: Text(isConnected ? ip : 'Tap to set IP manually', style: TextStyle(color: isConnected ? Colors.blueAccent : Colors.white24, fontSize: 13)),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.qr_code_scanner, color: Colors.white70),
                onPressed: _scanQRCode,
                tooltip: 'Scan QR Code',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _controllerCard(String title, String subtitle, IconData icon, Color color, VoidCallback? onTap) {
    bool isDisabled = onTap == null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Opacity(
        opacity: isDisabled ? 0.5 : 1.0,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
