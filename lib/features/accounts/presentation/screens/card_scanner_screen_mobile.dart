import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/toast_utils.dart';

class CardScannerScreen extends StatefulWidget {
  const CardScannerScreen({super.key});

  @override
  State<CardScannerScreen> createState() => _CardScannerScreenState();
}

class _CardScannerScreenState extends State<CardScannerScreen> {
  CameraController? _cameraController;
  late TextRecognizer _textRecognizer;
  bool _isInitialized = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          showAppToast(context, 'No hay cámaras disponibles', isError: true);
        }
        return;
      }

      // Intentar usar la cámara trasera
      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error inicializando cámara: $e');
      if (mounted) {
        showAppToast(context, 'Error al acceder a la cámara', isError: true);
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _scanCard() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final image = await _cameraController!.takePicture();
      final inputImage = InputImage.fromFilePath(image.path);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      String text = recognizedText.text;

      // Regex para buscar el patrón de tarjeta: grupos de 4 a 16 dígitos
      final regex = RegExp(r'\b(?:\d[ -]*?){13,16}\b');
      final match = regex.firstMatch(text);

      if (match != null) {
        String cardNumber = match.group(0) ?? '';
        // Limpiamos los caracteres no numéricos
        cardNumber = cardNumber.replaceAll(RegExp(r'[^0-9]'), '');

        if (cardNumber.length >= 4) {
          final lastFour = cardNumber.substring(cardNumber.length - 4);
          if (mounted) {
            Navigator.pop(context, lastFour);
          }
          return;
        }
      }
      
      // Si no encuentra los números
      if (mounted) {
        showAppToast(context, 'No se pudo detectar el número. Intenta de nuevo.', isError: true);
      }
      
    } catch (e) {
      debugPrint('Error procesando imagen: $e');
      if (mounted) {
        showAppToast(context, 'Error al procesar la imagen.', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _cameraController == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Vista previa de la cámara
          CameraPreview(_cameraController!),

          // Overlay guía (rectángulo y áreas oscurecidas)
          CustomPaint(
            painter: _CardOverlayPainter(),
          ),

          // Botón de regresar y Título
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Row(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),

          // Instrucción superior
          Positioned(
            top: MediaQuery.of(context).padding.top + 80,
            left: 0,
            right: 0,
            child: const Center(
              child: Text(
                'Escanea tu tarjeta',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      offset: Offset(0, 1),
                      blurRadius: 4.0,
                      color: Colors.black87,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Instrucción inferior
          const Positioned(
            bottom: 130,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Centra la tarjeta en el recuadro\npara leer los últimos 4 dígitos.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  shadows: [
                    Shadow(
                      offset: Offset(0, 1),
                      blurRadius: 4.0,
                      color: Colors.black87,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isProcessing ? null : _scanCard,
        backgroundColor: AppColors.primary,
        icon: _isProcessing 
          ? const SizedBox(
              width: 24, 
              height: 24, 
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
            ) 
          : const Icon(Icons.camera_alt, color: Colors.white),
        label: Text(
          _isProcessing ? 'Procesando...' : 'Escanear Tarjeta',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class _CardOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Fondo semitransparente oscuro
    final backgroundPaint = Paint()..color = Colors.black54;

    // Proporción estándar de tarjeta (aprox. 85.6mm x 53.98mm)
    final cardWidth = size.width * 0.85;
    final cardHeight = cardWidth * 0.63; // 53.98 / 85.6

    final center = Offset(size.width / 2, size.height / 2);
    final cardRect = Rect.fromCenter(
      center: center,
      width: cardWidth,
      height: cardHeight,
    );
    final cardRRect = RRect.fromRectAndRadius(cardRect, const Radius.circular(16));

    // Recortar agujero transparente
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRRect(cardRRect),
      ),
      backgroundPaint,
    );

    // Borde guía central con color primario
    final borderPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRRect(cardRRect, borderPaint);
    
    // Esquinas más gruesas para simular estilo de escáner
    const cornerLength = 30.0;
    final cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
      
    // Arriba Izquierda
    canvas.drawPath(
      Path()
        ..moveTo(cardRect.left, cardRect.top + cornerLength)
        ..lineTo(cardRect.left, cardRect.top + 16)
        ..quadraticBezierTo(cardRect.left, cardRect.top, cardRect.left + 16, cardRect.top)
        ..lineTo(cardRect.left + cornerLength, cardRect.top),
      cornerPaint,
    );
    // Arriba Derecha
    canvas.drawPath(
      Path()
        ..moveTo(cardRect.right - cornerLength, cardRect.top)
        ..lineTo(cardRect.right - 16, cardRect.top)
        ..quadraticBezierTo(cardRect.right, cardRect.top, cardRect.right, cardRect.top + 16)
        ..lineTo(cardRect.right, cardRect.top + cornerLength),
      cornerPaint,
    );
    // Abajo Izquierda
    canvas.drawPath(
      Path()
        ..moveTo(cardRect.left, cardRect.bottom - cornerLength)
        ..lineTo(cardRect.left, cardRect.bottom - 16)
        ..quadraticBezierTo(cardRect.left, cardRect.bottom, cardRect.left + 16, cardRect.bottom)
        ..lineTo(cardRect.left + cornerLength, cardRect.bottom),
      cornerPaint,
    );
    // Abajo Derecha
    canvas.drawPath(
      Path()
        ..moveTo(cardRect.right - cornerLength, cardRect.bottom)
        ..lineTo(cardRect.right - 16, cardRect.bottom)
        ..quadraticBezierTo(cardRect.right, cardRect.bottom, cardRect.right, cardRect.bottom - 16)
        ..lineTo(cardRect.right, cardRect.bottom - cornerLength),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
