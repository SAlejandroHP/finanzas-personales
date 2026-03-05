
import 'package:flutter/material.dart';

class CardScannerScreen extends StatelessWidget {
  const CardScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escáner no disponible')),
      body: const Center(
        child: Text('El escaneo de tarjetas no está disponible en la versión web.'),
      ),
    );
  }
}
