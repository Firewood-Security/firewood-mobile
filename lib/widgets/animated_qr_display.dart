import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../theme/app_theme.dart';

/// A custom animated QR Code widget built using CustomPainter and QrPainter.
/// It dynamically draws the actual QR code matrix blocks using animated orange and gray tiles!
class AnimatedQrDisplay extends StatefulWidget {
  final String qrData;
  final double size;

  const AnimatedQrDisplay({
    super.key,
    required this.qrData,
    this.size = 230,
  });

  @override
  State<AnimatedQrDisplay> createState() => _AnimatedQrDisplayState();
}

class _AnimatedQrDisplayState extends State<AnimatedQrDisplay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  QrCode? _qrCode;
  bool _isBuildingQr = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _generateQrMatrix();
  }

  void _generateQrMatrix() {
    try {
      final qr = QrCode.fromData(
        data: widget.qrData,
        errorCorrectLevel: QrErrorCorrectLevel.M,
      );
      _qrCode = qr;
      _isBuildingQr = false;
      _controller.forward(from: 0.0);
    } catch (_) {
      setState(() => _isBuildingQr = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _replayAnimation() {
    _controller.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    if (_isBuildingQr || _qrCode == null) {
      return SizedBox(
        width: widget.size + 28,
        height: widget.size + 28,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _replayAnimation,
          child: Container(
            width: widget.size + 28,
            height: widget.size + 28,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0E0E12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.orangeAccent.withValues(alpha: 0.7),
                width: 1.8,
              ),
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  size: Size(widget.size, widget.size),
                  painter: _QrMatrixPainter(
                    qrCode: _qrCode!,
                    progress: _controller.value,
                    orangeColor: AppColors.orangeAccent,
                    grayColor: const Color(0xFF383845),
                    lightGrayColor: const Color(0xFF8E8E9F),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _QrMatrixPainter extends CustomPainter {
  final QrCode qrCode;
  final double progress;
  final Color orangeColor;
  final Color grayColor;
  final Color lightGrayColor;

  _QrMatrixPainter({
    required this.qrCode,
    required this.progress,
    required this.orangeColor,
    required this.grayColor,
    required this.lightGrayColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final qrImage = QrImage(qrCode);
    final moduleCount = qrCode.moduleCount;
    final tileSize = size.width / moduleCount;

    final orangePaint = Paint()..color = orangeColor;
    final grayPaint = Paint()..color = grayColor;
    final lightGrayPaint = Paint()..color = lightGrayColor;
    final darkBgPaint = Paint()..color = const Color(0xFF09090C);

    // Draw background
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(12),
      ),
      darkBgPaint,
    );

    for (int r = 0; r < moduleCount; r++) {
      for (int c = 0; c < moduleCount; c++) {
        final isDark = qrImage.isDark(r, c);

        // Check if this module is part of the 3 Corner Eye position patterns (7x7 squares)
        final isTopLeftEye = (r < 7 && c < 7);
        final isTopRightEye = (r < 7 && c >= moduleCount - 7);
        final isBottomLeftEye = (r >= moduleCount - 7 && c < 7);
        final isEyePattern = isTopLeftEye || isTopRightEye || isBottomLeftEye;

        // Diagonal reveal animation index
        final diagonalIndex = (r + c) / ((moduleCount * 2) - 2);

        // Stagger module appearance based on animation progress
        final moduleProgress =
            ((progress - (diagonalIndex * 0.65)) / 0.35).clamp(0.0, 1.0);

        if (moduleProgress <= 0.0) continue; // Not revealed yet

        final x = c * tileSize;
        final y = r * tileSize;
        final moduleRect = Rect.fromLTWH(
          x + (tileSize * (1 - moduleProgress) * 0.5),
          y + (tileSize * (1 - moduleProgress) * 0.5),
          tileSize * moduleProgress,
          tileSize * moduleProgress,
        );

        if (isEyePattern) {
          // Corner eyes draw in vibrant DEEP ORANGE!
          if (isDark) {
            canvas.drawRect(moduleRect, orangePaint);
          } else {
            canvas.drawRect(moduleRect, grayPaint);
          }
        } else if (isDark) {
          // Data modules draw in DEEP ORANGE & LIGHT GRAY (No black & white!)
          // Alternate block colors to form an orange and gray matrix grid
          final isOrangeBlock = (r + c) % 3 == 0 || (r * c) % 5 == 0;
          canvas.drawRect(
              moduleRect, isOrangeBlock ? orangePaint : lightGrayPaint);
        } else {
          // Empty modules draw subtle dark gray grid squares during creation phase
          if (progress < 0.9) {
            final alphaVal = (1.0 - progress) * 0.4;
            final dimGray = Paint()
              ..color = grayColor.withValues(alpha: alphaVal);
            canvas.drawRect(moduleRect, dimGray);
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrMatrixPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.qrCode != qrCode;
  }
}

/// Renders [data] as a static, fully-scannable QR code and returns PNG bytes.
///
/// Used by "Save QR": the exported image is a standard black-on-white code
/// with a proper quiet zone (maximally reliable when re-scanned later from a
/// gallery or another screen), unlike the animated on-screen version which is
/// mid-reveal part of the time and uses the brand palette.
Future<Uint8List> buildQrPngBytes(
  String data, {
  double imageSize = 1024,
  double quietZone = 72,
}) async {
  final qr = QrCode.fromData(
    data: data,
    errorCorrectLevel: QrErrorCorrectLevel.M,
  );
  final painter = QrPainter.withQr(qr: qr);

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  // Opaque white background — transparent PNGs confuse some scanners.
  canvas.drawRect(
    Rect.fromLTWH(0, 0, imageSize, imageSize),
    Paint()..color = const Color(0xFFFFFFFF),
  );
  // Quiet zone: scanners need a blank margin around the code.
  canvas.translate(quietZone, quietZone);
  painter.paint(
    canvas,
    Size(imageSize - quietZone * 2, imageSize - quietZone * 2),
  );

  final picture = recorder.endRecording();
  final image = await picture.toImage(imageSize.toInt(), imageSize.toInt());
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  if (byteData == null) {
    throw StateError('Failed to render the QR code image');
  }
  return byteData.buffer.asUint8List();
}
