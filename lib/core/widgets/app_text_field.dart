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
    final fillColor = isDark ? const Color(0xFF2C2C2C) : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.controller,
          focusNode: _effectiveFocusNode,
          obscureText: widget.isPassword && _obscureText,
          keyboardType: widget.keyboardType,
          enabled: widget.enabled,
          maxLines: widget.maxLines,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onSubmitted,
          validator: widget.validator,
          onSaved: widget.onSaved,
          style: GoogleFonts.montserrat(
            fontSize: 14,
            color: widget.enabled
                ? (isDark ? Colors.white : AppColors.textPrimary)
                : Colors.grey,
          ),
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hintText,
            errorText: widget.errorText,
            labelStyle: GoogleFonts.montserrat(
              fontSize: 14,
              color: widget.isError
                  ? AppColors.accent
                  : (isDark ? Colors.white70 : Colors.grey[600]),
            ),
            hintStyle: GoogleFonts.montserrat(
              fontSize: 14,
              color: isDark ? Colors.white54 : Colors.grey[400],
            ),
            floatingLabelStyle: GoogleFonts.montserrat(
              fontSize: 12,
              color: widget.isError ? AppColors.accent : AppColors.primary,
            ),
            filled: true,
            fillColor: fillColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            prefixIcon: widget.prefixIcon != null
                ? Icon(
                    widget.prefixIcon,
                    color: widget.isError
                        ? AppColors.accent
                        : (isDark ? Colors.white70 : AppColors.primary),
                    size: 20,
                  )
                : null,
            suffixIcon: widget.isPassword
                ? IconButton(
                    icon: Icon(
                      _obscureText ? Icons.visibility_off : Icons.visibility,
                      color: isDark ? Colors.white70 : Colors.grey[600],
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: widget.isError ? AppColors.accent : AppColors.primary,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.accent,
                width: 2,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.accent,
                width: 2,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        if (widget.helperText != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(
              widget.helperText!,
              style: GoogleFonts.montserrat(
                fontSize: 12,
                color: widget.isError ? AppColors.accent : Colors.grey[600],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
