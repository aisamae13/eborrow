import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';
import 'catalogpage.dart'; // Needed for the Equipment model
import 'equipment_detail_page.dart';

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
                    // Stop scanning immediately to prevent multiple detections
                    setState(() {
                      isScanning = false;
                    });
                    // Call our new handler function with the scanned code
                    _handleScan(barcode.rawValue!);
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
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Search the 'equipment' table for a matching 'qr_code'
      final response = await supabase
          .from('equipment')
          .select('*, equipment_categories(category_name)')
          .eq('qr_code', qrCode)
          .single(); // .single() expects exactly one matching row

      // Dismiss the loading indicator
      Navigator.of(context).pop();

      // Convert the database response into an Equipment object
      final equipment = Equipment.fromMap(response);

      // Navigate to the detail page for the found item
      if (mounted) {
        // We await the result of the push, so we can re-enable scanning
        // after the user comes back from the detail page.
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => EquipmentDetailPage(equipment: equipment),
          ),
        );
      }
    } catch (e) {
      // If .single() finds no rows or an error occurs, it will throw an exception
      // Dismiss the loading indicator
      Navigator.of(context).pop();

      // Show an error message to the user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Equipment not found. Please try another code.',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      // This block runs whether the scan was successful or not.
      // We re-enable scanning so the user can try again.
      if (mounted) {
        setState(() {
          isScanning = true;
        });
      }
    }

    @override
    void dispose() {
      cameraController.dispose();
      super.dispose();
    }
  }
}
