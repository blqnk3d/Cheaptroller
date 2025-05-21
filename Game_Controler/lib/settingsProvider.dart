import 'package:flutter/material.dart';

class SettingsProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  String _ipAddress = '';
  String _maxSpeed = '80';
  String _deadzone = '0.1';
  String _smoothFactor = '0.3';
  String _moveThrottle = '${(1000 / 60).toStringAsFixed(0)}';

  bool get isDarkMode => _isDarkMode;
  String get ipAddress => _ipAddress;
  String get maxSpeed => _maxSpeed;
  String get deadzone => _deadzone;
  String get smoothFactor => _smoothFactor;
  String get moveThrottle => _moveThrottle;

  void setDarkMode(bool value) {
    _isDarkMode = value;
    notifyListeners();
  }

  void setIpAddress(String ip) {
    _ipAddress = ip;
    notifyListeners();
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
