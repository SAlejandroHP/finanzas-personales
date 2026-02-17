import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Widget indicador de carga personalizado para la aplicación.
/// Muestra un indicador de progreso circular con el color primario de la app.

class LoadingIndicator extends StatelessWidget {
  /// Color del indicador de carga
  final Color? color;

  /// Tamaño del indicador
  final double size;

  /// Mensaje opcional a mostrar debajo del indicador
  final String? message;

  /// Si es true, muestra el indicador en el centro de la pantalla
  final bool fullScreen;

  const LoadingIndicator({
    Key? key,
    this.color,
    this.size = AppColors.iconLarge,
    this.message,
    this.fullScreen = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final widget = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(
              color ?? AppColors.primary,
            ),
          ),
        ),
        if (message != null) ...[
          SizedBox(height: AppColors.md),
          Text(
            message!,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );

    if (fullScreen) {
      return Center(child: widget);
    }

    return widget;
  }
}
