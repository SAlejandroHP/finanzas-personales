import 'package:flutter/material.dart';
import '../widgets/app_toast.dart' as widgets;

/// Muestra un toast moderno con estilo personalizado.
/// Redirige al nuevo sistema de toasts en lib/core/widgets/app_toast.dart
/// para mantener consistencia visual en toda la app.
/// 
/// [message]: Texto a mostrar en el toast
/// [isError]: Si es true, muestra estilo de error, si es false, success
void showAppToast(BuildContext context, String message, {bool isError = false}) {
  widgets.showAppToast(
    context,
    message: message,
    type: isError ? widgets.ToastType.error : widgets.ToastType.success,
  );
}
