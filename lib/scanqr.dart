import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScanQRPage extends StatefulWidget {
  const ScanQRPage({Key? key}) : super(key: key);

  @override
  State<ScanQRPage> createState() => _ScanQRPageState();
}

class _ScanQRPageState extends State<ScanQRPage> with WidgetsBindingObserver {
  late MobileScannerController cameraController;
  bool isScanning = true;
  bool isInitialized = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  void _initializeCamera() {
    try {
      cameraController = MobileScannerController(
        // Add specific configuration to reduce logs
        detectionSpeed: DetectionSpeed.normal,
        detectionTimeoutMs: 1000,
        returnImage: false, // Don't return images to reduce memory usage
      );
      setState(() {
        isInitialized = true;
        errorMessage = null;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Camera initialization failed: $e';
        isInitialized = false;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (!isInitialized) return;

    switch (state) {
      case AppLifecycleState.resumed:
        // Resume camera when app comes back to foreground
        if (!cameraController.value.isRunning) {
          cameraController.start();
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // Stop camera to prevent background logging
        if (cameraController.value.isRunning) {
          cameraController.stop();
        }
        break;
      case AppLifecycleState.detached:
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
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
          if (isInitialized)
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
          const SizedBox(width: 16),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4.0),
          child: Container(
            color: const Color(0xFFFDC031),
            height: 4.0,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  errorMessage = null;
                });
                _initializeCamera();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (!isInitialized) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Stack(
      children: [
        // Camera preview
        MobileScanner(
          controller: cameraController,
          onDetect: _onQRCodeDetected,
        ),

        // UI overlay
        Column(
          children: [
            const Expanded(child: SizedBox()),
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
    );
  }

  void _onQRCodeDetected(BarcodeCapture capture) {
    if (!isScanning || !mounted) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
        setState(() {
          isScanning = false;
        });

        // Stop the camera immediately to prevent further scanning
        cameraController.stop();

        _showResultDialog(barcode.rawValue!);
        break; // Only process the first valid barcode
      }
    }
  }

  void _showResultDialog(String result) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Scan Result'),
          content: Text(result),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _resumeScanning();
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
                _resumeScanning();
              },
              child: const Text('Copy'),
            ),
          ],
        );
      },
    );
  }

  void _resumeScanning() {
    if (!mounted) return;

    setState(() {
      isScanning = true;
    });

    // Restart the camera
    if (isInitialized) {
      cameraController.start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (isInitialized) {
      cameraController.dispose();
    }
    super.dispose();
  }
}