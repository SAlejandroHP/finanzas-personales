import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

/// Enum para los tipos de toast disponibles
enum ToastType { success, error, warning, info }

/// Muestra un toast elegante y moderno que no interrumpe visualmente.
/// 
/// Utiliza un Overlay para posicionarse en la parte superior sin depender
/// del ScaffoldMessenger, lo que permite un diseño más limpio y controlado.
void showAppToast(
  BuildContext context, {
  required String message,
  required ToastType type,
  Duration duration = const Duration(seconds: 3),
}) {
  final overlay = Overlay.of(context);
  
  late OverlayEntry overlayEntry;
  
  overlayEntry = OverlayEntry(
    builder: (context) => _ToastWidget(
      message: message,
      type: type,
      duration: duration,
      onDismiss: () {
        overlayEntry.remove();
      },
    ),
  );

  overlay.insert(overlayEntry);
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final ToastType type;
  final Duration duration;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.message,
    required this.type,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _controller.forward();

    _timer = Timer(widget.duration, () {
      if (mounted) {
        _controller.reverse().then((value) => widget.onDismiss());
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = _getToastConfig(widget.type);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: SlideTransition(
            position: _offsetAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark 
                          ? const Color(0xFF2C2C2E) // Gris oscuro elegante
                          : Colors.white,            // Blanco sólido
                      borderRadius: BorderRadius.circular(AppColors.radiusCircular),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.5 : 0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Dismissible(
                      key: UniqueKey(),
                      direction: DismissDirection.up,
                      onDismissed: (_) => widget.onDismiss(),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: config.color.withOpacity(0.25),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              config.icon,
                              color: config.color,
                              size: AppColors.iconXSmall,
                            ),
                          ),
                          const SizedBox(width: AppColors.contentGap),
                          Flexible(
                            child: Text(
                              widget.message,
                              style: GoogleFonts.montserrat(
                                fontSize: AppColors.bodySmall,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToastConfig {
  final Color color;
  final IconData icon;

  _ToastConfig({required this.color, required this.icon});
}

_ToastConfig _getToastConfig(ToastType type) {
  switch (type) {
    case ToastType.success:
      return _ToastConfig(
        color: AppColors.primary, // Teal
        icon: Icons.check_rounded,
      );
    case ToastType.error:
      return _ToastConfig(
        color: AppColors.secondary, // Coral
        icon: Icons.close_rounded,
      );
    case ToastType.warning:
      return _ToastConfig(
        color: AppColors.tertiary, // Gold
        icon: Icons.report_problem_rounded,
      );
    case ToastType.info:
      return _ToastConfig(
        color: const Color(0xFF3B82F6), // Azul informativo
        icon: Icons.info_outline_rounded,
      );
  }
}
