import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocr_expense_tracker/utils/crop_calculator.dart';

void main() {
  group('CropCalculator - Pure Function Unit Tests', () {
    test('Tỉ lệ đồng dạng: Preview và Ảnh cùng tỉ lệ 1:2', () {
      const previewSize = Size(400, 800);
      const imageSize = Size(800, 1600);
      final viewfinderRect = Rect.fromLTWH(50, 100, 300, 500);

      final cropRect = CropCalculator.calculateCropRect(
        previewSize: previewSize,
        imageSize: imageSize,
        viewfinderRect: viewfinderRect,
        fit: BoxFit.cover,
      );

      // Scale = 0.5 -> pixel trên ảnh gấp 2 lần tọa độ preview
      expect(cropRect.left, 100.0);
      expect(cropRect.top, 200.0);
      expect(cropRect.width, 600.0);
      expect(cropRect.height, 1000.0);
    });

    test('BoxFit.cover với tỉ lệ khác nhau: ảnh rộng hơn preview (crop ngang)', () {
      const previewSize = Size(400, 800);
      const imageSize = Size(1200, 1600);
      // scale = max(400/1200, 800/1600) = max(0.333, 0.5) = 0.5
      // renderedWidth = 600, renderedHeight = 800, offsetX = 100, offsetY = 0
      final viewfinderRect = Rect.fromLTWH(50, 150, 300, 500);

      final cropRect = CropCalculator.calculateCropRect(
        previewSize: previewSize,
        imageSize: imageSize,
        viewfinderRect: viewfinderRect,
        fit: BoxFit.cover,
      );

      // (50 + 100) / 0.5 = 300
      expect(cropRect.left, 300.0);
      // (150 + 0) / 0.5 = 300
      expect(cropRect.top, 300.0);
      // 300 / 0.5 = 600
      expect(cropRect.width, 600.0);
      // 500 / 0.5 = 1000
      expect(cropRect.height, 1000.0);
    });

    test('BoxFit.cover với tỉ lệ khác nhau: ảnh dài hơn preview (crop dọc)', () {
      const previewSize = Size(400, 600);
      const imageSize = Size(800, 1600);
      // scale = max(400/800, 600/1600) = max(0.5, 0.375) = 0.5
      // renderedWidth = 400, renderedHeight = 800, offsetX = 0, offsetY = 100
      final viewfinderRect = Rect.fromLTWH(50, 100, 300, 400);

      final cropRect = CropCalculator.calculateCropRect(
        previewSize: previewSize,
        imageSize: imageSize,
        viewfinderRect: viewfinderRect,
        fit: BoxFit.cover,
      );

      // (50 + 0) / 0.5 = 100
      expect(cropRect.left, 100.0);
      // (100 + 100) / 0.5 = 400
      expect(cropRect.top, 400.0);
      // 300 / 0.5 = 600
      expect(cropRect.width, 600.0);
      // 400 / 0.5 = 800
      expect(cropRect.height, 800.0);
    });

    test('BoxFit.contain: tính toán chuẩn xác khi có letterbox viền trên dưới', () {
      const previewSize = Size(400, 800);
      const imageSize = Size(600, 600);
      // scale = min(400/600, 800/600) = 400/600 = 2/3
      // renderedWidth = 400, renderedHeight = 400
      // offsetX = 0, offsetY = (800 - 400) / 2 = 200
      final viewfinderRect = Rect.fromLTWH(50, 250, 300, 300);

      final cropRect = CropCalculator.calculateCropRect(
        previewSize: previewSize,
        imageSize: imageSize,
        viewfinderRect: viewfinderRect,
        fit: BoxFit.contain,
      );

      // relLeft = 50, relTop = 250 - 200 = 50
      // cropX = 50 / (2/3) = 75
      // cropY = 50 / (2/3) = 75
      // cropW = 300 / (2/3) = 450
      // cropH = 300 / (2/3) = 450
      expect(cropRect.left, closeTo(75.0, 0.01));
      expect(cropRect.top, closeTo(75.0, 0.01));
      expect(cropRect.width, closeTo(450.0, 0.01));
      expect(cropRect.height, closeTo(450.0, 0.01));
    });

    test('Clamp an toàn: khi khung ngắm tràn ra ngoài biên ảnh', () {
      const previewSize = Size(400, 800);
      const imageSize = Size(400, 800);
      // Khung ngắm bắt đầu từ -50 và rộng 500
      final viewfinderRect = Rect.fromLTWH(-50, -50, 500, 900);

      final cropRect = CropCalculator.calculateCropRect(
        previewSize: previewSize,
        imageSize: imageSize,
        viewfinderRect: viewfinderRect,
        fit: BoxFit.cover,
      );

      expect(cropRect.left, 0.0);
      expect(cropRect.top, 0.0);
      expect(cropRect.right, lessThanOrEqualTo(imageSize.width));
      expect(cropRect.bottom, lessThanOrEqualTo(imageSize.height));
    });

    test('Kích thước 0 hoặc âm trả về Rect.zero', () {
      final rect = CropCalculator.calculateCropRect(
        previewSize: Size.zero,
        imageSize: const Size(800, 600),
        viewfinderRect: const Rect.fromLTWH(0, 0, 100, 100),
      );
      expect(rect, Rect.zero);
    });

    test('toPixelBox làm tròn số thực sang số nguyên', () {
      const rect = Rect.fromLTWH(12.3, 45.7, 100.2, 200.8);
      final pixelBox = CropCalculator.toPixelBox(rect);

      expect(pixelBox.x, 12);
      expect(pixelBox.y, 46);
      expect(pixelBox.width, 100);
      expect(pixelBox.height, 201);
    });
  });
}
