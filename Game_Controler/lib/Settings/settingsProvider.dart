import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  String _ipAddress = '';
  String _maxSpeed = '50';
  String _deadzone = '0.001';
  String _smoothFactor = '0.5';
  String _moveThrottle = '1';

  bool get isDarkMode => _isDarkMode;
  String get ipAddress => _ipAddress;
  String get maxSpeed => _maxSpeed;
  String get deadzone => _deadzone;
  String get smoothFactor => _smoothFactor;
  String get moveThrottle => _moveThrottle;

  SettingsProvider() {
    _loadSavedIp();
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

  Future<void> _loadSavedIp() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIp = prefs.getString('last_ip');
    if (savedIp != null) {
      _ipAddress = savedIp;
      notifyListeners();
    }
  }

  void setMaxSpeed(String val) {
    _maxSpeed = val;
    notifyListeners();
  }

  void setDeadzone(String val) {
    _deadzone = val;
    notifyListeners();
  }

  void setSmoothFactor(String val) {
    _smoothFactor = val;
    notifyListeners();
  }

  void setMoveThrottle(String val) {
    _moveThrottle = val;
    notifyListeners();
  }
}
