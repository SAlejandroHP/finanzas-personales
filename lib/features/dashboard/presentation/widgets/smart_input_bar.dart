import 'package:flutter/material.dart';
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
  late final IAService _iaService;
  late final stt.SpeechToText _speech;
  
  bool _isLoading = false;
  bool _isListening = false;
  bool _speechEnabled = false;

  @override
  void initState() {
    super.initState();
    _iaService = IAService();
    _speech = stt.SpeechToText();
    _initSpeech();
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
    try {
      _speechEnabled = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done') {
            if (_isListening) {
              setState(() => _isListening = false);
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
    if (!_speechEnabled) {
      bool initSuccess = await _speech.initialize();
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
      await _speech.stop();
      setState(() => _isListening = false);
      if (_controller.text.trim().isNotEmpty) {
        _processInput();
      }
    } else {
      _controller.clear();
      await _speech.listen(
        onResult: (result) {
          setState(() {
            _controller.text = result.recognizedWords;
          });
        },
        localeId: 'es_MX',
      );
      setState(() => _isListening = true);
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
      await _speech.stop();
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
      
      final draft = await _iaService.parseTransactionIntent(
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
    final backgroundColor = isDark ? AppColors.surfaceDark : Colors.black.withOpacity(0.05);
    final textColor = isDark ? AppColors.textSecondary : AppColors.textPrimary;
    final hintColor = isDark ? AppColors.textSecondary.withOpacity(0.5) : AppColors.textPrimary.withOpacity(0.5);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(AppColors.radiusCircular),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Botón de Micrófono transformado
            GestureDetector(
              onTap: _isLoading ? null : _listen,
              child: Container(
                width: AppColors.xl + AppColors.sm, // ~40-44 normalized
                height: AppColors.xl + AppColors.sm,
                decoration: BoxDecoration(
                  color: _isListening ? AppColors.error : AppColors.primaryDark,
                  shape: BoxShape.circle,
                ),
                child: _isLoading && _isListening == false
                    ? const Padding(
                        padding: EdgeInsets.all(AppColors.sm),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        color: Colors.white,
                        size: AppColors.iconMedium,
                      ),
              ),
            ),
            const SizedBox(width: AppColors.md),
            Expanded(
              child: TextField(
                controller: _controller,
                onSubmitted: (_) => _processInput(),
                enabled: !_isLoading,
                style: GoogleFonts.montserrat(
                  color: textColor,
                  fontWeight: FontWeight.w500,
                  fontSize: AppColors.bodyMedium,
                ),
                decoration: InputDecoration(
                  hintText: _isListening ? 'Escuchando...' : '¿Qué registramos hoy?',
                  hintStyle: GoogleFonts.montserrat(
                    color: hintColor,
                    fontSize: AppColors.bodyMedium,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                ),
              ),
            ),
            // Botón de envío (Varita mágica)
            IconButton(
              onPressed: _processInput,
              icon: const Icon(Icons.auto_awesome),
              color: AppColors.primary,
              iconSize: AppColors.iconLarge,
              tooltip: 'Procesar',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: AppColors.sm),
          ],
        ),
      ),
    );
  }
}
