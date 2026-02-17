import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

/// Botón compacto para login social (Google, Apple, etc.)
/// Muestra un ícono a la izquierda y texto pequeño.
class AppSocialButton extends StatelessWidget {
  /// Texto del botón (ej: "Continuar con Google")
  final String label;

  /// Callback al presionar el botón
  final VoidCallback? onPressed;

  /// Tipo de proveedor social: 'google' o 'apple'
  final String provider;

  /// Si es true, muestra un indicador de carga
  final bool isLoading;

  const AppSocialButton({
    Key? key,
    required this.label,
    required this.provider,
    this.onPressed,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Determina el ícono según el proveedor
    IconData icon;
    Color iconColor;
    Color borderColor;

    switch (provider.toLowerCase()) {
      case 'google':
        icon = Icons.login; // Fallback para Google en Material Icons
        iconColor = const Color(0xFFDB4437); // Rojo de Google
        borderColor = isDark ? Colors.white24 : Colors.grey[300]!;
        break;
      case 'apple':
        icon = Icons.apple; // Apple está disponible en versiones recientes
        iconColor = isDark ? Colors.white : Colors.black;
        borderColor = isDark ? Colors.white24 : Colors.grey[300]!;
        break;
      default:
        icon = Icons.login_outlined;
        iconColor = Colors.grey;
        borderColor = Colors.grey[300]!;
    }

    return OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        side: BorderSide(color: borderColor, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
      ),
      child: isLoading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: iconColor,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: iconColor,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: GoogleFonts.montserrat(
                    fontSize: AppColors.bodySmall,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
    );
  }
}
