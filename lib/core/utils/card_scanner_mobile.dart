import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Utilidad para escanear tarjetas y extraer información mediante OCR local.
/// Utiliza google_mlkit_text_recognition para privacidad y velocidad on-device.
class CardScannerUtil {
  static final ImagePicker _picker = ImagePicker();
  static final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Abre la cámara, toma una foto y extrae los últimos 4 dígitos.
  /// Retorna los 4 dígitos encontrados o null si no detecta nada válido.
  static Future<String?> scanLastFourDigits() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1280,
        maxHeight: 720,
        imageQuality: 85,
      );

      if (image == null) return null;

      final inputImage = InputImage.fromFilePath(image.path);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

      String fullText = recognizedText.text;
      
      // Regex explicada:
      // (?<=\d{12})\d{4} -> Busca 4 dígitos que estén precedidos por exactamente 12 dígitos (Formato 16 dígitos)
      // |                 -> O
      // \d{4}$             -> 4 dígitos al final de una línea (asumiendo que los últimos son los que importan)
      // [0-9]{4}          -> Simplemente cualquier grupo de 4 dígitos si los anteriores fallan
      
      // Intentamos encontrar grupos de 4 dígitos que parezcan el final de una tarjeta
      final regExp = RegExp(r'\b\d{4}\b');
      final matches = regExp.allMatches(fullText);

      if (matches.isNotEmpty) {
        // Normalmente el último grupo de 4 dígitos en una tarjeta es el que buscamos
        return matches.last.group(0);
      }

      return null;
    } catch (e) {
      print('Error en CardScanner: $e');
      return null;
    }
  }

  /// Cierra los recursos del reconocedor.
  static void dispose() {
    _textRecognizer.close();
  }
}
