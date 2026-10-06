import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  Future<String> extractText(String imagePath) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);
      return recognizedText.text;
    } finally {
      await textRecognizer.close();
    }
  }
}
