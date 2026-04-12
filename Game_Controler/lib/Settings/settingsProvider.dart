import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Models/custom_layout_model.dart';
import '../utils/udp_service.dart'; // Import UdpService
import 'package:provider/provider.dart'; // Import Provider

class SettingsProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  String _ipAddress = '';
  
  bool _hapticFeedbackEnabled = true;
  bool _gyroSteeringEnabled = false;
  bool _showConnectionStatus = false;

  CustomLayout _customLayout = CustomLayout.defaultLayout();

  bool get isDarkMode => _isDarkMode;
  String get ipAddress => _ipAddress;
  bool get hapticFeedbackEnabled => _hapticFeedbackEnabled;
  bool get gyroSteeringEnabled => _gyroSteeringEnabled;
  bool get showConnectionStatus => _showConnectionStatus;
  CustomLayout get customLayout => _customLayout;

  SettingsProvider() {
    _loadSettings();
  }

  void setDarkMode(bool value) {
    _isDarkMode = value;
    notifyListeners();
  }

  void setIpAddress(String ip, BuildContext context) async {
    _ipAddress = ip;
    await saveLastSuccessfulIp(ip);
    // Notify UdpService to connect/reconnect
    Provider.of<UdpService>(context, listen: false).connect(ip);
    notifyListeners();
  }

  Future<void> saveLastSuccessfulIp(String ip) async {
    _ipAddress = ip;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_ip', ip);
    // No need to notifyListeners() here as it's called by setIpAddress
  }

  void setHapticFeedback(bool value, BuildContext context) async {
    _hapticFeedbackEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('haptic_feedback', value);
    // Notify UdpService about the setting change
    Provider.of<UdpService>(context, listen: false).updateSettings(
      _gyroSteeringEnabled,
      value,
      _showConnectionStatus,
    );
    notifyListeners();
  }

  void setGyroSteering(bool value, BuildContext context) async {
    _gyroSteeringEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('gyro_steering', value);
    // Notify UdpService about the setting change
    Provider.of<UdpService>(context, listen: false).updateSettings(
      value,
      _hapticFeedbackEnabled,
      _showConnectionStatus,
    );
    notifyListeners();
  }

  void setShowConnectionStatus(bool value, BuildContext context) async {
    _showConnectionStatus = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_connection_status', value);
    // Notify UdpService about the setting change
    Provider.of<UdpService>(context, listen: false).updateSettings(
      _gyroSteeringEnabled,
      _hapticFeedbackEnabled,
      value,
    );
    notifyListeners();
  }


  Future<void> saveCustomLayout(CustomLayout layout) async {
    _customLayout = layout;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_layout', layout.toJson());
    notifyListeners();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _ipAddress = prefs.getString('last_ip') ?? '';
    _hapticFeedbackEnabled = prefs.getBool('haptic_feedback') ?? true;
    _gyroSteeringEnabled = prefs.getBool('gyro_steering') ?? false;
    _showConnectionStatus = prefs.getBool('show_connection_status') ?? false;

    final customLayoutJson = prefs.getString('custom_layout') ?? '';
    if (customLayoutJson.isNotEmpty) {
      _customLayout = CustomLayout.fromJson(customLayoutJson);
    }

    notifyListeners();
  }
}
