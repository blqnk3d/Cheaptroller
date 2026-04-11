import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Models/custom_layout_model.dart';

class SettingsProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  String _ipAddress = '';
  
  bool _hapticFeedbackEnabled = true;
  bool _gyroSteeringEnabled = false;

  CustomLayout _customLayout = CustomLayout.defaultLayout();

  bool get isDarkMode => _isDarkMode;
  String get ipAddress => _ipAddress;
  bool get hapticFeedbackEnabled => _hapticFeedbackEnabled;
  bool get gyroSteeringEnabled => _gyroSteeringEnabled;
  CustomLayout get customLayout => _customLayout;

  SettingsProvider() {
    _loadSettings();
  }

  void setDarkMode(bool value) {
    _isDarkMode = value;
    notifyListeners();
  }

  void setIpAddress(String ip) async {
    _ipAddress = ip;
    saveLastSuccessfulIp(ip);
    notifyListeners();
  }

  Future<void> saveLastSuccessfulIp(String ip) async {
    _ipAddress = ip;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_ip', ip);
    notifyListeners();
  }

  void setHapticFeedback(bool value) async {
    _hapticFeedbackEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('haptic_feedback', value);
    notifyListeners();
  }

  void setGyroSteering(bool value) async {
    _gyroSteeringEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('gyro_steering', value);
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

    final customLayoutJson = prefs.getString('custom_layout') ?? '';
    if (customLayoutJson.isNotEmpty) {
      _customLayout = CustomLayout.fromJson(customLayoutJson);
    }

    notifyListeners();
  }
}
