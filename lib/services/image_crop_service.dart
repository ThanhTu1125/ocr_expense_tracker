import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../utils/crop_calculator.dart';

class CropImageParams {
  final String sourcePath;
  final String destinationPath;
  final double previewWidth;
  final double previewHeight;
  final double viewfinderLeft;
  final double viewfinderTop;
  final double viewfinderWidth;
  final double viewfinderHeight;
  final String fitMode;

  const CropImageParams({
    required this.sourcePath,
    required this.destinationPath,
    required this.previewWidth,
    required this.previewHeight,
    required this.viewfinderLeft,
    required this.viewfinderTop,
    required this.viewfinderWidth,
    required this.viewfinderHeight,
    this.fitMode = 'cover',
  });
}

class ImageCropService {
  /// Cắt ảnh theo khung ngắm chạy trong isolate độc lập thông qua `compute()`
  /// để tránh làm gián đoạn UI thread.
  static Future<String> cropImageToViewfinder(CropImageParams params) async {
    return await compute(_processCropTask, params);
  }

  /// Hàm thuần xử lý logic giải mã, xoay EXIF và crop ảnh trong Isolate
  static String _processCropTask(CropImageParams params) {
    final file = File(params.sourcePath);
    if (!file.existsSync()) {
      throw FileSystemException('Source image does not exist', params.sourcePath);
    }

    final bytes = file.readAsBytesSync();
    var image = img.decodeImage(bytes);
    if (image == null) {
      throw Exception('Không thể giải mã hình ảnh từ: ${params.sourcePath}');
    }

    // 1. bakeOrientation để đồng bộ hóa góc xoay EXIF thành pixel thật
    image = img.bakeOrientation(image);

    final imageSize = Size(image.width.toDouble(), image.height.toDouble());
    final previewSize = Size(params.previewWidth, params.previewHeight);
    final viewfinderRect = Rect.fromLTWH(
      params.viewfinderLeft,
      params.viewfinderTop,
      params.viewfinderWidth,
      params.viewfinderHeight,
    );

    // 2. Tính toán tọa độ crop theo đúng tỉ lệ hiển thị của CameraPreview
    final cropRect = CropCalculator.calculateCropRect(
      previewSize: previewSize,
      imageSize: imageSize,
      viewfinderRect: viewfinderRect,
      fit: params.fitMode == 'contain' ? BoxFit.contain : BoxFit.cover,
    );

    final box = CropCalculator.toPixelBox(cropRect);

    // Đảm bảo biên hợp lệ trong không gian ảnh
    final x = box.x.clamp(0, image.width - 1);
    final y = box.y.clamp(0, image.height - 1);
    final w = box.width.clamp(1, image.width - x);
    final h = box.height.clamp(1, image.height - y);

    // 3. Thực hiện crop thật bằng image package
    final croppedImage = img.copyCrop(
      image,
      x: x,
      y: y,
      width: w,
      height: h,
    );

    // 4. Lưu ra file mới
    final jpgBytes = img.encodeJpg(croppedImage, quality: 92);
    final destFile = File(params.destinationPath);
    destFile.writeAsBytesSync(jpgBytes);

    return destFile.path;
  }
}
