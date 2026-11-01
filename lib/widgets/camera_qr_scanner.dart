import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/app_theme.dart';

/// Full-screen camera QR scanner screen for AirShare Spark bootstrap.
class CameraQrScannerScreen extends StatefulWidget {
  final String title;
  final String? hintText;

  const CameraQrScannerScreen({
    super.key,
    this.title = 'Scan Spark QR Code',
    this.hintText,
  });

  @override
  State<CameraQrScannerScreen> createState() => _CameraQrScannerScreenState();
}

class _CameraQrScannerScreenState extends State<CameraQrScannerScreen>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _controller;
  late final AnimationController _animController;
  bool _isDispatched = false;
  bool _torchEnabled = false;
  CameraFacing _facing = CameraFacing.back;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: _facing,
      torchEnabled: false,
    );

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleBarcode(BarcodeCapture capture) {
    if (_isDispatched) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.isNotEmpty) {
        _isDispatched = true;
        HapticFeedback.mediumImpact();
        Navigator.of(context).pop(raw);
        return;
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final capture = await _controller.analyzeImage(path);
        if (capture != null && capture.barcodes.isNotEmpty) {
          final code = capture.barcodes.first.rawValue;
          if (code != null && code.isNotEmpty && mounted) {
            _isDispatched = true;
            HapticFeedback.mediumImpact();
            Navigator.of(context).pop(code);
            return;
          }
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.surfaceZinc,
              content: Text('No QR code detected in selected image.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Error analyzing image: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final scanBoxSize = (screenSize.width * 0.72).clamp(220.0, 300.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Live Camera Stream
          MobileScanner(
            controller: _controller,
            onDetect: _handleBarcode,
            errorBuilder: (context, error, child) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.camera_alt_outlined,
                          size: 56, color: Colors.white38),
                      const SizedBox(height: 16),
                      Text(
                        'Camera unavailable (${error.errorCode.name})',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 15),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.orangeAccent),
                        icon: const Icon(Icons.photo_library,
                            color: Colors.black),
                        label: const Text('Pick QR from Gallery',
                            style: TextStyle(color: Colors.black)),
                        onPressed: _pickImage,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Custom Viewfinder Overlay
          CustomPaint(
            painter: _ScannerOverlayPainter(
              boxSize: scanBoxSize,
              borderColor: AppColors.orangeAccent,
            ),
            child: const SizedBox.expand(),
          ),

          // Animated Scan Laser
          Center(
            child: SizedBox(
              width: scanBoxSize - 20,
              height: scanBoxSize - 20,
              child: AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  return Align(
                    alignment: Alignment(0, (_animController.value * 2) - 1),
                    child: Container(
                      height: 2.5,
                      decoration: BoxDecoration(
                        color: AppColors.orangeAccent,
                        boxShadow: [
                          BoxShadow(
                            color:
                                AppColors.orangeAccent.withValues(alpha: 0.8),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Top Header Controls
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: Colors.white, size: 24),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _torchEnabled ? Icons.flash_on : Icons.flash_off,
                        color: _torchEnabled
                            ? AppColors.orangeAccent
                            : Colors.white70,
                      ),
                      onPressed: () async {
                        await _controller.toggleTorch();
                        setState(() => _torchEnabled = !_torchEnabled);
                      },
                    ),
                    IconButton(
                      icon:
                          const Icon(Icons.cameraswitch, color: Colors.white70),
                      onPressed: () async {
                        await _controller.switchCamera();
                        setState(() {
                          _facing = _facing == CameraFacing.back
                              ? CameraFacing.front
                              : CameraFacing.back;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Helper and Actions
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        widget.hintText ??
                            'Align Spark QR code within the frame to connect',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        backgroundColor: Colors.black45,
                      ),
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('Scan Image / Screenshot',
                          style: TextStyle(fontSize: 13)),
                      onPressed: _pickImage,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final double boxSize;
  final Color borderColor;

  _ScannerOverlayPainter({
    required this.boxSize,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = Colors.black.withValues(alpha: 0.62);
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final rect =
        Rect.fromCenter(center: center, width: boxSize, height: boxSize);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(16));

    // Darkened outer mask with transparent cutout
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, bgPaint);

    // Corner Reticles
    const cornerLength = 26.0;
    // Top-Left
    canvas.drawLine(Offset(rect.left, rect.top + cornerLength),
        Offset(rect.left, rect.top + 8), borderPaint);
    canvas.drawLine(Offset(rect.left, rect.top + 8),
        Offset(rect.left + 8, rect.top), borderPaint);
    canvas.drawLine(Offset(rect.left + 8, rect.top),
        Offset(rect.left + cornerLength, rect.top), borderPaint);

    // Top-Right
    canvas.drawLine(Offset(rect.right - cornerLength, rect.top),
        Offset(rect.right - 8, rect.top), borderPaint);
    canvas.drawLine(Offset(rect.right - 8, rect.top),
        Offset(rect.right, rect.top + 8), borderPaint);
    canvas.drawLine(Offset(rect.right, rect.top + 8),
        Offset(rect.right, rect.top + cornerLength), borderPaint);

    // Bottom-Left
    canvas.drawLine(Offset(rect.left, rect.bottom - cornerLength),
        Offset(rect.left, rect.bottom - 8), borderPaint);
    canvas.drawLine(Offset(rect.left, rect.bottom - 8),
        Offset(rect.left + 8, rect.bottom), borderPaint);
    canvas.drawLine(Offset(rect.left + 8, rect.bottom),
        Offset(rect.left + cornerLength, rect.bottom), borderPaint);

    // Bottom-Right
    canvas.drawLine(Offset(rect.right - cornerLength, rect.bottom),
        Offset(rect.right - 8, rect.bottom), borderPaint);
    canvas.drawLine(Offset(rect.right - 8, rect.bottom),
        Offset(rect.right, rect.bottom - 8), borderPaint);
    canvas.drawLine(Offset(rect.right, rect.bottom - 8),
        Offset(rect.right, rect.bottom - cornerLength), borderPaint);
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) {
    return oldDelegate.boxSize != boxSize ||
        oldDelegate.borderColor != borderColor;
  }
}
