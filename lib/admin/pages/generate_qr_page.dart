import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:gal/gal.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';
import '../../main.dart';

class GenerateQRPage extends StatefulWidget {
  const GenerateQRPage({super.key});

  @override
  State<GenerateQRPage> createState() => _GenerateQRPageState();
}

class _GenerateQRPageState extends State<GenerateQRPage> {
  List<Map<String, dynamic>> equipmentList = [];
  Map<String, dynamic>? selectedEquipment;
  bool isLoading = true;
  bool isSaving = false;
  final GlobalKey _qrKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadEquipment();
  }

  Future<void> _loadEquipment() async {
    try {
      // Use correct column names from your schema
      final data = await supabase
          .from('equipment')
          .select('equipment_id, name, qr_code')
          .order('name');
      
      if (mounted) {
        setState(() {
          equipmentList = List<Map<String, dynamic>>.from(data);
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading equipment: $e')),
        );
      }
    }
  }

  Future<void> _generateQRCodeAutomatically() async {
    if (selectedEquipment == null) return;

    try {
      // Generate a unique QR code if it doesn't exist
      String qrCode = selectedEquipment!['qr_code'] ?? 'EQP-${selectedEquipment!['equipment_id']}';
      
      // Update the equipment with the QR code using correct column name
      await supabase
          .from('equipment')
          .update({'qr_code': qrCode})
          .eq('equipment_id', selectedEquipment!['equipment_id']);

      setState(() {
        selectedEquipment!['qr_code'] = qrCode;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating QR code: $e')),
      );
    }
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      // Request permissions for saving to gallery
      if (!await Gal.hasAccess()) {
        await Gal.requestAccess();
      }
    }
  }

  Future<void> _saveQRCodeAsImage() async {
    if (selectedEquipment == null || selectedEquipment!['qr_code'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No QR code to save')),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      await _requestPermissions();

      // Capture the QR code as image
      RenderRepaintBoundary boundary = _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List imageBytes = byteData!.buffer.asUint8List();

      // Generate filename with equipment name and timestamp
      String equipmentName = selectedEquipment!['name'].replaceAll(RegExp(r'[^\w\s-]'), '');
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      
      // Save to temporary file first
      Directory tempDir = await getTemporaryDirectory();
      String filename = 'QR_${equipmentName}_$timestamp.png';
      File tempFile = File('${tempDir.path}/$filename');
      await tempFile.writeAsBytes(imageBytes);

      // Save to gallery using Gal
      await Gal.putImage(tempFile.path, album: 'E-Borrow QR Codes');

      // Clean up temp file
      await tempFile.delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('QR Code saved to gallery as $filename'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving QR code: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Generate QR Code',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF2B326B),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4.0),
          child: Container(color: const Color(0xFFFFC107), height: 4.0),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : equipmentList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No equipment found',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add some equipment first',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Equipment',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Equipment Dropdown
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: DropdownButtonFormField<Map<String, dynamic>>(
                          decoration: const InputDecoration(
                            labelText: 'Choose Equipment',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          items: equipmentList.map((equipment) {
                            return DropdownMenuItem<Map<String, dynamic>>(
                              value: equipment,
                              child: Text(
                                equipment['name'] ?? 'Unnamed Equipment',
                                style: GoogleFonts.poppins(),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) async {
                            setState(() {
                              selectedEquipment = value;
                            });
                            // Automatically generate QR code when equipment is selected
                            if (value != null) {
                              await _generateQRCodeAutomatically();
                            }
                          },
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Save to Gallery Button
                      if (selectedEquipment != null && selectedEquipment!['qr_code'] != null)
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: isSaving ? null : _saveQRCodeAsImage,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFC107),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: isSaving 
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.photo_library, size: 20),
                            label: Text(
                              isSaving ? 'Saving...' : 'Save to Gallery',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w500,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 32),

                      // QR Code Display
                      if (selectedEquipment != null && selectedEquipment!['qr_code'] != null)
                        Expanded(
                          child: Center(
                            child: RepaintBoundary(
                              key: _qrKey,
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.1),
                                      spreadRadius: 1,
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      selectedEquipment!['name'] ?? 'Equipment',
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 16),
                                    QrImageView(
                                      data: selectedEquipment!['qr_code'],
                                      version: QrVersions.auto,
                                      size: 200,
                                      backgroundColor: Colors.white,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'QR Code: ${selectedEquipment!['qr_code']}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}