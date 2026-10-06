import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'review_transaction_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  static const routeName = '/scanner';

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  bool _isFlashOn = false;
  bool _isCapturing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _errorMessage = 'No camera found on this device.';
          });
        }
        return;
      }

      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await controller.initialize();

      if (mounted) {
        setState(() {
          _controller = controller;
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Camera initialization failed: $e';
        });
      }
    }
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      final newMode = _isFlashOn ? FlashMode.off : FlashMode.torch;
      await _controller!.setFlashMode(newMode);
      if (mounted) {
        setState(() {
          _isFlashOn = !_isFlashOn;
        });
      }
    } catch (e) {
      debugPrint('Error toggling flash: $e');
    }
  }

  Future<void> _takePicture() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isCapturing) {
      return;
    }

    setState(() {
      _isCapturing = true;
    });

    try {
      final XFile file = await _controller!.takePicture();
      if (mounted) {
        Navigator.pushNamed(
          context,
          ReviewTransactionScreen.routeName,
          arguments: file.path,
        );
      }
    } catch (e) {
      debugPrint('Error capturing photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to capture photo: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scanner'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off),
            tooltip: 'Flash',
            onPressed: _isCameraInitialized ? _toggleFlash : null,
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;

            final cutoutWidth = width * 0.82;
            final cutoutHeight = height * 0.62;
            final cutoutLeft = (width - cutoutWidth) / 2;
            final cutoutTop = (height - cutoutHeight) / 2 - 40;
            final cutoutRect = Rect.fromLTWH(
              cutoutLeft,
              cutoutTop,
              cutoutWidth,
              cutoutHeight,
            );

            return Stack(
              fit: StackFit.expand,
              children: [
                // 1. Bottom layer: CameraPreview or Loading / Error
                if (_isCameraInitialized && _controller != null)
                  Center(
                    child: CameraPreview(_controller!),
                  )
                else if (_errorMessage != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),

                // 2. Middle layer: Viewfinder Overlay
                if (_isCameraInitialized)
                  CustomPaint(
                    painter: _ViewfinderPainter(
                      cutoutRect: cutoutRect,
                      borderColor: Theme.of(context).colorScheme.primary,
                    ),
                  ),

                // Hint text above or below viewfinder
                if (_isCameraInitialized)
                  Positioned(
                    top: cutoutTop - 36,
                    left: 0,
                    right: 0,
                    child: const Text(
                      'Căn chỉnh hóa đơn vào khung ngắm',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        shadows: [
                          Shadow(color: Colors.black, blurRadius: 4),
                        ],
                      ),
                    ),
                  ),

                // 3. Top layer (Controls): Shutter button
                Positioned(
                  bottom: 24,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Secondary control / placeholder
                      const SizedBox(width: 56),

                      // Big Shutter Button
                      GestureDetector(
                        onTap: (_isCameraInitialized && !_isCapturing)
                            ? _takePicture
                            : null,
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 4,
                            ),
                            color: _isCapturing
                                ? Colors.grey
                                : Colors.white.withValues(alpha: 0.2),
                          ),
                          child: Center(
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _isCapturing
                                    ? Colors.grey
                                    : Colors.white,
                              ),
                              child: _isCapturing
                                  ? const CircularProgressIndicator(
                                      strokeWidth: 3,
                                      color: Colors.black,
                                    )
                                  : const Icon(
                                      Icons.camera_alt,
                                      color: Colors.black87,
                                      size: 32,
                                    ),
                            ),
                          ),
                        ),
                      ),

                      // Flash toggle shortcut
                      IconButton(
                        icon: Icon(
                          _isFlashOn ? Icons.flash_on : Icons.flash_off,
                          color: _isFlashOn ? Colors.amber : Colors.white,
                          size: 28,
                        ),
                        onPressed: _isCameraInitialized ? _toggleFlash : null,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ViewfinderPainter extends CustomPainter {
  final Rect cutoutRect;
  final Color borderColor;

  const _ViewfinderPainter({
    required this.cutoutRect,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;

    // Cutout with rounded corners
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(
        RRect.fromRectAndRadius(cutoutRect, const Radius.circular(16)),
      )
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, backgroundPaint);

    // Prominent border around cutout
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    canvas.drawRRect(
      RRect.fromRectAndRadius(cutoutRect, const Radius.circular(16)),
      borderPaint,
    );

    // Corner accents
    final accentPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    const cornerLength = 24.0;
    final r = cutoutRect;

    // Top-Left
    canvas.drawLine(Offset(r.left, r.top + cornerLength), Offset(r.left, r.top), accentPaint);
    canvas.drawLine(Offset(r.left, r.top), Offset(r.left + cornerLength, r.top), accentPaint);

    // Top-Right
    canvas.drawLine(Offset(r.right - cornerLength, r.top), Offset(r.right, r.top), accentPaint);
    canvas.drawLine(Offset(r.right, r.top), Offset(r.right, r.top + cornerLength), accentPaint);

    // Bottom-Left
    canvas.drawLine(Offset(r.left, r.bottom - cornerLength), Offset(r.left, r.bottom), accentPaint);
    canvas.drawLine(Offset(r.left, r.bottom), Offset(r.left + cornerLength, r.bottom), accentPaint);

    // Bottom-Right
    canvas.drawLine(Offset(r.right - cornerLength, r.bottom), Offset(r.right, r.bottom), accentPaint);
    canvas.drawLine(Offset(r.right, r.bottom), Offset(r.right, r.bottom - cornerLength), accentPaint);
  }

  @override
  bool shouldRepaint(covariant _ViewfinderPainter oldDelegate) {
    return cutoutRect != oldDelegate.cutoutRect ||
        borderColor != oldDelegate.borderColor;
  }
}
