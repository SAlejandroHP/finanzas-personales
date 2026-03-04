import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
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
  }

  Future<void> _initSpeech() async {
    try {
      _speechEnabled = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done') {
            if (_isListening) {
              setState(() => _isListening = false);
              // Cuando se detiene automáticamente por silencio, si hay texto, lo procesamos.
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
    _controller.dispose();
    super.dispose();
  }

  Future<void> _processInput() async {
    // Si estaba escuchando, detener
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
          
          final hoyFin = DateTime(ahora.year, ahora.month, ahora.day, 23, 59, 59);
          final estadoFinal = draftFecha.isBefore(hoyFin) ||
                (draftFecha.day == ahora.day &&
                 draftFecha.month == ahora.month &&
                 draftFecha.year == ahora.year)
              ? 'completa'
              : 'pendiente';

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
            
            final snackBar = SnackBar(
              content: Text('✅ Transacción guardada.' + (usedDefault ? ' Se usó tu cuenta por defecto.' : '')),
              action: SnackBarAction(
                label: 'Editar',
                textColor: Colors.white,
                onPressed: () {
                  showTransactionFormSheet(
                    context,
                    draft: draft,
                  );
                },
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 4),
            );
            ScaffoldMessenger.of(context).showSnackBar(snackBar);
          }
        } else {
          // Modo Manual (Fallback) si falta monto o no hay cuenta
          if (mounted) {
            _controller.clear();
            showTransactionFormSheet(
               context,
               draft: draft,
             );
           }
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
             child: AppTextField(
               label: '',
               hintText: _isListening ? 'Escuchando...' : 'Ej. Gasté \$500 en súper hoy o Aboné \$500 a Ismael',
               controller: _controller,
               onSubmitted: (_) => _processInput(),
               enabled: !_isLoading,
             ),
           ),
           const SizedBox(width: 8),
           IconButton(
             onPressed: _isLoading ? null : _listen,
             icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
             color: _isListening ? AppColors.error : AppColors.primary,
             iconSize: 28,
             tooltip: _isListening ? 'Detener dictado' : 'Dictar transacción',
           ),
           _isLoading
               ? const Padding(
                   padding: EdgeInsets.all(12.0),
                   child: SizedBox(
                     width: 24,
                     height: 24,
                     child: CircularProgressIndicator(
                       strokeWidth: 2,
                     ),
                   ),
                 )
               : IconButton(
                   onPressed: _processInput,
                   icon: const Icon(Icons.auto_awesome),
                   color: AppColors.primary,
                   iconSize: 28,
                   tooltip: 'Procesar con IA',
                 ),
         ],
       ),
    );
  }
}
