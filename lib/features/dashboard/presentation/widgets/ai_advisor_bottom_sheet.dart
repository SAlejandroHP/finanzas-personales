import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/groq_service.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:collection/collection.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';

import '../../../../core/services/multi_agent_advisor_service.dart';
import '../../../../core/services/finance_service.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../accounts/presentation/providers/accounts_provider.dart';
import '../../../categories/presentation/providers/categories_provider.dart';
import '../../../debts/presentation/providers/debts_provider.dart';
import '../../../goals/presentation/providers/goals_provider.dart';
import '../../../transactions/presentation/providers/transactions_provider.dart';
import '../../../transactions/presentation/screens/recurring_transactions_screen.dart';
import '../../../transactions/models/transaction_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'package:uuid/uuid.dart';
import '../../../accounts/models/account_model.dart';
import '../../../accounts/presentation/providers/currencies_provider.dart';
/// Acción que puede ejecutar el Asesor IA
class AdvisorAction {
  final String type; // 'pay_debt' | 'contribute_goal' | 'create_goal' | 'navigate'
  final String label;
  final Map<String, String> params;

  AdvisorAction({
    required this.type,
    required this.label,
    required this.params,
  });
}

/// Mensaje individual en el chat del Asesor
class AdvisorMessage {
  final String text;
  final bool isUser;
  final bool isSystem;
  final DateTime timestamp;
  final List<AdvisorAction> actions;
  final String? imagePath;

  AdvisorMessage({
    required this.text,
    required this.isUser,
    this.isSystem = false,
    required this.timestamp,
    this.actions = const [],
    this.imagePath,
  });
}

/// Hoja modal inferior del Asesor Financiero IA para Libertad Financiera
class AIAdvisorBottomSheet extends ConsumerStatefulWidget {
  final String? initialQuery;
  final String? initialImagePath;

  const AIAdvisorBottomSheet({
    super.key,
    this.initialQuery,
    this.initialImagePath,
  });

  @override
  ConsumerState<AIAdvisorBottomSheet> createState() => _AIAdvisorBottomSheetState();
}

class _AIAdvisorBottomSheetState extends ConsumerState<AIAdvisorBottomSheet> {
  final List<AdvisorMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  late final stt.SpeechToText _speech;
  String _iaThinkingStatus = 'Pensando...';
  
  ChatSession? _chatSession;
  bool _isLoading = true;
  bool _isListening = false;
  bool _speechEnabled = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initSpeech();
    
    // Inicializar chat en el siguiente frame después de tener el contexto cargado
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAdvisorChat();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      _speechEnabled = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' && _isListening) {
            setState(() => _isListening = false);
            if (_textController.text.trim().isNotEmpty) {
              _onSendMessage();
            }
          }
        },
        onError: (err) {
          setState(() => _isListening = false);
        },
      );
    } catch (_) {
      _speechEnabled = false;
    }
  }

  void _toggleListening() async {
    if (!_speechEnabled) {
      bool initSuccess = await _speech.initialize();
      if (!initSuccess) {
        if (mounted) {
          showAppToast(context, message: 'Permiso de micrófono no disponible.', type: ToastType.warning);
        }
        return;
      }
      _speechEnabled = true;
    }

    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      if (_textController.text.trim().isNotEmpty) {
        _onSendMessage();
      }
    } else {
      _textController.clear();
      await _speech.listen(
        onResult: (result) {
          setState(() {
            _textController.text = result.recognizedWords;
          });
        },
        localeId: 'es_MX',
      );
      setState(() => _isListening = true);
    }
  }

  /// Construye el contexto financiero actual del usuario
  String _buildClientContext() {
    final userAsync = ref.read(currentUserProvider);
    final accounts = ref.read(accountsWithBalanceProvider).valueOrNull ?? [];
    final debts = ref.read(debtsListProvider).valueOrNull ?? [];
    final goals = ref.read(goalsListProvider).valueOrNull ?? [];
    final transactions = ref.read(transactionsListProvider).valueOrNull ?? [];
    final recurring = ref.read(recurringTransactionsProvider).valueOrNull ?? [];
    
    // Totales
    final totalBalance = ref.read(totalBalanceProvider);
    final realAvailable = ref.read(realAvailableBalanceProvider);
    final totalDebts = ref.read(totalDebtsProvider);
    final monthlyIncome = ref.read(monthlyIncomeProvider);
    final monthlyExpenses = ref.read(monthlyExpensesProvider);

    String? userName;
    final user = userAsync.valueOrNull;
    if (user != null) {
      userName = user.userMetadata?['full_name'] ?? 
                 user.userMetadata?['name'] ?? 
                 user.email?.split('@')[0];
    }
    if (userName != null && userName.isNotEmpty) {
      userName = userName[0].toUpperCase() + userName.substring(1);
    }

    final accountsStr = accounts.map((a) => "- ${a.nombre}: \$${NumberFormat.decimalPattern().format(a.saldoActual)} (Tipo: ${a.tipo}, ID: ${a.id})").join('\n');
    final debtsStr = debts.map((d) => "- ${d.nombre}: \$${NumberFormat.decimalPattern().format(d.montoRestante)} restantes de \$${NumberFormat.decimalPattern().format(d.montoTotal)} (Estado: ${d.estado}, Rol: ${d.ownerRole}, ID: ${d.id})").join('\n');
    final goalsStr = goals.map((g) => "- ${g.title}: \$${NumberFormat.decimalPattern().format(g.currentAmount)} de \$${NumberFormat.decimalPattern().format(g.targetAmount)} (Fecha meta: ${g.deadline != null ? DateFormat('yyyy-MM-dd').format(g.deadline!) : 'Sin límite'}, ID: ${g.id})").join('\n');
    
    String getFrequencyLabel(String? rule) {
      if (rule == null) return 'Recurrente';
      if (rule.startsWith('monthly_day_')) {
        final day = rule.split('_').last;
        return 'Mensual (día $day)';
      }
      switch (rule) {
        case 'quincenal': return 'Quincenal (15 y último)';
        case 'monthly_last_day': return 'Último día del mes';
        case 'biweekly': return 'Cada 2 semanas';
        case 'weekly': return 'Cada semana';
        default: return rule;
      }
    }

    final recurringStr = recurring.map((r) {
      final status = r.isActive ? 'Activa' : 'Pausada';
      final nextOcc = r.nextOccurrence != null ? DateFormat('yyyy-MM-dd').format(r.nextOccurrence!) : 'Desconocida';
      return "- ${r.descripcion ?? 'Sin descripción'}: \$${NumberFormat.decimalPattern().format(r.monto)} (Frecuencia: ${getFrequencyLabel(r.recurringRule)}, Próxima: $nextOcc, Estado: $status, ID de Regla: ${r.id})";
    }).join('\n');

    final now = DateTime.now();
    final fortnightEnd = now.add(const Duration(days: 15));
    final currentDateStr = DateFormat('yyyy-MM-dd (EEEE)', 'es').format(now);
    final fortnightEndStr = DateFormat('yyyy-MM-dd (EEEE)', 'es').format(fortnightEnd);

    final recentTxs = transactions.take(10).toList();
    final transactionsStr = recentTxs.map((t) {
      final desc = t.descripcion ?? 'Sin descripción';
      return "- ${DateFormat('yyyy-MM-dd').format(t.fecha)}: ${t.tipo.toUpperCase()} de \$${NumberFormat.decimalPattern().format(t.monto)} - $desc";
    }).join('\n');

    return '''
INFORMACIÓN FINANCIERA REAL DEL USUARIO (${userName ?? 'el usuario'}):
- Fecha de hoy: $currentDateStr
- Próxima Quincena: Desde $currentDateStr hasta $fortnightEndStr
- Balance Total de Cuentas: \$${totalBalance.toStringAsFixed(2)}
- Disponible Real (Balance - Deudas Activas): \$${realAvailable.toStringAsFixed(2)}
- Total de Deudas Pasivas (Lo que el usuario debe): \$${totalDebts.toStringAsFixed(2)}
- Ingresos de este mes: \$${monthlyIncome.toStringAsFixed(2)}
- Gastos de este mes: \$${monthlyExpenses.toStringAsFixed(2)}

CUENTAS BANCARIAS Y SALDOS:
${accountsStr.isEmpty ? 'No hay cuentas registradas.' : accountsStr}

DEUDAS ACTIVAS:
${debtsStr.isEmpty ? 'No hay deudas registradas.' : debtsStr}

METAS DE AHORRO:
${goalsStr.isEmpty ? 'No hay metas de ahorro registradas.' : goalsStr}

REGLAS DE GASTOS Y SERVICIOS RECURRENTES (Plantillas):
${recurringStr.isEmpty ? 'No hay gastos/servicios recurrentes configurados.' : recurringStr}

TRANSACCIONES RECIENTES (Últimos 10 movimientos):
${transactionsStr.isEmpty ? 'No hay transacciones recientes.' : transactionsStr}
''';
  }

  /// Inicializa la sesión de chat con Gemini
  void _initializeAdvisorChat() {
    try {
      final multiAgentService = ref.read(multiAgentAdvisorServiceProvider);
      _chatSession = multiAgentService.startSupervisorChat();
      setState(() {
        _isLoading = false;
        
        // Agregar mensaje de bienvenida
        _messages.add(AdvisorMessage(
          text: '¡Hola! Soy tu Asesor de Libertad Financiera. He analizado tu situación financiera actual con tus cuentas, deudas y metas. 🚀\n\n¿Por dónde te gustaría empezar? Puedo ayudarte a armar una estrategia de deudas, optimizar tus gastos o estructurar tus metas de ahorro.',
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });

      // Si hay una imagen inicial, procesarla primero; si no, la consulta inicial de búsqueda
      if (widget.initialImagePath != null && widget.initialImagePath!.trim().isNotEmpty) {
        _sendImageMessage(widget.initialImagePath!.trim());
      } else if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
        _sendUserMessage(widget.initialQuery!.trim());
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _messages.add(AdvisorMessage(
          text: 'Lo siento, ocurrió un error al inicializar el Asesor IA: $e',
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
    }
  }

  /// Envía un mensaje en el chat
  Future<void> _sendUserMessage(String text) async {
    if (_chatSession == null) return;

    setState(() {
      _messages.add(AdvisorMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true; // Mostrar indicador de IA pensando
      _iaThinkingStatus = 'Preparando agentes especialistas...';
    });

    _scrollToBottom();

    try {
      final multiAgentService = ref.read(multiAgentAdvisorServiceProvider);
      final contextStr = _buildClientContext();

      final response = await multiAgentService.processInteraction(
        supervisorChat: _chatSession!,
        userQuery: text,
        clientContext: contextStr,
        onStatusChanged: (status) {
          if (mounted) {
            setState(() {
              _iaThinkingStatus = status;
            });
          }
        },
      );
      final responseText = response.text;
      if (responseText.isNotEmpty) {
        final actions = _parseActions(responseText);
        final cleanedText = _cleanText(responseText);

        setState(() {
          _messages.add(AdvisorMessage(
            text: cleanedText,
            isUser: false,
            timestamp: DateTime.now(),
            actions: actions,
          ));
        });
      } else {
        setState(() {
          _messages.add(AdvisorMessage(
            text: 'El asesor no devolvió ninguna respuesta. Intenta de nuevo.',
            isUser: false,
            timestamp: DateTime.now(),
          ));
        });
      }
    } catch (e) {
      setState(() {
        _messages.add(AdvisorMessage(
          text: 'Error al obtener respuesta del Asesor: $e',
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  /// Envía una captura de pantalla al chat para que sea analizada
  Future<void> _sendImageMessage(String imagePath) async {
    if (_chatSession == null) return;

    setState(() {
      _messages.add(AdvisorMessage(
        text: 'Analizando esta captura...',
        isUser: true,
        timestamp: DateTime.now(),
        imagePath: imagePath,
      ));
      _isLoading = true;
      _iaThinkingStatus = 'Leyendo la imagen...';
    });

    _scrollToBottom();

    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        throw Exception('El archivo de imagen no existe.');
      }
      final bytes = await file.readAsBytes();
      
      String mimeType = 'image/jpeg';
      if (imagePath.toLowerCase().endsWith('.png')) {
        mimeType = 'image/png';
      } else if (imagePath.toLowerCase().endsWith('.heic')) {
        mimeType = 'image/heic';
      } else if (imagePath.toLowerCase().endsWith('.webp')) {
        mimeType = 'image/webp';
      }

      final dataPart = DataPart(mimeType, bytes);
      final multiAgentService = ref.read(multiAgentAdvisorServiceProvider);
      final contextStr = _buildClientContext();

      final response = await multiAgentService.processInteraction(
        supervisorChat: _chatSession!,
        userQuery: 'Por favor analiza esta captura de pantalla de un gasto, transferencia o recibo de compra. Identifica el comercio/concepto, el monto, la fecha y propón una acción interactiva tipo create_transaction para registrarlo en mi cuenta.',
        clientContext: contextStr,
        userParts: [
          dataPart,
          TextPart('Analiza esta imagen para registrar el gasto o transferencia.'),
        ],
        onStatusChanged: (status) {
          if (mounted) {
            setState(() {
              _iaThinkingStatus = status;
            });
          }
        },
      );

      final responseText = response.text;
      if (responseText.isNotEmpty) {
        final actions = _parseActions(responseText);
        final cleanedText = _cleanText(responseText);

        setState(() {
          _messages.add(AdvisorMessage(
            text: cleanedText,
            isUser: false,
            timestamp: DateTime.now(),
            actions: actions,
          ));
        });
      } else {
        setState(() {
          _messages.add(AdvisorMessage(
            text: 'El asesor no devolvió ninguna respuesta. Intenta de nuevo.',
            isUser: false,
            timestamp: DateTime.now(),
          ));
        });
      }
    } catch (e) {
      setState(() {
        _messages.add(AdvisorMessage(
          text: 'Error al obtener respuesta del Asesor: $e',
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _onSendMessage() {
    final query = _textController.text.trim();
    if (query.isEmpty) return;
    _textController.clear();
    _sendUserMessage(query);
  }

  /// Permite elegir y enviar una imagen desde la cámara o galería
  Future<void> _pickAndSendImage() async {
    try {
      final picker = ImagePicker();
      final source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.surfaceDark : Colors.white,
          title: Text(
            'Seleccionar Captura',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          content: Text(
            'Elige la fuente de la imagen de tu recibo, ticket o transferencia.',
            style: GoogleFonts.montserrat(
              fontSize: 14,
              color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppColors.textPrimary,
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.pop(context, ImageSource.camera),
              icon: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
              label: Text(
                'Cámara',
                style: GoogleFonts.montserrat(color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
            ),
            TextButton.icon(
              onPressed: () => Navigator.pop(context, ImageSource.gallery),
              icon: const Icon(Icons.image_outlined, color: AppColors.primary),
              label: Text(
                'Galería',
                style: GoogleFonts.montserrat(color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );

      if (source == null) return;

      final file = await picker.pickImage(source: source);
      if (file != null) {
        await _sendImageMessage(file.path);
      }
    } catch (e) {
      if (mounted) {
        showAppToast(context, message: 'Error al seleccionar imagen: $e', type: ToastType.error);
      }
    }
  }

  /// Desplazar el listview al fondo
  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Parsea las etiquetas XML de acciones
  List<AdvisorAction> _parseActions(String text) {
    final List<AdvisorAction> actions = [];
    final regex = RegExp(r'<action\s+([^>]+)\s*/>');
    final matches = regex.allMatches(text);
    
    for (final match in matches) {
      final attributesStr = match.group(1) ?? '';
      final Map<String, String> attrs = {};
      
      // Busca atributos llave="valor"
      final attrRegex = RegExp(r'(\w+)="([^"]*)"|(\w+)=\x27([^\x27]*)\x27');
      final attrMatches = attrRegex.allMatches(attributesStr);
      for (final am in attrMatches) {
        final key = am.group(1) ?? am.group(3);
        final value = am.group(2) ?? am.group(4);
        if (key != null && value != null) {
          attrs[key] = value;
        }
      }
      
      if (attrs.containsKey('type')) {
        actions.add(AdvisorAction(
          type: attrs['type']!,
          label: attrs['label'] ?? 'Ejecutar acción',
          params: attrs,
        ));
      }
    }
    return actions;
  }

  /// Limpia las etiquetas <action> del texto visible del usuario
  String _cleanText(String text) {
    return text.replaceAll(RegExp(r'<action\s+([^>]+)\s*/>'), '').trim();
  }

  /// Ejecuta una acción sugerida por el Asesor IA
  Future<void> _executeAction(AdvisorAction action) async {
    final financeService = ref.read(financeServiceProvider);
    
    setState(() {
      _isLoading = true;
    });

    try {
      if (action.type == 'pay_debt') {
        final debtId = action.params['debt_id'];
        final amountStr = action.params['amount'];
        
        if (debtId == null || amountStr == null) {
          throw Exception('Faltan parámetros debt_id o amount');
        }
        
        final amount = double.tryParse(amountStr) ?? 0.0;
        if (amount <= 0) throw Exception('Monto inválido para el pago');

        // Buscar una cuenta para debitar (preferir default, o la primera)
        final accounts = ref.read(accountsWithBalanceProvider).valueOrNull ?? [];
        final defaultAccount = accounts.firstWhereOrNull((a) => a.isDefault) ?? accounts.firstOrNull;
        
        if (defaultAccount == null) {
          throw Exception('No tienes ninguna cuenta registrada para procesar el pago.');
        }

        await financeService.processDebtPayment(
          debtId: debtId,
          amount: amount,
          accountId: defaultAccount.id,
          description: 'Abono sugerido por Asesor IA',
        );

        if (mounted) {
          showAppToast(
            context,
            message: 'Pago de \$${NumberFormat.decimalPattern().format(amount)} registrado con éxito desde ${defaultAccount.nombre}.',
            type: ToastType.success,
          );
        }

        setState(() {
          _messages.add(AdvisorMessage(
            text: '¡Listo! He registrado el pago de \$${NumberFormat.decimalPattern().format(amount)} a la deuda desde tu cuenta ${defaultAccount.nombre}. El balance general se ha actualizado en tiempo real. 💳💸',
            isUser: false,
            isSystem: true,
            timestamp: DateTime.now(),
          ));
        });

      } else if (action.type == 'contribute_goal') {
        final goalId = action.params['goal_id'];
        final amountStr = action.params['amount'];

        if (goalId == null || amountStr == null) {
          throw Exception('Faltan parámetros goal_id o amount');
        }

        final amount = double.tryParse(amountStr) ?? 0.0;
        if (amount <= 0) throw Exception('Monto inválido para el ahorro');

        final accounts = ref.read(accountsWithBalanceProvider).valueOrNull ?? [];
        final defaultAccount = accounts.firstWhereOrNull((a) => a.isDefault) ?? accounts.firstOrNull;

        if (defaultAccount == null) {
          throw Exception('No tienes ninguna cuenta registrada para procesar el abono.');
        }

        await financeService.processGoalContribution(
          goalId: goalId,
          amount: amount,
          accountId: defaultAccount.id,
          description: 'Aporte sugerido por Asesor IA',
        );

        if (mounted) {
          showAppToast(
            context,
            message: 'Aporte de \$${NumberFormat.decimalPattern().format(amount)} registrado con éxito a tu meta.',
            type: ToastType.success,
          );
        }

        setState(() {
          _messages.add(AdvisorMessage(
            text: '¡Meta actualizada! Se añadieron \$${NumberFormat.decimalPattern().format(amount)} a tu meta de ahorro desde tu cuenta ${defaultAccount.nombre}. ¡Sigue así! 🎯💰',
            isUser: false,
            isSystem: true,
            timestamp: DateTime.now(),
          ));
        });

      } else if (action.type == 'create_transaction') {
        final tipo = action.params['tipo'] ?? 'gasto';
        final montoStr = action.params['monto'];
        final descripcion = action.params['descripcion'] ?? 'Gasto registrado';

        if (montoStr == null) {
          throw Exception('Falta el parámetro monto');
        }

        final monto = double.tryParse(montoStr) ?? 0.0;
        if (monto <= 0) throw Exception('Monto inválido para el registro');

        final accounts = ref.read(accountsWithBalanceProvider).valueOrNull ?? [];
        final defaultAccount = accounts.firstWhereOrNull((a) => a.isDefault) ?? accounts.firstOrNull;

        if (defaultAccount == null) {
          throw Exception('No tienes ninguna cuenta registrada para procesar la transacción.');
        }

        final categories = ref.read(categoriesListProvider).valueOrNull ?? [];
        final matchingCategories = categories.where((c) => c.tipo == tipo).toList();
        
        String? categoriaId;
        if (matchingCategories.isNotEmpty) {
          final targetCatName = action.params['categoria']?.toLowerCase() ?? descripcion.toLowerCase();
          final matched = matchingCategories.firstWhereOrNull(
            (c) => c.nombre.toLowerCase().contains(targetCatName) || targetCatName.contains(c.nombre.toLowerCase())
          );
          categoriaId = matched?.id ?? matchingCategories.first.id;
        }

        final ahora = DateTime.now();
        final transaction = TransactionModel(
          id: const Uuid().v4(),
          userId: '',
          tipo: tipo,
          monto: monto,
          fecha: ahora,
          estado: 'completa',
          descripcion: descripcion,
          cuentaOrigenId: defaultAccount.id,
          categoriaId: categoriaId,
          createdAt: ahora,
          isRecurring: false,
          autoComplete: false,
          weekendAdjustment: false,
        );

        await ref.read(transactionsNotifierProvider.notifier).createTransaction(transaction);

        if (mounted) {
          showAppToast(
            context,
            message: '${tipo == "gasto" ? "Gasto" : "Ingreso"} de \$${NumberFormat.decimalPattern().format(monto)} registrado con éxito.',
            type: ToastType.success,
          );
        }

        setState(() {
          _messages.add(AdvisorMessage(
            text: '¡Transacción registrada! He guardado el ${tipo == "gasto" ? "gasto" : "ingreso"} de \$${NumberFormat.decimalPattern().format(monto)} en tu cuenta ${defaultAccount.nombre}. 📝✅',
            isUser: false,
            isSystem: true,
            timestamp: DateTime.now(),
          ));
        });

      } else if (action.type == 'pay_recurring') {
        final ruleId = action.params['rule_id'];
        if (ruleId == null) {
          throw Exception('Falta el parámetro rule_id');
        }

        await financeService.processRecurringPayment(ruleId);

        if (mounted) {
          showAppToast(
            context,
            message: 'Pago recurrente registrado con éxito.',
            type: ToastType.success,
          );
        }

        setState(() {
          _messages.add(AdvisorMessage(
            text: '¡Servicio pagado! He registrado el movimiento de este gasto recurrente y actualizado su fecha de próximo vencimiento en tu calendario. 📅✅',
            isUser: false,
            isSystem: true,
            timestamp: DateTime.now(),
          ));
        });

      } else if (action.type == 'navigate') {
        final route = action.params['route'];
        if (route == null) throw Exception('Falta parámetro route');
        
        if (mounted) {
          Navigator.pop(context); // Cerrar bottom sheet
          context.push('/$route');
        }
      } else {
        throw Exception('Acción desconocida: ${action.type}');
      }
    } catch (e) {
      if (mounted) {
        showAppToast(context, message: 'Error al ejecutar acción: $e', type: ToastType.error);
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
      financeService.refreshAll();
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(recurringTransactionsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final backgroundColor = isDark ? AppColors.backgroundDark : Colors.white;
    final cardColor = isDark ? AppColors.surfaceDark : Colors.grey[100]!;
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppColors.radiusXLarge)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 25,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppColors.radiusXLarge)),
        child: Column(
          children: [
            // Línea indicadora superior
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 5),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white30 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            
            // Header del Asesor
            _buildHeader(context, isDark),
            
            // Divisor
            Divider(height: 1, color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
            
            // Chat area
            Expanded(
              child: _messages.isEmpty && _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    )
                  : Stack(
                      children: [
                        ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            return _buildMessageBubble(msg, isDark, cardColor);
                          },
                        ),
                        if (_isLoading && _messages.isNotEmpty)
                          Positioned(
                            left: 20,
                            bottom: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  const TypingIndicator(),
                                  const SizedBox(width: 8),
                                  Text(
                                    _iaThinkingStatus,
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
            ),

            // Sugerencias Rápidas (Chips de inicio)
            if (_messages.length == 1 && !_isLoading) _buildQuickSuggestions(),

            // Divisor
            Divider(height: 1, color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),

            // Barra de entrada
            _buildInputBar(context, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          // Avatar glowing
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Asesor de Libertad Financiera',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Inteligencia Artificial • En línea',
                  style: GoogleFonts.montserrat(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
            color: isDark ? Colors.white60 : Colors.black54,
            iconSize: 22,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(AdvisorMessage msg, bool isDark, Color cardColor) {
    final isMe = msg.isUser;
    
    if (msg.isSystem) {
      // Burbuja de notificación de sistema ejecutada
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline, color: AppColors.primary, size: 16),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  msg.text,
                  style: GoogleFonts.montserrat(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final bubbleBg = isMe
        ? AppColors.primary
        : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7));
    
    final textColor = isMe
        ? Colors.white
        : (isDark ? Colors.white : AppColors.textPrimary);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (msg.imagePath != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(
                    File(msg.imagePath!),
                    height: 180,
                    width: 240,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: bubbleBg,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: FormattedMessageText(
                text: msg.text,
                style: GoogleFonts.montserrat(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                  height: 1.4,
                ),
                boldStyle: GoogleFonts.montserrat(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                  height: 1.4,
                ),
              ),
            ),
            
            // Render de botones de acción
            if (msg.actions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: msg.actions.map((act) => _buildActionButton(act)).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(AdvisorAction action) {
    IconData icon;
    Color buttonColor;
    
    switch (action.type) {
      case 'pay_debt':
        icon = Icons.credit_card_rounded;
        buttonColor = AppColors.primary;
        break;
      case 'contribute_goal':
        icon = Icons.savings_rounded;
        buttonColor = AppColors.success;
        break;
      case 'navigate':
        icon = Icons.explore_rounded;
        buttonColor = AppColors.secondary;
        break;
      case 'create_transaction':
        icon = Icons.receipt_long_rounded;
        buttonColor = AppColors.secondary;
        break;
      case 'pay_recurring':
        icon = Icons.event_repeat_rounded;
        buttonColor = AppColors.primary;
        break;
      default:
        icon = Icons.play_arrow_rounded;
        buttonColor = AppColors.primary;
    }

    // Si es secundario (lime), el texto debe ser negro para contraste
    final foregroundColor = buttonColor == AppColors.secondary ? Colors.black : Colors.white;

    return ElevatedButton.icon(
      onPressed: () => _executeAction(action),
      icon: Icon(icon, size: 14, color: foregroundColor),
      label: Text(
        action.label,
        style: GoogleFonts.montserrat(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: foregroundColor,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: buttonColor,
        elevation: 1,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildQuickSuggestions() {
    final List<String> suggestions = [
      '💸 Plan para salir de deudas',
      '📊 ¿Cómo optimizar mis gastos?',
      '🎯 Estrategia para mis metas',
      '🚀 Ruta a libertad financiera',
    ];

    return Container(
      height: 46,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: suggestions.length,
        itemBuilder: (context, index) {
          final text = suggestions[index];
          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: ActionChip(
              onPressed: () {
                // Eliminar el emoji para mandar solo texto
                final cleanText = text.substring(2).trim();
                _sendUserMessage(cleanText);
              },
              label: Text(
                text,
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              backgroundColor: AppColors.primary.withOpacity(0.08),
              side: BorderSide(color: AppColors.primary.withOpacity(0.15)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputBar(BuildContext context, bool isDark) {
    final backgroundColor = isDark ? AppColors.surfaceDark : Colors.black.withOpacity(0.05);
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final hintColor = isDark ? AppColors.textSecondaryLight.withOpacity(0.5) : AppColors.textPrimary.withOpacity(0.5);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(AppColors.radiusCircular),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              // Botón de Micrófono
              GestureDetector(
                onTap: _isLoading ? null : _toggleListening,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _isListening ? AppColors.error : AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Botón de Imagen/Galería
              IconButton(
                onPressed: _isLoading ? null : _pickAndSendImage,
                icon: const Icon(Icons.image_outlined),
                color: isDark ? Colors.white70 : Colors.black54,
                iconSize: 22,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _textController,
                  onSubmitted: (_) => _onSendMessage(),
                  enabled: !_isLoading,
                  minLines: 1,
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.send,
                  style: GoogleFonts.montserrat(
                    color: textColor,
                    fontWeight: FontWeight.w500,
                    fontSize: AppColors.bodyMedium,
                  ),
                  decoration: InputDecoration(
                    hintText: _isListening ? 'Escuchando...' : 'Pregúntame sobre tus deudas o metas...',
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
              IconButton(
                onPressed: _isLoading ? null : _onSendMessage,
                icon: const Icon(Icons.send_rounded),
                color: AppColors.primary,
                iconSize: 22,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

/// Formateador de texto simple que renderiza Markdown (Negrita e Ítems de lista)
class FormattedMessageText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final TextStyle boldStyle;

  const FormattedMessageText({
    super.key,
    required this.text,
    required this.style,
    required this.boldStyle,
  });

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        // Verifica si la línea es un ítem de lista
        final isBullet = line.trim().startsWith('-') || line.trim().startsWith('*') || line.trim().startsWith('•');
        final cleanLine = isBullet
            ? line.trim().substring(1).trim()
            : line;

        // Parsea partes en negrita
        final parts = cleanLine.split('**');
        final textSpans = <TextSpan>[];
        
        for (int i = 0; i < parts.length; i++) {
          final part = parts[i];
          if (i % 2 == 1) {
            textSpans.add(TextSpan(text: part, style: boldStyle));
          } else {
            textSpans.add(TextSpan(text: part, style: style));
          }
        }

        Widget lineWidget = RichText(
          text: TextSpan(children: textSpans),
        );

        if (isBullet) {
          lineWidget = Padding(
            padding: const EdgeInsets.only(left: 12.0, top: 2.0, bottom: 2.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: boldStyle),
                Expanded(child: lineWidget),
              ],
            ),
          );
        } else {
          lineWidget = Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: lineWidget,
          );
        }

        return lineWidget;
      }).toList(),
    );
  }
}

/// Indicador visual animado de que la IA está escribiendo
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final delay = index * 0.2;
            final double value = (sin((_controller.value * 2 * pi) - delay) + 1.0) / 2.0;
            return Opacity(
              opacity: 0.3 + (0.7 * value),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2.0),
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        );
      }),
    );
  }
}