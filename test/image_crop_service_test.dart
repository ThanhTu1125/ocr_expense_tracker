import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:ocr_expense_tracker/services/image_crop_service.dart';

void main() {
  group('ImageCropService Tests', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('crop_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('cropImageToViewfinder cắt ảnh thật bằng compute/isolate và lưu file mới', () async {
      // 1. Tạo một ảnh gốc 400x800 pixel
      final original = img.Image(width: 400, height: 800);
      // Vẽ một số pixel để phân biệt
      img.fill(original, color: img.ColorRgb8(255, 0, 0));

      final originalPath = '${tempDir.path}/original.jpg';
      final croppedPath = '${tempDir.path}/cropped.jpg';

      File(originalPath).writeAsBytesSync(img.encodeJpg(original));
      expect(File(originalPath).existsSync(), isTrue);

      // Giả sử preview trên màn hình là 400x800 (tỉ lệ 1:1 với ảnh)
      // Khung ngắm ở giữa: left 50, top 100, width 300, height 500
      final params = CropImageParams(
        sourcePath: originalPath,
        destinationPath: croppedPath,
        previewWidth: 400,
        previewHeight: 800,
        viewfinderLeft: 50,
        viewfinderTop: 100,
        viewfinderWidth: 300,
        viewfinderHeight: 500,
      );

      final resultPath = await ImageCropService.cropImageToViewfinder(params);

      expect(resultPath, croppedPath);
      expect(File(croppedPath).existsSync(), isTrue);

      // Đọc lại file đã crop để xác thực kích thước
      final croppedBytes = File(croppedPath).readAsBytesSync();
      final decodedCropped = img.decodeImage(croppedBytes);

      expect(decodedCropped, isNotNull);
      expect(decodedCropped!.width, 300);
      expect(decodedCropped.height, 500);
    });
  });
}
