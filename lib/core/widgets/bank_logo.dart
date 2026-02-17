import 'package:flutter/material.dart';

/// Widget para mostrar un avatar de banco basado en color e iniciales
/// Usado cuando no podemos cargar los logos reales por CORS
class BankLogo extends StatelessWidget {
  final String bankName;
  final String primaryColor;
  final double size;

  const BankLogo({
    Key? key,
    required this.bankName,
    required this.primaryColor,
    this.size = 40,
  }) : super(key: key);

  /// Extrae las iniciales del nombre del banco
  String _getInitials() {
    final words = bankName.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '??';
    if (words.length == 1) {
      return words[0].substring(0, words[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  /// Convierte el string de color hex a Color de Flutter
  Color _parseColor(String hexColor) {
    try {
      final hex = hexColor.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (e) {
      return Colors.blueGrey; // Color por defecto si falla el parsing
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _parseColor(primaryColor);
    final initials = _getInitials();
    
    // Calculamos si el color de fondo es claro u oscuro para el texto
    final luminance = bgColor.computeLuminance();
    final textColor = luminance > 0.5 ? Colors.black87 : Colors.white;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: bgColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: textColor,
          fontSize: size * 0.4,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
