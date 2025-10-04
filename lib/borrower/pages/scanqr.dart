import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';
import '../models/equipment_model.dart'; // This is the correct import
import 'equipment_detail_page.dart';

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
          child: Container(color: const Color(0xFFFDC031), height: 4.0),
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
                    // Call the new, corrected function
                    _handleScan(barcode.rawValue!);
                  }
                }
              }
            },
          ),
          // Layer 2: UI elements on top of the camera
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
                    style: TextStyle(color: Color(0xFF888888), fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleScan(String qrCode) async {
    // Show a loading indicator while we search the database
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(child: CircularProgressIndicator());
      },
    );



    try {
      final query = supabase
          .from('equipment')
          .select('*, equipment_categories(*)')
          .eq('qr_code', qrCode);
          

      final response = await query.maybeSingle();

      // Dismiss the loading dialog
      Navigator.of(context).pop();

      if (response != null) {
        // Equipment found! Navigate to the detail page.
        final equipment = Equipment.fromMap(response);
        if (mounted) {
          Navigator.of(context).push(
            // <-- MODIFIED
            MaterialPageRoute(
              builder: (context) => EquipmentDetailPage(equipment: equipment),
            ),
          );
        }
      } else {
        // No equipment found with that QR code
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No equipment found for this QR code.'),
              backgroundColor: Colors.red,
            ),
          );
          // Resume scanning after a brief delay
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() {
                isScanning = true;
              });
            }
          });
        }
      }
    } on PostgrestException catch (e) {
      // Handle Supabase errors
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Handle any other errors
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An unexpected error occurred: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // Ensure scanning is re-enabled if an error occurred
      if (!isScanning && mounted) {
        setState(() {
          isScanning = true;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    cameraController.dispose();
    super.dispose();
  }
}
