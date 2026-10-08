import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../services/image_crop_service.dart';
import 'review_transaction_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  static const routeName = '/scanner';

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  bool _isFlashOn = false;
  bool _isCapturing = false;
  String? _errorMessage;

  // Tap-to-focus
  Offset? _focusPoint;
  late final AnimationController _focusAnimController;

  @override
  void initState() {
    super.initState();
    _focusAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _focusAnimController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() {
          _focusPoint = null;
        });
      }
    });

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

  Future<void> _onTapToFocus(TapUpDetails details, Size previewSize) async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    final tapPos = details.localPosition;
    setState(() {
      _focusPoint = tapPos;
    });
    _focusAnimController.forward(from: 0.0);

    // Quy đổi tọa độ về Offset(0..1)
    final dx = (tapPos.dx / previewSize.width).clamp(0.0, 1.0);
    final dy = (tapPos.dy / previewSize.height).clamp(0.0, 1.0);

    try {
      await _controller!.setFocusPoint(Offset(dx, dy));
      await _controller!.setExposurePoint(Offset(dx, dy));
    } catch (e) {
      // Một số thiết bị hoặc giả lập không hỗ trợ điểm lấy nét/đo sáng
      debugPrint('Tap-to-focus/exposure not supported on this device: $e');
    }
  }

  Future<void> _takePicture(Rect cutoutRect, Size previewSize) async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isCapturing) {
      return;
    }

    setState(() {
      _isCapturing = true;
    });

    try {
      final XFile originalFile = await _controller!.takePicture();

      // Ở chế độ debug, lưu thêm ảnh GỐC trước crop vào thư mục tạm để so sánh với ảnh sau crop
      final tempDir = await getTemporaryDirectory();
      String? debugOriginalPath;
      if (kDebugMode) {
        final copyPath =
            '${tempDir.path}/debug_original_before_crop_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await File(originalFile.path).copy(copyPath);
        debugOriginalPath = copyPath;
        debugPrint('===============================================================');
        debugPrint('[DEBUG MODE] ĐÃ LƯU ẢNH GỐC TRƯỚC CROP VÀO THƯ MỤC TẠM:');
        debugPrint('ĐƯỜNG DẪN ẢNH GỐC: $debugOriginalPath');
        debugPrint('===============================================================');
      }

      // Cắt ảnh thật theo khung ngắm chạy trong Isolate để không giật UI
      final croppedPath =
          '${tempDir.path}/cropped_receipt_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final params = CropImageParams(
        sourcePath: originalFile.path,
        destinationPath: croppedPath,
        previewWidth: previewSize.width,
        previewHeight: previewSize.height,
        viewfinderLeft: cutoutRect.left,
        viewfinderTop: cutoutRect.top,
        viewfinderWidth: cutoutRect.width,
        viewfinderHeight: cutoutRect.height,
        fitMode: 'cover',
      );

      final resultImagePath =
          await ImageCropService.cropImageToViewfinder(params);

      // Xóa file ảnh thô ban đầu để tiết kiệm dung lượng
      try {
        final rawFile = File(originalFile.path);
        if (await rawFile.exists()) {
          await rawFile.delete();
        }
      } catch (_) {}

      if (mounted) {
        Navigator.pushNamed(
          context,
          ReviewTransactionScreen.routeName,
          arguments: {
            'imagePath': resultImagePath,
            'debugOriginalPath': debugOriginalPath,
          },
        );
      }
    } catch (e) {
      debugPrint('Error capturing or cropping photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chụp hoặc cắt ảnh thất bại: $e')),
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
    _focusAnimController.dispose();
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
            final previewSize = Size(width, height);

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
                // 1. Bottom layer: CameraPreview với Tap-To-Focus
                if (_isCameraInitialized && _controller != null)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) =>
                        _onTapToFocus(details, previewSize),
                    child: Center(
                      child: CameraPreview(_controller!),
                    ),
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
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _ViewfinderPainter(
                        cutoutRect: cutoutRect,
                        borderColor: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),

                // Vòng tròn Animation Tap-To-Focus (~1 giây)
                if (_focusPoint != null)
                  Positioned(
                    left: _focusPoint!.dx - 32,
                    top: _focusPoint!.dy - 32,
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _focusAnimController,
                        builder: (context, child) {
                          final scale =
                              1.2 - (0.4 * _focusAnimController.value);
                          final opacity =
                              (1.0 - _focusAnimController.value).clamp(0.0, 1.0);
                          return Opacity(
                            opacity: opacity,
                            child: Transform.scale(
                              scale: scale,
                              child: Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.amberAccent,
                                    width: 2.0,
                                  ),
                                ),
                                child: Center(
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.amberAccent,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                // Hint text
                if (_isCameraInitialized)
                  Positioned(
                    top: cutoutTop - 36,
                    left: 0,
                    right: 0,
                    child: const IgnorePointer(
                      child: Text(
                        'Chạm để lấy nét • Căn chỉnh hóa đơn vào khung',
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
                  ),

                // 3. Top layer (Controls): Shutter button
                Positioned(
                  bottom: 24,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      const SizedBox(width: 56),

                      // Big Shutter Button
                      GestureDetector(
                        onTap: (_isCameraInitialized && !_isCapturing)
                            ? () => _takePicture(cutoutRect, previewSize)
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
                        onPressed:
                            _isCameraInitialized ? _toggleFlash : null,
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
    canvas.drawLine(
        Offset(r.left, r.top + cornerLength), Offset(r.left, r.top), accentPaint);
    canvas.drawLine(
        Offset(r.left, r.top), Offset(r.left + cornerLength, r.top), accentPaint);

    // Top-Right
    canvas.drawLine(
        Offset(r.right - cornerLength, r.top), Offset(r.right, r.top), accentPaint);
    canvas.drawLine(
        Offset(r.right, r.top), Offset(r.right, r.top + cornerLength), accentPaint);

    // Bottom-Left
    canvas.drawLine(Offset(r.left, r.bottom - cornerLength),
        Offset(r.left, r.bottom), accentPaint);
    canvas.drawLine(Offset(r.left, r.bottom),
        Offset(r.left + cornerLength, r.bottom), accentPaint);

    // Bottom-Right
    canvas.drawLine(Offset(r.right - cornerLength, r.bottom),
        Offset(r.right, r.bottom), accentPaint);
    canvas.drawLine(Offset(r.right, r.bottom),
        Offset(r.right, r.bottom - cornerLength), accentPaint);
  }

  @override
  bool shouldRepaint(covariant _ViewfinderPainter oldDelegate) {
    return cutoutRect != oldDelegate.cutoutRect ||
        borderColor != oldDelegate.borderColor;
  }
}
