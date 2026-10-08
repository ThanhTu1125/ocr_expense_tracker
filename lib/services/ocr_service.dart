import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../utils/ocr_row_reconstructor.dart';

export '../utils/ocr_row_reconstructor.dart' show OcrLine, OcrResult, OcrRowReconstructor;

class OcrService {
  /// Xử lý nhận diện hình ảnh và trích xuất danh sách OcrLine kèm boundingBox
  Future<OcrResult> processImage(String imagePath) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);

      final List<OcrLine> ocrLines = [];
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          ocrLines.add(OcrLine(
            text: line.text,
            boundingBox: line.boundingBox,
          ));
        }
      }

      return OcrResult(
        text: recognizedText.text,
        lines: ocrLines,
      );
    } finally {
      await textRecognizer.close();
    }
  }

  /// Trích xuất chuỗi văn bản thô (giữ để tương thích ngược 100%)
  Future<String> extractText(String imagePath) async {
    final result = await processImage(imagePath);
    return result.text;
  }
}
