import 'package:flutter_test/flutter_test.dart';
import 'package:game_controler/Settings/settingsProvider.dart';
import 'package:game_controler/Models/custom_layout_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SettingsProvider', () {
    late SettingsProvider settings;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      settings = SettingsProvider();
      await Future.delayed(Duration.zero);
    });

    test('should have default dark mode as false', () {
      expect(settings.isDarkMode, false);
    });

    test('should have default ipAddress as empty', () {
      expect(settings.ipAddress, '');
    });

    test('should have default hapticFeedbackEnabled as true', () {
      expect(settings.hapticFeedbackEnabled, true);
    });

    test('should have default gyroSteeringEnabled as false', () {
      expect(settings.gyroSteeringEnabled, false);
    });

    test('should have default showConnectionStatus as false', () {
      expect(settings.showConnectionStatus, false);
    });

    test('should have default custom layout', () {
      expect(settings.customLayout.elements.isNotEmpty, true);
    });

    test('should update dark mode', () {
      settings.setDarkMode(true);
      expect(settings.isDarkMode, true);

      settings.setDarkMode(false);
      expect(settings.isDarkMode, false);
    });

    test('should update IP address', () {
      settings.setIpAddress('192.168.1.100');
      expect(settings.ipAddress, '192.168.1.100');
    });

    test('should update haptic feedback setting', () {
      settings.setHapticFeedback(false);
      expect(settings.hapticFeedbackEnabled, false);
    });

    test('should update gyro steering setting', () {
      settings.setGyroSteering(true);
      expect(settings.gyroSteeringEnabled, true);
    });

    test('should update connection status visibility', () {
      settings.setShowConnectionStatus(true);
      expect(settings.showConnectionStatus, true);
    });

    test('should save and update custom layout', () async {
      final newLayout = CustomLayout(
        elements: [
          ControlElement(
            type: ControlType.dpad,
            x: 0.2,
            y: 0.2,
            size: 100,
            side: 'left',
          ),
        ],
      );

      await settings.saveCustomLayout(newLayout);
      expect(settings.customLayout.elements.length, 1);
      expect(settings.customLayout.elements[0].type, ControlType.dpad);
    });
  });

  group('SettingsProvider persistence', () {
    test('should load saved IP address', () async {
      SharedPreferences.setMockInitialValues({
        'last_ip': '192.168.1.50',
      });

      final settings = SettingsProvider();
      await Future.delayed(Duration.zero);

      expect(settings.ipAddress, '192.168.1.50');
    });

    test('should load saved haptic feedback preference', () async {
      SharedPreferences.setMockInitialValues({
        'haptic_feedback': false,
      });

      final settings = SettingsProvider();
      await Future.delayed(Duration.zero);

      expect(settings.hapticFeedbackEnabled, false);
    });

    test('should load saved gyro steering preference', () async {
      SharedPreferences.setMockInitialValues({
        'gyro_steering': true,
      });

      final settings = SettingsProvider();
      await Future.delayed(Duration.zero);

      expect(settings.gyroSteeringEnabled, true);
    });

    test('should load saved custom layout', () async {
      SharedPreferences.setMockInitialValues({
        'custom_layout': '[{"type":2,"x":0.5,"y":0.5,"size":100,"side":"right","label":"Test"}]',
      });

      final settings = SettingsProvider();
      await Future.delayed(Duration.zero);

      expect(settings.customLayout.elements.length, 1);
      expect(settings.customLayout.elements[0].type, ControlType.faceButtons);
    });
  });
}