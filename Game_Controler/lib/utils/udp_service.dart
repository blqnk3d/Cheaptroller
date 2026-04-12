import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:game_controler/Settings/settingsProvider.dart';
import 'package:msgpack_dart/msgpack_dart.dart' as msgpack;
import 'package:vibration/vibration.dart';
import 'package:sensors_plus/sensors_plus.dart';

// A service to manage UDP communication and controller-specific logic.
class UdpService with ChangeNotifier {
  RawDatagramSocket? _socket;
  InternetAddress? _serverAddress;
  bool _isSocketReady = false;
  final int _port = 8080;
  final Set<String> _pressedButtons = {};

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  double _lastGyroX = 0;
  bool _gyroSteeringEnabled = false;
  bool _hapticFeedbackEnabled = false;
  bool _showConnectionStatus = false;

  // UDP Queue for non-blocking sends
  final StreamController<List<int>> _udpQueue = StreamController<List<int>>();
  StreamSubscription? _queueSubscription;

  String get ipAddress => _serverAddress?.address ?? '';
  bool get isSocketReady => _isSocketReady;
  bool get gyroSteeringEnabled => _gyroSteeringEnabled;
  bool get hapticFeedbackEnabled => _hapticFeedbackEnabled;
  bool get showConnectionStatus => _showConnectionStatus;

  UdpService() {
    _initQueue();
    // Listen to SettingsProvider changes to update gyro/haptics settings
    // Note: In a real app, you might inject SettingsProvider or use a more direct
    // mechanism if SettingsProvider is not globally available as a ChangeNotifier.
    // For this example, we assume we can access it or it will be passed in.
    // For now, we'll rely on explicit calls to update settings.
  }

  // Call this method to update settings from SettingsProvider
  void updateSettings(bool gyro, bool haptics, bool showStatus) {
    _gyroSteeringEnabled = gyro;
    _hapticFeedbackEnabled = haptics;
    _showConnectionStatus = showStatus;
    if (_gyroSteeringEnabled) {
      _initGyro();
    } else {
      _accelerometerSubscription?.cancel();
      _accelerometerSubscription = null;
    }
    notifyListeners();
  }

  void _initQueue() {
    _queueSubscription = _udpQueue.stream.listen((bytes) {
      if (_isSocketReady && _socket != null && _serverAddress != null) {
        try {
          _socket!.send(bytes, _serverAddress!, _port);
        } catch (e) {
          print('UDP Send Error: $e'); // Basic logging
          // Potentially handle error, e.g., try to re-bind or notify user
          _isSocketReady = false;
          notifyListeners();
        }
      }
    });
  }

  void _initGyro() {
    if (!_gyroSteeringEnabled || _accelerometerSubscription != null) return;

    _accelerometerSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
      // In landscape, we use Y-axis for left/right steering (tilt)
      double steering = (event.y / 7.0).clamp(-1.0, 1.0);

      // Send only if it changed enough to matter (0.015 threshold)
      if ((steering - _lastGyroX).abs() > 0.015) {
        _lastGyroX = steering;
        sendMove('left', steering, 0);
      }
    });
  }

  Future<void> connect(String ip) async {
    if (ip == _serverAddress?.address && _isSocketReady) return;

    print('Connecting to $ip...');
    setState(() => _isSocketReady = false);
    _socket?.close();

    try {
      _serverAddress = InternetAddress(ip);
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _isSocketReady = true;
      print('UDP Socket bound to ${_socket!.address.address}:${_socket!.port}');
      // Set system orientations only when connected/initialized
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      notifyListeners();
    } catch (e) {
      print('UDP Connection Error: $e');
      _isSocketReady = false;
      notifyListeners();
    }
  }

  void disconnect() {
    _socket?.close();
    _socket = null;
    _serverAddress = null;
    _isSocketReady = false;
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
    _queueSubscription?.cancel();
    _udpQueue.close(); // Close the stream controller as well
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    print('UDP Socket closed.');
    notifyListeners();
  }

  // Common method to pack and send data
  void _sendPackedData(Map<String, dynamic> data) {
    if (!_isSocketReady || _socket == null || _serverAddress == null) return;

    try {
      // Use binary keys for reduced payload
      final Map<String, dynamic> optimizedData = {
        't': data['type'], // 'move', 'button_down', 'button_up'
        'ts': DateTime.now().millisecondsSinceEpoch,
        if (data.containsKey('side')) 's': data['side'], // 'left', 'right'
        if (data.containsKey('x')) 'x': data['x'],
        if (data.containsKey('y')) 'y': data['y'],
        if (data.containsKey('index')) 'i': data['index'],
      };
      final encoder = msgpack.Encoder();
      encoder.write(optimizedData);
      final bytes = encoder.drain();
      _udpQueue.add(bytes);
    } catch (e) {
      print('Error packing or queuing UDP data: $e');
    }
  }

  // --- Controller specific actions ---

  void sendMove(String side, double x, double y) {
    _sendPackedData({"type": "move", "side": side, "x": x, "y": y});
  }

  void sendButton(String side, int index, bool pressed) {
    if (_pressedButtons.contains('$side-$index') && pressed) return; // Prevent duplicate down events
    if (!pressed) {
      _pressedButtons.discard('$side-$index');
    } else {
      _pressedButtons.add('$side-$index');
      if (_hapticFeedbackEnabled) {
        Vibration.vibrate(duration: 20); // Short vibration for button press
      }
    }
    _sendPackedData({
      "type": pressed ? "button_down" : "button_up",
      "side": side,
      "index": index,
    });
  }

  void sendCustomButton(String buttonId, bool pressed) {
    // For custom buttons, 'index' might not be relevant, use a unique ID if needed
    // For now, we'll map it to a generic index if possible, or send as is.
    // This part might need adjustment based on how custom buttons are defined.

    // Example: If custom buttons are mapped to specific indices or types
    // For now, sending a generic button event
    _sendPackedData({
      "type": pressed ? "button_down" : "button_up",
      "id": buttonId, // Custom identifier
      // Add other relevant data if your protocol supports it
    });
  }

  // --- Gyro and Haptics ---
  void toggleGyroSteering() {
    _gyroSteeringEnabled = !_gyroSteeringEnabled;
    if (_gyroSteeringEnabled) {
      _initGyro();
    } else {
      _accelerometerSubscription?.cancel();
      _accelerometerSubscription = null;
    }
    notifyListeners();
  }

  void toggleHapticFeedback() {
    _hapticFeedbackEnabled = !_hapticFeedbackEnabled;
    notifyListeners();
  }
  
  void toggleConnectionStatusVisibility() {
    _showConnectionStatus = !_showConnectionStatus;
    notifyListeners();
  }

  @override
  void dispose() {
    _socket?.close();
    _queueSubscription?.cancel();
    _udpQueue.close();
    _accelerometerSubscription?.cancel();
    // Revert system settings when service is disposed
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    print('UdpService disposed.');
    super.dispose();
  }
}

// Helper extension for easy clearing of sets
extension SetExtensions<T> on Set<T> {
  void discard(T element) {
    remove(element);
  }
}

// Example usage of the service (e.g., in a widget):
/*
void _setupService(BuildContext context) {
  final udpService = Provider.of<UdpService>(context, listen: false);
  final settings = Provider.of<SettingsProvider>(context, listen: false);
  udpService.updateSettings(
    settings.gyroSteeringEnabled,
    settings.hapticFeedbackEnabled,
    settings.showConnectionStatus,
  );
  udpService.connect(settings.ipAddress);
}
*/
