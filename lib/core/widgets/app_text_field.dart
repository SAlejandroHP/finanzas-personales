import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

/// Campo de texto personalizado compacto para toda la aplicación.
/// Diseño minimalista con padding reducido y bordes suaves.
class AppTextField extends StatefulWidget {
  /// Texto de placeholder/label del campo
  final String label;

  /// Controlador del campo de texto
  final TextEditingController? controller;

  /// Si es true, el campo es para contraseña (oculta el texto)
  final bool isPassword;

  /// Tipo de teclado a mostrar
  final TextInputType keyboardType;

  /// Texto de ayuda/error debajo del campo
  final String? helperText;

  /// Si es true, muestra un mensaje de error
  final bool isError;

  /// Ícono opcional a la izquierda del campo
  final IconData? prefixIcon;

  /// Callback al cambiar el texto
  final Function(String)? onChanged;

  /// Callback al enviar el formulario
  final Function(String)? onSubmitted;

  /// Número máximo de líneas (1 para una sola línea)
  final int maxLines;

  /// Si el campo está habilitado
  final bool enabled;

  /// Nodo de enfoque opcional
  final FocusNode? focusNode;

  /// Validador opcional
  final String? Function(String?)? validator;

  /// Callback al guardar
  final void Function(String?)? onSaved;

  /// Texto de sugerencia dentro del campo
  final String? hintText;

  /// Error manual externo
  final String? errorText;

  /// Si debe tomar el foco automáticamente
  final bool autofocus;

  /// Ícono opcional a la derecha del campo
  final Widget? suffixIcon;

  /// Longitud máxima permitida
  final int? maxLength;

  /// Capitalización de texto
  final TextCapitalization textCapitalization;

  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.helperText,
    this.isError = false,
    this.prefixIcon,
    this.onChanged,
    this.onSubmitted,
    this.maxLines = 1,
    this.enabled = true,
    this.focusNode,
    this.validator,
    this.onSaved,
    this.hintText,
    this.errorText,
    this.autofocus = false,
    this.suffixIcon,
    this.maxLength,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _obscureText = true;
  FocusNode? _localFocusNode;

  FocusNode get _effectiveFocusNode => widget.focusNode ?? (_localFocusNode ??= FocusNode());

  @override
  void dispose() {
    _localFocusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Colores para el diseño de "píldora"
    final fillColor = isDark 
        ? Colors.white.withValues(alpha: 0.08) 
        : AppColors.primary.withValues(alpha: 0.06);
    final bubbleColor = isDark ? Colors.white : AppColors.primary;
    final iconColor = isDark ? AppColors.surfaceDark : Colors.white;

    // Helper para el icono en burbuja
    Widget? buildBubbleIcon(IconData? icon, {bool isPrefix = true, VoidCallback? onTap}) {
      if (icon == null) return null;
      return Container(
        margin: EdgeInsets.only(
          left: isPrefix ? 6 : 0, 
          right: isPrefix ? 12 : 6, 
          top: 6, 
          bottom: 6
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(
            child: Icon(icon, color: iconColor, size: 20),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.controller,
          focusNode: _effectiveFocusNode,
          autofocus: widget.autofocus,
          obscureText: widget.isPassword && _obscureText,
          keyboardType: widget.keyboardType,
          enabled: widget.enabled,
          maxLines: widget.maxLines,
          maxLength: widget.maxLength,
          textCapitalization: widget.textCapitalization,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onSubmitted,
          validator: widget.validator,
          onSaved: widget.onSaved,
          style: GoogleFonts.montserrat(
            fontSize: AppColors.bodyMedium,
            fontWeight: FontWeight.w500,
            color: widget.enabled
                ? (isDark ? Colors.white : AppColors.textPrimary)
                : Colors.grey,
          ),
          decoration: InputDecoration(
            hintText: widget.hintText ?? widget.label,
            errorText: widget.errorText,
            hintStyle: GoogleFonts.montserrat(
              fontSize: AppColors.bodyMedium,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white60 : Colors.grey[500],
            ),
            filled: true,
            fillColor: fillColor,
            isDense: true,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 20,
              vertical: widget.maxLines > 1 ? 16 : 18,
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 56, minHeight: 56),
            suffixIconConstraints: const BoxConstraints(minWidth: 56, minHeight: 56),
            prefixIcon: buildBubbleIcon(widget.prefixIcon),
            suffixIcon: widget.isPassword
                ? buildBubbleIcon(
                    _obscureText ? Icons.visibility_off : Icons.visibility,
                    isPrefix: false,
                    onTap: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                  )
                : (widget.suffixIcon != null 
                    ? Padding(
                        padding: const EdgeInsets.only(right: 16.0),
                        child: widget.suffixIcon,
                      ) 
                    : null),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(100),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(100),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(100),
              borderSide: BorderSide(
                color: widget.isError ? AppColors.error : AppColors.primary.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(100),
              borderSide: const BorderSide(
                color: AppColors.error,
                width: 1.5,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(100),
              borderSide: const BorderSide(
                color: AppColors.error,
                width: 1.5,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(100),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        if (widget.helperText != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Text(
              widget.helperText!,
              style: GoogleFonts.montserrat(
                fontSize: AppColors.bodySmall,
                color: widget.isError ? AppColors.error : Colors.grey[600],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
