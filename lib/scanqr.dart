import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScanQRPage extends StatefulWidget {
  const ScanQRPage({Key? key}) : super(key: key);

  @override
  State<ScanQRPage> createState() => _ScanQRPageState();
}

class _ScanQRPageState extends State<ScanQRPage> {
  final MobileScannerController cameraController = MobileScannerController();
  bool isScanning = true;

  @override
  Widget build(BuildContext context) {
    // The Scaffold now includes a proper AppBar for a consistent look.
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'QR Scanner',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF2B326B),
        actions: [
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: cameraController,
            builder: (context, state, child) {
              return IconButton(
                icon: Icon(
                  state.torchState == TorchState.on
                      ? Icons.flash_on
                      : Icons.flash_off,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: () => cameraController.toggleTorch(),
              );
            },
          ),
          const SizedBox(width: 16), // Spacing for the icon
        ],
        // The yellow line is now part of the app bar's bottom property.
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4.0),
          child: Container(
            color: const Color(0xFFFDC031),
            height: 4.0,
          ),
        ),
      ),
      body: Stack(
        children: [
          // Layer 1: The full-screen camera preview
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              if (isScanning) {
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  if (barcode.rawValue != null) {
                    setState(() {
                      isScanning = false;
                    });
                    _showResultDialog(barcode.rawValue!);
                  }
                }
              }
            },
          ),

          // Layer 2: UI elements on top of the camera
          // The header has been replaced by the AppBar. This column now only contains
          // the bottom text box and the expanded space.
          Column(
            children: [
              // This Expanded widget fills the remaining space, pushing the next widget to the bottom.
              const Expanded(child: SizedBox()),

              // Main camera area with transparent space for camera feed
              Container(
                height: 80,
                width: double.infinity,
                color: const Color(0xFFEBEBEB),
                alignment: Alignment.center,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.0),
                  child: Text(
                    'Position the QR code within the frame',
                    style: TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showResultDialog(String result) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Scan Result'),
          content: Text(result),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  isScanning = true;
                });
              },
              child: const Text('OK'),
            ),
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: result));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
                Navigator.of(context).pop();
                setState(() {
                  isScanning = true;
                });
              },
              child: const Text('Copy'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
}
