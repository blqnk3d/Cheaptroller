import 'dart:convert';
import 'dart:io';

class ControllerUtils {
  final RawDatagramSocket? socket;
  final InternetAddress? serverAddress;
  final int port;

  ControllerUtils({
    required this.socket,
    required this.serverAddress,
    this.port = 8080,
  });

  void sendUDP(Map<String, dynamic> data) {
    if (socket == null || serverAddress == null) return;
    final bytes = utf8.encode(jsonEncode(data));
    socket!.send(bytes, serverAddress!, port);
  }

  void sendMove(String side, double x, double y) {
    sendUDP({"type": "move", "side": side, "x": x, "y": y});
  }

  void sendButton(String side, int index, bool pressed) {
    sendUDP({
      "type": pressed ? "button_down" : "button_up",
      "side": side,
      "index": index,
    });
  }
}
