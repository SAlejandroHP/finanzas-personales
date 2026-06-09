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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: GoogleFonts.montserrat(
            fontSize: AppColors.bodySmall,
            fontWeight: FontWeight.w600,
            color: widget.isError 
                ? AppColors.error 
                : (isDark ? Colors.white70 : Colors.grey[700]),
          ),
        ),
        const SizedBox(height: 4),
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
            color: widget.enabled
                ? (isDark ? Colors.white : AppColors.textPrimary)
                : Colors.grey,
          ),
          decoration: InputDecoration(
            hintText: widget.hintText ?? widget.label,
            errorText: widget.errorText,
            hintStyle: GoogleFonts.montserrat(
              fontSize: AppColors.bodyMedium,
              color: isDark ? Colors.white30 : Colors.grey[400],
            ),
            filled: false,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 0,
              vertical: 12,
            ),
            prefixIcon: widget.prefixIcon != null
                ? Icon(
                    widget.prefixIcon,
                    color: widget.isError
                        ? AppColors.error
                        : Colors.grey,
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
                : widget.suffixIcon,
            border: UnderlineInputBorder(
              borderSide: BorderSide(
                color: isDark ? Colors.white24 : Colors.grey[300]!,
                width: 1,
              ),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: isDark ? Colors.white24 : Colors.grey[300]!,
                width: 1,
              ),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: widget.isError ? AppColors.error : AppColors.primary,
                width: 2,
              ),
            ),
            errorBorder: const UnderlineInputBorder(
              borderSide: BorderSide(
                color: AppColors.error,
                width: 2,
              ),
            ),
            focusedErrorBorder: const UnderlineInputBorder(
              borderSide: BorderSide(
                color: AppColors.error,
                width: 2,
              ),
            ),
            disabledBorder: const UnderlineInputBorder(
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
                fontSize: AppColors.bodySmall,
                color: widget.isError ? AppColors.secondary : Colors.grey[600],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
