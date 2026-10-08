import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Lớp tiện ích thuần túy (pure functions) để tính toán vùng crop ảnh
/// từ tọa độ khung ngắm trên màn hình CameraPreview sang tọa độ pixel ảnh gốc.
class CropCalculator {
  /// Quy đổi tọa độ khung ngắm [viewfinderRect] trên widget preview [previewSize]
  /// thành tọa độ vùng cần crop [Rect] trên pixel của ảnh thật [imageSize].
  ///
  /// - [previewSize]: Kích thước vùng hiển thị CameraPreview trên màn hình.
  /// - [imageSize]: Kích thước thật (width x height) của ảnh sau khi bakeOrientation.
  /// - [viewfinderRect]: Hình chữ nhật khung ngắm (cutout) trên màn hình.
  /// - [fit]: Quy cách co giãn ảnh trong preview (mặc định BoxFit.cover).
  static Rect calculateCropRect({
    required Size previewSize,
    required Size imageSize,
    required Rect viewfinderRect,
    BoxFit fit = BoxFit.cover,
  }) {
    if (previewSize.width <= 0 ||
        previewSize.height <= 0 ||
        imageSize.width <= 0 ||
        imageSize.height <= 0) {
      return Rect.zero;
    }

    final double scale;
    final double renderedWidth;
    final double renderedHeight;
    final double offsetX;
    final double offsetY;

    if (fit == BoxFit.contain) {
      scale = math.min(
        previewSize.width / imageSize.width,
        previewSize.height / imageSize.height,
      );
      renderedWidth = imageSize.width * scale;
      renderedHeight = imageSize.height * scale;
      // Vị trí biên bắt đầu của ảnh trong khung preview
      offsetX = (previewSize.width - renderedWidth) / 2.0;
      offsetY = (previewSize.height - renderedHeight) / 2.0;

      final relLeft = viewfinderRect.left - offsetX;
      final relTop = viewfinderRect.top - offsetY;

      final cropX = (relLeft / scale).clamp(0.0, imageSize.width);
      final cropY = (relTop / scale).clamp(0.0, imageSize.height);
      final cropW = (viewfinderRect.width / scale)
          .clamp(0.0, imageSize.width - cropX);
      final cropH = (viewfinderRect.height / scale)
          .clamp(0.0, imageSize.height - cropY);

      return Rect.fromLTWH(cropX, cropY, cropW, cropH);
    } else {
      // Mặc định: BoxFit.cover (ảnh phủ kín preview, có thể tràn mép)
      scale = math.max(
        previewSize.width / imageSize.width,
        previewSize.height / imageSize.height,
      );
      renderedWidth = imageSize.width * scale;
      renderedHeight = imageSize.height * scale;
      // Độ tràn ra ngoài preview được căn giữa
      offsetX = (renderedWidth - previewSize.width) / 2.0;
      offsetY = (renderedHeight - previewSize.height) / 2.0;

      final renderedLeft = viewfinderRect.left + offsetX;
      final renderedTop = viewfinderRect.top + offsetY;

      final cropX = (renderedLeft / scale).clamp(0.0, imageSize.width);
      final cropY = (renderedTop / scale).clamp(0.0, imageSize.height);
      final cropW = (viewfinderRect.width / scale)
          .clamp(0.0, imageSize.width - cropX);
      final cropH = (viewfinderRect.height / scale)
          .clamp(0.0, imageSize.height - cropY);

      return Rect.fromLTWH(cropX, cropY, cropW, cropH);
    }
  }

  /// Chuyển đổi [Rect] sang tuple pixel nguyên (x, y, width, height) để truyền vào image.copyCrop
  static ({int x, int y, int width, int height}) toPixelBox(Rect rect) {
    final x = rect.left.round();
    final y = rect.top.round();
    final width = rect.width.round();
    final height = rect.height.round();
    return (x: x, y: y, width: width, height: height);
  }
}
