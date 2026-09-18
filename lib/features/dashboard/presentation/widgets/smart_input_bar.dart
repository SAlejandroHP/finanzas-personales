import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:google_fonts/google_fonts.dart'; // Added
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/ia_service.dart';
import '../../../accounts/presentation/providers/accounts_provider.dart';
import '../../../categories/presentation/providers/categories_provider.dart';
import '../../../debts/presentation/providers/debts_provider.dart';
import '../../../transactions/presentation/widgets/transaction_form_sheet.dart';
import '../../../transactions/presentation/providers/transactions_provider.dart';
import '../../../transactions/models/transaction_model.dart';
import '../../../../core/services/finance_service.dart';
import 'package:uuid/uuid.dart';
import 'package:collection/collection.dart';
import '../../../goals/models/goal_model.dart';
import '../../../goals/presentation/widgets/goal_form_bottom_sheet.dart';
import '../../../debts/models/debt_model.dart';
import '../../../debts/presentation/widgets/debt_form_sheet.dart';
import '../../../../core/providers/ui_provider.dart';

class SmartInputBar extends ConsumerStatefulWidget {
  const SmartInputBar({super.key});

  @override
  ConsumerState<SmartInputBar> createState() => _SmartInputBarState();
}

class _SmartInputBarState extends ConsumerState<SmartInputBar> {
  final TextEditingController _controller = TextEditingController();
  IAService? _iaService;
  // Nullable para evitar LateInitializationError en Web donde STT no está soportado
  stt.SpeechToText? _speech;
  
  bool _isLoading = false;
  bool _isListening = false;
  bool _speechEnabled = false;

  @override
  void initState() {
    super.initState();
    try {
      _iaService = IAService();
    } catch (e) {
      debugPrint('[SmartInputBar] IAService no disponible: $e');
      // IAService fallará gracefully cuando se use, no en el build
    }
    // STT solo disponible en plataformas nativas (iOS/Android)
    if (!kIsWeb) {
      try {
        _speech = stt.SpeechToText();
        _initSpeech();
      } catch (e) {
        debugPrint('SpeechToText could not be instantiated: $e');
        _speech = null;
      }
    }
    // Escucha cambios en el texto para notificar al FAB sobre ocultarse
    _controller.addListener(_onTextChanged);
  }

  /// Actualiza el provider global cuando el campo de texto cambia
  void _onTextChanged() {
    final hasText = _controller.text.isNotEmpty;
    // Usa Future.microtask para evitar llamar setState durante el build
    Future.microtask(() {
      if (mounted) {
        ref.read(smartInputHasTextProvider.notifier).state = hasText;
      }
    });
  }

  Future<void> _initSpeech() async {
    final speechInstance = _speech;
    if (speechInstance == null) return;
    try {
      _speechEnabled = await speechInstance.initialize(
        onStatus: (status) {
          if (status == 'done') {
            if (_isListening) {
              if (mounted) setState(() => _isListening = false);
              if (_controller.text.trim().isNotEmpty) {
                _processInput();
              }
            }
          }
        },
        onError: (errorNotification) {
          if (mounted) {
            setState(() => _isListening = false);
            showAppToast(
              context,
              message: "Error de micrófono: ${errorNotification.errorMsg}",
              type: ToastType.warning,
            );
          }
        },
      );
      if (mounted) setState(() {});
    } catch (e) {
      _speechEnabled = false;
      if (mounted) setState(() {});
    }
  }

  void _listen() async {
    final speechInstance = _speech;
    if (speechInstance == null || kIsWeb) {
      showAppToast(
        context,
        message: "El reconocimiento de voz no está disponible aquí.",
        type: ToastType.warning,
      );
      return;
    }
    try {
      if (!_speechEnabled) {
        bool initSuccess = await speechInstance.initialize();
        if (!initSuccess) {
          if (mounted) {
            showAppToast(
              context,
              message: "Permiso de micrófono denegado o no disponible.",
              type: ToastType.error,
            );
          }
          return;
        } else {
          _speechEnabled = true;
        }
      }

      if (_isListening) {
        await speechInstance.stop();
        setState(() => _isListening = false);
        if (_controller.text.trim().isNotEmpty) {
          _processInput();
        }
      } else {
        _controller.clear();
        await speechInstance.listen(
          onResult: (result) {
            setState(() {
              _controller.text = result.recognizedWords;
            });
          },
          localeId: 'es_MX',
        );
        setState(() => _isListening = true);
      }
    } catch (e) {
      if (mounted) {
        showAppToast(
          context,
          message: "No se pudo acceder al micrófono.",
          type: ToastType.error,
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    // Limpia el estado del provider al desmontar
    Future.microtask(() {
      if (mounted) {
        ref.read(smartInputHasTextProvider.notifier).state = false;
      }
    });
    super.dispose();
  }

  Future<void> _processInput() async {
    if (_isListening) {
      await _speech?.stop();
      setState(() => _isListening = false);
    }

    final input = _controller.text.trim();
    if (input.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final accounts = ref.read(accountsWithBalanceProvider).valueOrNull ?? [];
      final categories = ref.read(categoriesListProvider).valueOrNull ?? [];
      final debts = ref.read(debtsListProvider).valueOrNull ?? [];

      final service = _iaService;
      if (service == null) {
        throw Exception('El asistente de IA no está configurado en este entorno.');
      }
      
      final draft = await service.parseTransactionIntent(
        input, 
        accounts,
        categories,
        debts,
      );

      if (draft.intent == 'transaction') {
        final accountsList = accounts;
        final defaultAccount = accountsList.firstWhereOrNull((a) => a.isDefault);
        
        String? finalAccountId = draft.cuentaOrigenId;
        bool usedDefault = false;

        if (finalAccountId == null || finalAccountId.isEmpty) {
          if (defaultAccount != null) {
            finalAccountId = defaultAccount.id;
            usedDefault = true;
          }
        }

        if (draft.monto != null && draft.monto! > 0 && finalAccountId != null) {
          final ahora = DateTime.now();
          final draftFecha = draft.fecha ?? ahora;

          // Prioriza el estado determinado por la IA (Punto 3: fechas futuras).
          // Si la IA no lo proporcionó, calcula localmente.
          final String estadoFinal;
          if (draft.estadoIA != null && draft.estadoIA!.isNotEmpty) {
            estadoFinal = draft.estadoIA!; // "completa" o "programada"
          } else {
            final hoyFin = DateTime(ahora.year, ahora.month, ahora.day, 23, 59, 59);
            estadoFinal = (draftFecha.isBefore(hoyFin) ||
                    (draftFecha.day == ahora.day &&
                     draftFecha.month == ahora.month &&
                     draftFecha.year == ahora.year))
                ? 'completa'
                : 'programada';
          }

          if (draft.tipo == 'pago_deuda' && draft.deudaId != null) {
            await ref.read(financeServiceProvider).processDebtPayment(
              debtId: draft.deudaId!,
              amount: draft.monto!,
              accountId: finalAccountId,
              description: draft.descripcion.isEmpty ? null : draft.descripcion,
              fecha: draftFecha,
            );
          } else {
            final transaction = TransactionModel(
              id: const Uuid().v4(),
              userId: '',
              tipo: draft.tipo,
              monto: draft.monto!,
              fecha: draftFecha,
              estado: estadoFinal,
              descripcion: draft.descripcion.isEmpty ? null : draft.descripcion,
              cuentaOrigenId: finalAccountId,
              cuentaDestinoId: (draft.tipo == 'transferencia' || draft.tipo == 'pago_deuda') ? draft.cuentaDestinoId : null,
              categoriaId: (draft.tipo == 'gasto' || draft.tipo == 'ingreso') ? draft.categoriaId : null,
              deudaId: draft.tipo == 'pago_deuda' ? draft.deudaId : null,
              createdAt: ahora,
              isRecurring: false,
              autoComplete: false,
              weekendAdjustment: false,
            );
            await ref.read(transactionsNotifierProvider.notifier).createTransaction(transaction);
          }

          ref.read(financeServiceProvider).refreshAll();

          if (mounted) {
            _controller.clear();
            showAppToast(
              context,
              message: 'Transacción guardada.' + (usedDefault ? ' (Cuenta por defecto)' : ''),
              type: ToastType.success,
            );
          }
        } else {
          // Modo Manual (Fallback)
          if (mounted) {
            _controller.clear();
            showTransactionFormSheet(
               context,
               draft: draft,
             );
           }
         }
       } else if (draft.intent == 'goal') {
         if (mounted) {
           _controller.clear();
           final goal = GoalModel(
             id: const Uuid().v4(),
             userId: '',
             title: draft.nombreMeta ?? '',
             targetAmount: draft.montoObjetivo ?? 0,
             currentAmount: 0,
             description: '',
              deadline: draft.fechaObjetivo,
              icon: 'savings',
              colorHex: AppColors.primaryHex, // Note: This is stored as a string, but the constant is AppColors.primary
              createdAt: DateTime.now(),
            );
           // useRootNavigator: true asegura que el sheet se renderice
           // por ENCIMA del BottomNavigationBar (Punto 17b - Fix Z-Index)
           showModalBottomSheet(
             context: context,
             useRootNavigator: true,
             isScrollControlled: true,
             backgroundColor: Colors.transparent,
             builder: (context) => GoalFormBottomSheet(goal: goal),
           );
         }
       } else if (draft.intent == 'debt') {
         if (mounted) {
           _controller.clear();
           final debt = DebtModel(
             id: const Uuid().v4(),
             userId: '',
             nombre: draft.nombreDeuda ?? '',
             tipo: 'prestamo_personal',
             montoTotal: draft.montoDeuda ?? 0,
             montoRestante: draft.montoDeuda ?? 0,
             fechaVencimiento: null,
             estado: 'activa',
             createdAt: DateTime.now(),
             isShared: false,
             ownerRole: draft.tipoDeuda == 'pasivo' ? 'borrower' : 'lender',
           );
           showDebtFormSheet(
             context,
             debt: debt,
           );
         }
       } else {
         if (mounted) {
           showAppToast(
             context,
             message: "No se pudo interpretar la entrada de forma segura.",
             type: ToastType.warning,
           );
         }
       }
     } catch (e) {
       if (mounted) {
         showAppToast(
           context,
           message: e.toString().replaceAll('Exception: ', ''),
           type: ToastType.error,
         );
       }
     } finally {
       if (mounted) {
         setState(() {
           _isLoading = false;
         });
       }
     }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final hintColor = isDark ? Colors.white38 : Colors.black38;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Botón Siri/Apple Intelligence (Micrófono)
          GestureDetector(
            onTap: _isLoading ? null : _listen,
            child: SiriOrb(
              isListening: _isListening,
              isLoading: _isLoading,
              size: 44.0,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _controller,
              onSubmitted: (_) => _processInput(),
              enabled: !_isLoading,
              style: GoogleFonts.montserrat(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: _isListening ? 'Escuchando tu gasto...' : '✨ ¿Qué registramos hoy?',
                hintStyle: GoogleFonts.montserrat(
                  color: hintColor,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          // Botón de envío estético
          GestureDetector(
            onTap: _processInput,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primary.withBlue(200)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}



class SiriOrb extends StatefulWidget {
  final bool isListening;
  final bool isLoading;
  final double size;

  const SiriOrb({
    Key? key,
    this.isListening = false,
    this.isLoading = false,
    this.size = 44.0,
  }) : super(key: key);

  @override
  State<SiriOrb> createState() => _SiriOrbState();
}

class _SiriOrbState extends State<SiriOrb> with TickerProviderStateMixin {
  late AnimationController _rotateController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _rotateController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // When listening or loading, it rotates much faster
    final double speedMultiplier = widget.isListening ? 3.0 : (widget.isLoading ? 2.0 : 1.0);
    final double pulseScale = widget.isListening ? 1.15 : (widget.isLoading ? 1.05 : 1.0);
    
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_rotateController, _pulseController]),
        builder: (context, child) {
          final pulse = 1.0 + (_pulseController.value * 0.1 * (widget.isListening ? 2 : 1));
          final targetScale = pulse * pulseScale;
          
          return Transform.scale(
            scale: targetScale,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Layer 1: Glowing base (Blurred shadow effect)
                Container(
                  width: widget.size * 0.85,
                  height: widget.size * 0.85,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF651FFF).withOpacity(0.5),
                        blurRadius: 16 * pulse,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                
                // Layer 2: Colorful Siri-like Sweep Gradient
                Transform.rotate(
                  angle: _rotateController.value * 2 * math.pi * speedMultiplier,
                  child: Container(
                    width: widget.size * 0.85,
                    height: widget.size * 0.85,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          Color(0xFFFF3D00), // Orange/Red
                          Color(0xFFD500F9), // Purple
                          Color(0xFF2979FF), // Blue
                          Color(0xFF00E5FF), // Cyan
                          Color(0xFF00E676), // Green
                          Color(0xFFFF3D00), // Back to Orange
                        ],
                        stops: [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
                      ),
                    ),
                  ),
                ),
                
                // Layer 3: Inner counter-rotating gradient to blend colors nicely (MUST be integer multiplier for seamless loop)
                Transform.rotate(
                  angle: -_rotateController.value * 2 * math.pi * (speedMultiplier * 2.0),
                  child: Container(
                    width: widget.size * 0.7,
                    height: widget.size * 0.7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          const Color(0xFF2979FF).withOpacity(0.8),
                          const Color(0xFFFF3D00).withOpacity(0.4),
                          const Color(0xFF00E5FF).withOpacity(0.8),
                          const Color(0xFFD500F9).withOpacity(0.4),
                          const Color(0xFF2979FF).withOpacity(0.8),
                        ],
                      ),
                    ),
                  ),
                ),

                // Layer 4: Soft white inner core to give it volume (like a bubble)
                Container(
                  width: widget.size * 0.5,
                  height: widget.size * 0.5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withOpacity(0.8),
                        Colors.white.withOpacity(0.0),
                      ],
                      stops: const [0.2, 1.0],
                    ),
                  ),
                ),
                
                // Layer 5: Microphone Icon so the user knows it's the voice AI button
                Icon(
                  widget.isListening ? Icons.mic : Icons.mic_none_rounded,
                  color: Colors.white.withOpacity(0.9),
                  size: widget.size * 0.5,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
