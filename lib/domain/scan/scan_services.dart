import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../agent/gemini_model.dart';
import '../agent/verdict_schema.dart';
import 'scan.dart';

/// ML Kit on-device OCR (Latin script). Free and offline.
class MlKitOcr implements TextOcr {
  @override
  Future<String> read(String imagePath) async {
    final recognizer = TextRecognizer();
    try {
      final result = await recognizer.processImage(
        InputImage.fromFilePath(imagePath),
      );
      return result.text;
    } finally {
      await recognizer.close();
    }
  }
}

/// Gemini reads the photo and the OCR text together: the image gives
/// layout (what is a heading, which date is the deadline), the OCR text
/// keeps spellings exact.
class GeminiNoticeReader implements NoticeReader {
  GeminiNoticeReader({GenerativeModel? model})
    : _model =
          model ??
          FirebaseAI.googleAI().generativeModel(
            model: GeminiModel.defaultModel,
            generationConfig: GenerationConfig(
              responseMimeType: 'application/json',
              responseSchema: scannedNoticeSchema,
              temperature: 0.1,
            ),
          );

  final GenerativeModel _model;

  static const prompt = '''
This is a photo of a printed public tender notice, plus the text OCR read
from it. Extract the fields. Use only what is printed; leave a field empty
if it is not there. The deadline is the bid submission deadline, not the
publication date.

OCR TEXT:
''';

  @override
  Future<ScannedNotice> read({
    required Uint8List image,
    required String mimeType,
    required String ocrText,
  }) async {
    final res = await _model
        .generateContent([
          Content.multi([
            TextPart('$prompt$ocrText'),
            InlineDataPart(mimeType, image),
          ]),
        ])
        .timeout(const Duration(seconds: 30));
    final decoded = jsonDecode(res.text ?? '{}');
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('AI response is not a JSON object');
    }
    return ScannedNotice.fromJson(decoded);
  }
}
