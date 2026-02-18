import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Botón personalizado reutilizable para toda la aplicación.
/// Soporta diferentes variantes (primary, secondary, outlined) y estados.

class AppButton extends StatelessWidget {
  /// Texto del botón
  final String label;

  /// Callback al presionar el botón
  final VoidCallback? onPressed;

  /// Color de fondo del botón
  final Color? backgroundColor;

  /// Color del texto del botón
  final Color? textColor;

  /// Ícono opcional que se muestra a la izquierda del texto
  final IconData? icon;

  /// Si es true, el botón ocupa todo el ancho disponible
  final bool isFullWidth;

  /// Si es true, el botón muestra un estado deshabilitado
  final bool isLoading;

  /// Variante del botón: 'primary', 'secondary', 'outlined'
  final String variant;

  /// Tamaño del botón: 'small', 'medium', 'large'
  final String size;

  /// Altura personalizada del botón (sobrescribe el tamaño)
  final double? height;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.backgroundColor,
    this.textColor,
    this.icon,
    this.isFullWidth = false,
    this.isLoading = false,
    this.variant = 'primary',
    this.size = 'medium',
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    // Determina los colores según la variante
    late Color bgColor;
    late Color textColorFinal;

    switch (variant) {
      case 'primary':
        bgColor = backgroundColor ?? AppColors.primary;
        textColorFinal = textColor ?? AppColors.textSecondary;
        break;
      case 'secondary':
        bgColor = backgroundColor ?? AppColors.secondary;
        textColorFinal = textColor ?? AppColors.textSecondary;
        break;
      case 'outlined':
        bgColor = Colors.transparent;
        textColorFinal = textColor ?? AppColors.primary;
        break;
      default:
        bgColor = AppColors.primary;
        textColorFinal = AppColors.textSecondary;
    }

    // Determina el tamaño
    late double padding;
    late double fontSize;
    late double buttonHeight;

    switch (size) {
      case 'small':
        padding = AppColors.sm;
        fontSize = 12;
        buttonHeight = AppColors.buttonHeightSmall;
        break;
      case 'large':
        padding = AppColors.lg;
        fontSize = 16;
        buttonHeight = AppColors.buttonHeight + 8;
        break;
      case 'medium':
      default:
        padding = AppColors.md;
        fontSize = 14;
        buttonHeight = AppColors.buttonHeight;
    }

    // Usa altura personalizada si se proporciona
    if (height != null) {
      buttonHeight = height!;
    }

    final buttonChild = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(textColorFinal),
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: textColorFinal, size: AppColors.iconMedium),
                SizedBox(width: AppColors.sm),
              ],
              Text(
                label,
                style: TextStyle(
                  color: textColorFinal,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );

    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        borderRadius: BorderRadius.circular(AppColors.radiusMedium),
        child: Container(
          height: buttonHeight,
          padding: EdgeInsets.symmetric(horizontal: padding),
          decoration: BoxDecoration(
            color: isLoading ? bgColor.withValues(alpha: 0.6) : bgColor,
            border: variant == 'outlined'
                ? Border.all(color: textColorFinal, width: 2)
                : null,
            borderRadius: BorderRadius.circular(AppColors.radiusMedium),
          ),
          child: Center(child: buttonChild),
        ),
      ),
    );

    if (isFullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }

    return button;
  }
}
