import 'package:flutter/material.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;

  void _onQRViewCreated(QRViewController ctrl) {
    controller = ctrl;
    controller!.scannedDataStream.listen((scanData) {
      final url = scanData.code;
      if (url != null && url.isNotEmpty) {
        // Extract IP only (strip http:// and port)
        final ip = Uri.tryParse(url)?.host ?? '';
        if (ip.isNotEmpty) {
          controller!.pauseCamera();
          Navigator.pop(context, ip);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Scan QR Code')),
      body: QRView(key: qrKey, onQRViewCreated: _onQRViewCreated),
    );
  }
}
