import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;
import 'package:uuid/uuid.dart';
import 'package:math_expressions/math_expressions.dart';
import 'package:collection/collection.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../accounts/presentation/providers/accounts_provider.dart';
import '../../../categories/presentation/providers/categories_provider.dart';
import '../../../accounts/models/account_model.dart';
import '../../../categories/models/category_model.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../models/transaction_model.dart';
import '../providers/transactions_provider.dart';
import '../../../debts/presentation/providers/debts_provider.dart';
import 'package:finanzas/features/debts/models/debt_model.dart';
import '../../../../core/services/finance_service.dart';

/// Función que abre el bottom sheet para agregar/editar una transacción
Future<void> showTransactionFormSheet(
  BuildContext context, {
  TransactionModel? transaction,
  bool isRecurringDefault = false,
}) async {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.5),
    builder: (context) => TransactionFormSheet(
      transaction: transaction,
      isRecurringDefault: isRecurringDefault,
    ),
  );
}

/// Widget que contiene el formulario de transacción en un bottom sheet deslizable
class TransactionFormSheet extends ConsumerStatefulWidget {
  final TransactionModel? transaction;
  final bool isRecurringDefault;

  const TransactionFormSheet({
    Key? key,
    this.transaction,
    this.isRecurringDefault = false,
  }) : super(key: key);

  @override
  ConsumerState<TransactionFormSheet> createState() =>
      _TransactionFormSheetState();
}

class _TransactionFormSheetState extends ConsumerState<TransactionFormSheet> {
  late String _tipo; // 'gasto', 'ingreso', 'transferencia'
  late double _montoNumerico; // Valor numérico limpio para cálculos
  late DateTime _fecha;
  late String _descripcion;
  late String? _cuentaOrigenId;
  late String? _cuentaDestinoId;
  late String? _categoriaId;
  late String? _deudaId; // Para pago_deuda
  late String? _metaId; // Para aporte_meta
  late String _estado; // Corrección v2: 'completada' o 'pendiente'
  
  // Recurrente
  late bool _isRecurring;
  late String _recurringRule;
  late bool _autoComplete;
  late bool _weekendAdjustment;

  final _calculatorResult = ValueNotifier<double?>(null);

  late TextEditingController _montoController;
  late TextEditingController _descripcionController;
  final _montoFocusNode = FocusNode();
  final _descripcionFocusNode = FocusNode();
  
  // Corrección: Formatter para moneda MXN
  late final intl.NumberFormat _moneyFormatter;

  @override
  void initState() {
    super.initState();
    
    // Corrección: Inicializar formatter de moneda MXN
    _moneyFormatter = intl.NumberFormat.currency(
      locale: 'es_MX',
      symbol: '\$ ',
      decimalDigits: 2,
    );

    if (widget.transaction != null) {
      _tipo = widget.transaction!.tipo;
      // Corrección v5: Determinar sub-tipo si es transferencia
      _montoNumerico = widget.transaction!.monto;
      _fecha = widget.transaction!.fecha;
      _descripcion = widget.transaction!.descripcion ?? '';
      _cuentaOrigenId = widget.transaction!.cuentaOrigenId;
      _cuentaDestinoId = widget.transaction!.cuentaDestinoId;
      _categoriaId = widget.transaction!.categoriaId;
      _deudaId = widget.transaction!.deudaId;
      _metaId = widget.transaction!.metaId;
      _estado = widget.transaction!.estado; // Corrección v2: Leer estado existente
      
      _isRecurring = widget.transaction!.isRecurring;
      _recurringRule = widget.transaction!.recurringRule ?? 'monthly_day_13';
      _autoComplete = widget.transaction!.autoComplete;
      _weekendAdjustment = widget.transaction!.weekendAdjustment;
    } else {
      _tipo = 'gasto';
      _montoNumerico = 0.0;
      _fecha = DateTime.now();
      _descripcion = '';
      _cuentaOrigenId = null;
      _cuentaDestinoId = null;
      _categoriaId = null;
      _deudaId = null;
      _metaId = null;
      // Corrección v2: Establecer estado basado en fecha (default "completa" si hoy)
      final ahora = DateTime.now();
      final hoyFin = DateTime(ahora.year, ahora.month, ahora.day, 23, 59, 59);
      _estado = _fecha.isBefore(hoyFin) || 
                (_fecha.day == ahora.day && _fecha.month == ahora.month && _fecha.year == ahora.year) 
                ? 'completa' 
                : 'pendiente';
      
      _isRecurring = widget.isRecurringDefault;
      _recurringRule = 'monthly_day_13'; // Default para nuevas
      _autoComplete = false;
      _weekendAdjustment = false;
    }

    // Corrección: Inicializar el controller con valor formateado
    _montoController = TextEditingController(
      text: _montoNumerico > 0 ? _moneyFormatter.format(_montoNumerico) : '',
    );
    _descripcionController = TextEditingController(text: _descripcion);

    _montoController.addListener(_onMontoChanged);
    _montoFocusNode.addListener(() => setState(() {}));
    _descripcionFocusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _montoController.dispose();
    _descripcionController.dispose();
    _montoFocusNode.dispose();
    _descripcionFocusNode.dispose();
    _calculatorResult.dispose();
    super.dispose();
  }

  /// Corrección: Calcula expresiones matemáticas seguras usando math_expressions
  /// Solo evalúa si la expresión es válida, sin crash
  void _onMontoChanged() {
    final text = _montoController.text.trim();
    
    // Corrección: Extraer números limpios (remover formatos $, comas)
    final cleanText = text
        .replaceAll(RegExp(r'[^\d\.\+\-\*\/\(\)]'), '')
        .trim();
    
    if (cleanText.isEmpty) {
      _calculatorResult.value = null;
      _montoNumerico = 0.0;
      return;
    }

    // Intenta evaluar la expresión
    final result = _evaluateExpressionSafely(cleanText);
    
    if (result != null && result > 0) {
      // Corrección: Actualizar valor interno numérico
      _montoNumerico = result;
      // Mostrar resultado a un lado
      _calculatorResult.value = result;
    } else {
      // Si no es una expresión válida, interpreta como número directo
      final numValue = double.tryParse(cleanText);
      if (numValue != null && numValue > 0) {
        _montoNumerico = numValue;
        _calculatorResult.value = null; // Solo mostrar = si hay operación
      } else {
        _calculatorResult.value = null;
      }
    }
  }

  /// Corrección: Evalúa expresiones matemáticas de forma segura sin crashes
  /// Usa math_expressions para evitar bucles infinitos
  double? _evaluateExpressionSafely(String expr) {
    try {
      // Valida que solo contenga caracteres permitidos
      if (!RegExp(r'^[\d+\-*/().\s]+$').hasMatch(expr)) {
        return null;
      }

      // Usa math_expressions para evaluación segura
      final parser = Parser();
      final expression = parser.parse(expr);
      final contextModel = ContextModel();
      final result = expression.evaluate(EvaluationType.REAL, contextModel);
      
      // Corrección: Validar que es un número válido
      if (result is num && result.isFinite && result > 0) {
        return result.toDouble();
      }
      return null;
    } catch (e) {
      // Silenciosamente ignora errores de parsing - no crashes
      return null;
    }
  }

  /// Abre el date picker con cierre automático al seleccionar fecha
  Future<void> _selectDate() async {
    DateTime? selectedDate;
    
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          contentPadding: const EdgeInsets.all(0),
          content: SizedBox(
            width: 320,
            height: 400,
            child: CalendarDatePicker(
              initialDate: _fecha,
              firstDate: DateTime(2000),
              lastDate: DateTime.now().add(Duration(days: 365 * 2)),
              onDateChanged: (DateTime value) {
                selectedDate = value;
                Navigator.pop(context); // Cierra automáticamente al seleccionar
              },
            ),
          ),
        );
      },
    );
    
    if (selectedDate != null && mounted) {
      setState(() {
        _fecha = selectedDate!;
        // Recalcula el estado basado en la nueva fecha (Corrección v2)
        final ahora = DateTime.now();
        final hoyFin = DateTime(ahora.year, ahora.month, ahora.day, 23, 59, 59);
        _estado = selectedDate!.isBefore(hoyFin) || 
                  (selectedDate!.day == ahora.day && selectedDate!.month == ahora.month && selectedDate!.year == ahora.year)
                  ? 'completa' 
                  : 'pendiente';
      });
    }
  }

  /// Guarda la transacción
  Future<void> _saveTransaction() async {
    if (_cuentaOrigenId == null || _montoNumerico <= 0) {
      showAppToast(
        context,
        message: 'Por favor completa los campos requeridos',
        type: ToastType.error,
      );
      return;
    }

    // 1. Validar límite de crédito (Requisito 28)
    final accountsList = ref.read(accountsWithBalanceProvider).value ?? [];
    if (_cuentaOrigenId != null) {
      final selectedAccount = accountsList.firstWhereOrNull((a) => a.id == _cuentaOrigenId);
      if (selectedAccount != null && selectedAccount.tipo == 'tarjeta_credito' && _tipo == 'gasto') {
        // Para tarjetas de crédito, saldoActual es el disponible.
        // Si estamos editando, el disponible real es (disponible_actual + monto_anterior)
        double disponibleReal = selectedAccount.saldoActual;
        if (widget.transaction != null && widget.transaction!.cuentaOrigenId == _cuentaOrigenId && widget.transaction!.tipo == 'gasto') {
          disponibleReal += widget.transaction!.monto;
        }

        if (_montoNumerico > disponibleReal) {
          showAppToast(
            context,
            message: 'El monto excede el crédito disponible (${_moneyFormatter.format(disponibleReal)})',
            type: ToastType.error,
          );
          return;
        }
      }
    }

    // 2. Validar que no se pague más de lo que se debe (Requisito: Seguridad)
    if (_tipo == 'deuda_pago' && _deudaId != null) {
      final debtsList = ref.read(debtsListProvider).value ?? [];
      final selectedDebt = debtsList.firstWhereOrNull((d) => d.id == _deudaId);
      if (selectedDebt != null) {
        double restanteReal = selectedDebt.montoRestante;
        // Si estamos editando, sumamos lo que ya habíamos pagado
        if (widget.transaction != null && widget.transaction!.deudaId == _deudaId && widget.transaction!.tipo == 'deuda_pago') {
          restanteReal += widget.transaction!.monto;
        }

        if (_montoNumerico > restanteReal) {
          // Ajustamos automáticamente al saldo restante
          _montoNumerico = restanteReal;
          _montoController.text = _montoNumerico.toStringAsFixed(2);
          showAppToast(
            context,
            message: 'Monto ajustado al saldo pendiente de la deuda',
            type: ToastType.warning,
          );
          // No retornamos, dejamos que continúe con el monto ajustado
        }
      }
    }

    try {
      // Corrección v3: Validar estado basado en fecha y _estado del toggle
      String estadoFinal = _estado;
      if (!['completa', 'pendiente'].contains(estadoFinal)) {
        final ahora = DateTime.now();
        final hoyFin = DateTime(ahora.year, ahora.month, ahora.day, 23, 59, 59);
        estadoFinal = _fecha.isBefore(hoyFin) || 
                      (_fecha.day == ahora.day && _fecha.month == ahora.month && _fecha.year == ahora.year)
                      ? 'completa' 
                      : 'pendiente';
      }

      final transaction = TransactionModel(
        id: widget.transaction?.id ?? const Uuid().v4(),
        userId: '', // Se asigna en el repositorio
        tipo: _tipo,
        monto: _montoNumerico,
        fecha: _fecha,
        estado: estadoFinal,
        descripcion: _descripcionController.text.isEmpty
            ? null
            : _descripcionController.text,
        cuentaOrigenId: _cuentaOrigenId!,
        cuentaDestinoId: (_tipo == 'transferencia' || _tipo == 'deuda_pago') ? _cuentaDestinoId : null,
        categoriaId: (_tipo == 'gasto' || _tipo == 'ingreso') ? _categoriaId : null,
        deudaId: _tipo == 'deuda_pago' ? _deudaId : null,
        metaId: _tipo == 'meta_aporte' ? _metaId : null,
        createdAt: widget.transaction?.createdAt ?? DateTime.now(),
        isRecurring: _isRecurring,
        recurringRule: _isRecurring ? _recurringRule : null,
        autoComplete: _isRecurring ? _autoComplete : false,
        weekendAdjustment: _isRecurring ? _weekendAdjustment : false,
        // nextOccurrence y lastOccurrence se calculan en el repositorio
      );

      if (widget.transaction != null) {
        await ref.read(transactionsNotifierProvider.notifier).updateTransaction(transaction);
        
        // Llama a FinanceService para refrescar saldos y providers en toda la app
        ref.read(financeServiceProvider).updateAfterTransaction(transaction, ref);
      } else {
        await ref.read(transactionsNotifierProvider.notifier).createTransaction(transaction);

        // Llama a FinanceService para refrescar saldos y providers en toda la app
        ref.read(financeServiceProvider).updateAfterTransaction(transaction, ref);
      }

      if (mounted) {
        showAppToast(
          context,
          message: 'Transacción guardada exitosamente',
          type: ToastType.success,
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showAppToast(
          context,
          message: 'Error: $e',
          type: ToastType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accounts = ref.watch(accountsWithBalanceProvider);
    final categories = ref.watch(categoriesListProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final surfaceColor = isDark ? AppColors.surfaceDark : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppColors.radiusXLarge)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Barra táctil superior (Grabber Handle)
                Container(
                  margin: const EdgeInsets.only(top: AppColors.sm, bottom: AppColors.xs),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(AppColors.radiusSmall),
                  ),
                ),
                
                // Header con Título
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppColors.lg, vertical: AppColors.sm),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.transaction != null ? 'Editar Movimiento' : 'Nuevo Movimiento',
                        style: GoogleFonts.montserrat(
                          fontSize: AppColors.titleMedium,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: AppColors.iconMedium),
                        onPressed: () => Navigator.pop(context),
                        style: IconButton.styleFrom(
                          backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                        ),
                      ),
                    ],
                  ),
                ),

                // Contenido principal
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: AppColors.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppColors.md),
                        
                        // AREA HERO: Monto principal
                        Center(
                          child: Column(
                            children: [
                              Text(
                                '¿CUÁNTO VAS A ${_getTipoAction(_tipo).toUpperCase()}?',
                                style: GoogleFonts.montserrat(
                                  fontSize: AppColors.bodySmall,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: AppColors.sm),
                              IntrinsicWidth(
                                child: TextField(
                                  controller: _montoController,
                                  focusNode: _montoFocusNode,
                                  textAlign: TextAlign.center,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: GoogleFonts.montserrat(
                                    fontSize: 44,
                                    fontWeight: FontWeight.w800,
                                    color: _getTipoColor(_tipo),
                                  ),
                                  decoration: InputDecoration(
                                    hintText: '\$ 0.00',
                                    hintStyle: TextStyle(
                                      color: (isDark ? Colors.white24 : Colors.black12),
                                    ),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                              // Resultado de calculadora (si hay operación)
                              ValueListenableBuilder<double?>(
                                valueListenable: _calculatorResult,
                                builder: (context, result, _) {
                                  if (result == null) return const SizedBox(height: 24);
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: AppColors.md, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(AppColors.radiusCircular),
                                    ),
                                    child: Text(
                                      '= ${_moneyFormatter.format(result)}',
                                      style: GoogleFonts.montserrat(
                                        fontSize: AppColors.bodyMedium,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.success,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: AppColors.lg),

                        // Selectores de Tipo (Pills)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: [
                              _buildTypeButton('gasto', 'Gasto', Icons.south_west_rounded, Colors.red, isDark),
                              const SizedBox(width: AppColors.sm),
                              _buildTypeButton('ingreso', 'Ingreso', Icons.north_east_rounded, AppColors.success, isDark),
                              const SizedBox(width: AppColors.sm),
                              _buildTypeButton('transferencia', 'Transf.', Icons.swap_horiz_rounded, AppColors.primary, isDark),
                              const SizedBox(width: AppColors.sm),
                              _buildTypeButton('deuda_pago', 'Pago Deuda', Icons.credit_score_rounded, Colors.orange, isDark),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: AppColors.xl),

                        _buildFormSectionHeader('DETALLES DE LA TRANSACCIÓN'),
                        const SizedBox(height: AppColors.md),
                        
                        // Tarjeta de Cuenta
                        _buildSelectorTile(
                          label: (_tipo == 'transferencia' || _tipo == 'deuda_pago') ? 'De cuenta origen' : 'Cuenta principal',
                          value: _getAccountName(_cuentaOrigenId, accounts),
                          icon: Icons.account_balance_wallet_rounded,
                          onTap: () => _showAccountSelector(context, accounts, true),
                          isDark: isDark,
                        ),
                        
                        // Campos Condicionales
                        if (_tipo == 'transferencia' || _tipo == 'deuda_pago') ...[
                          const SizedBox(height: AppColors.md),
                          _buildSelectorTile(
                            label: 'Hacia cuenta destino',
                            value: _getAccountName(_cuentaDestinoId, accounts),
                            icon: Icons.login_rounded,
                            onTap: () => _showAccountSelector(context, accounts, false),
                            isDark: isDark,
                          ),
                        ],
                        
                        if (_tipo == 'gasto' || _tipo == 'ingreso') ...[
                          const SizedBox(height: AppColors.md),
                          _buildSelectorTile(
                            label: 'Categoría',
                            value: _getCategoryName(_categoriaId, categories),
                            icon: Icons.category_rounded,
                            onTap: () => _showCategorySelector(context, categories),
                            isDark: isDark,
                          ),
                        ],

                        if (_tipo == 'deuda_pago') ...[
                          const SizedBox(height: AppColors.md),
                          ref.watch(debtsListProvider).when(
                            data: (debts) => _buildSelectorTile(
                              label: 'Deuda vinculada',
                              value: _getDebtName(_deudaId, debts),
                              icon: Icons.money_off_rounded,
                              onTap: () => _showDebtSelector(context, debts),
                              isDark: isDark,
                            ),
                            loading: () => const Center(child: CircularProgressIndicator()),
                            error: (_, __) => const Text('Error al cargar deudas'),
                          ),
                        ],

                        const SizedBox(height: AppColors.md),
                        _buildSelectorTile(
                          label: 'Fecha del movimiento',
                          value: intl.DateFormat('EEEE d MMMM, yyyy', 'es').format(_fecha),
                          icon: Icons.calendar_today_rounded,
                          onTap: _selectDate,
                          isDark: isDark,
                        ),

                        const SizedBox(height: AppColors.xl),
                        _buildFormSectionHeader('NOTAS Y RECURRENCIA'),
                        const SizedBox(height: AppColors.md),
                        
                        // Campo de Texto para Notas
                        TextField(
                          controller: _descripcionController,
                          focusNode: _descripcionFocusNode,
                          style: GoogleFonts.montserrat(fontSize: AppColors.bodyMedium),
                          decoration: InputDecoration(
                            hintText: 'Añadir una nota...',
                            prefixIcon: const Icon(Icons.notes_rounded, color: Colors.grey),
                            filled: true,
                            fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppColors.radiusMedium),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.all(AppColors.md),
                          ),
                        ),
                        
                        const SizedBox(height: AppColors.md),

                        // Sección Recurrente Mejorada
                        Container(
                          padding: const EdgeInsets.all(AppColors.md),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey[50],
                            borderRadius: BorderRadius.circular(AppColors.radiusLarge),
                            border: Border.all(
                              color: _isRecurring 
                                  ? AppColors.primary.withOpacity(0.3) 
                                  : Colors.transparent,
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: _isRecurring 
                                          ? AppColors.primary.withOpacity(0.1) 
                                          : Colors.grey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(AppColors.radiusSmall),
                                    ),
                                    child: Icon(
                                      Icons.repeat_rounded, 
                                      color: _isRecurring ? AppColors.primary : Colors.grey,
                                      size: 20
                                    ),
                                  ),
                                  const SizedBox(width: AppColors.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Gasto Recurrente',
                                          style: GoogleFonts.montserrat(
                                            fontWeight: FontWeight.w700,
                                            fontSize: AppColors.bodyMedium,
                                          ),
                                        ),
                                        Text(
                                          'Repetir automáticamente',
                                          style: GoogleFonts.montserrat(
                                            fontSize: AppColors.bodySmall,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch.adaptive(
                                    value: _isRecurring,
                                    activeColor: AppColors.primary,
                                    onChanged: (val) {
                                      setState(() {
                                        _isRecurring = val;
                                        if (val) {
                                          if (!_recurringRule.contains(_fecha.day.toString()) && _recurringRule.startsWith('monthly_day_')) {
                                             _recurringRule = 'monthly_day_${_fecha.day}';
                                          }
                                        }
                                      });
                                    },
                                  ),
                                ],
                              ),
                              
                              if (_isRecurring) ...[
                                Padding(
                                  padding: const EdgeInsets.only(top: AppColors.md),
                                  child: Divider(color: isDark ? Colors.white10 : Colors.black12),
                                ),
                                const SizedBox(height: AppColors.sm),
                                
                                // Frecuencia
                                InkWell(
                                  onTap: () {
                                    // Podríamos mostrar un selector más bonito aquí
                                  },
                                  child: Row(
                                    children: [
                                      const Icon(Icons.update_rounded, size: 20, color: Colors.grey),
                                      const SizedBox(width: AppColors.md),
                                      Expanded(
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: _recurringRule,
                                            isExpanded: true,
                                            icon: const Icon(Icons.keyboard_arrow_down_rounded),
                                            style: GoogleFonts.montserrat(
                                              fontSize: AppColors.bodyMedium,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? Colors.white : AppColors.textPrimary,
                                            ),
                                            items: [
                                              const DropdownMenuItem(value: 'quincenal', child: Text('Quincenal (15 y último)')),
                                              const DropdownMenuItem(value: 'monthly_day_13', child: Text('Mensual (día 13)')),
                                              const DropdownMenuItem(value: 'monthly_day_30', child: Text('Mensual (día 30)')),
                                              if (_recurringRule != 'quincenal' && _recurringRule != 'monthly_day_13' && _recurringRule != 'monthly_day_30')
                                                DropdownMenuItem(value: _recurringRule, child: Text(_getRuleLabel(_recurringRule))),
                                            ],
                                            onChanged: (val) { if (val != null) setState(() => _recurringRule = val); },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                const SizedBox(height: AppColors.md),
                                
                                // Auto-comp Check
                                Row(
                                  children: [
                                    Icon(Icons.check_circle_outline_rounded, size: 20, color: _autoComplete ? AppColors.success : Colors.grey),
                                    const SizedBox(width: AppColors.md),
                                    Expanded(
                                      child: Text(
                                        'Auto-completar automáticamente',
                                        style: GoogleFonts.montserrat(fontSize: AppColors.bodySmall, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    Switch.adaptive(
                                      value: _autoComplete,
                                      activeColor: AppColors.success,
                                      onChanged: (val) => setState(() => _autoComplete = val),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: AppColors.sm),
                                // Preview
                                Row(
                                  children: [
                                    const SizedBox(width: 36),
                                    Text(
                                      'Próximo: ${_getNextOccurrencePreview()}',
                                      style: GoogleFonts.montserrat(
                                        fontSize: AppColors.bodySmall,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: AppColors.md),

                        // Toggle de Estado Pagado
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppColors.md, vertical: 4),
                          decoration: BoxDecoration(
                            color: _estado == 'completa' 
                                ? AppColors.success.withOpacity(0.05) 
                                : Colors.grey.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(AppColors.radiusLarge),
                            border: Border.all(
                              color: _estado == 'completa' 
                                  ? AppColors.success.withOpacity(0.3) 
                                  : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _estado == 'completa' ? AppColors.success.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _estado == 'completa' ? Icons.check_rounded : Icons.pending_actions_rounded,
                                  color: _estado == 'completa' ? AppColors.success : Colors.grey,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: AppColors.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Marcar como pagado',
                                      style: GoogleFonts.montserrat(
                                        fontWeight: FontWeight.w700,
                                        fontSize: AppColors.bodyMedium,
                                      ),
                                    ),
                                    Text(
                                      _estado == 'completa' ? 'Esta transacción ya se liquidó' : 'Quedará como pendiente',
                                      style: GoogleFonts.montserrat(fontSize: AppColors.bodySmall, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              Switch.adaptive(
                                value: _estado == 'completa',
                                activeColor: AppColors.success,
                                onChanged: (val) => setState(() => _estado = val ? 'completa' : 'pendiente'),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
                
                // Footer Adaptativo (Calculadora o Botón)
                _buildAdaptiveFooter(isDark),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAdaptiveFooter(bool isDark) {
    // Si el monto tiene el foco, mostrar toolbar de calculadora
    if (_montoFocusNode.hasFocus) {
      return _buildCalculatorToolbar(isDark);
    }

    // Por defecto, mostrar el botón de guardado
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: AppButton(
        label: widget.transaction != null ? 'Actualizar Movimiento' : 'Registrar Movimiento',
        onPressed: _saveTransaction,
        isFullWidth: true,
        height: AppColors.buttonHeight,
      ),
    );
  }

  Widget _buildCalculatorToolbar(bool isDark) {
    final operators = ['+', '-', '*', '/'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            ...operators.map((op) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  onTap: () => _insertOperator(op),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      op,
                      style: GoogleFonts.montserrat(
                        fontSize: AppColors.titleMedium,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
            )),
            const SizedBox(width: 8),
            // Botón Hecho / Cerrar
            InkWell(
              onTap: () {
                _montoFocusNode.unfocus();
                // Si hay un resultado, lo aplicamos "limpio"
                if (_calculatorResult.value != null) {
                  setState(() {
                    _montoController.text = _moneyFormatter.format(_calculatorResult.value);
                    _onMontoChanged(); // Re-evaluar
                  });
                }
              },
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(Icons.check_rounded, color: Colors.white, size: 24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRuleLabel(String rule) {
    if (rule == 'quincenal') return 'Quincenal (15 y último)';
    if (rule == 'monthly_day_13') return 'Mensual (día 13)';
    if (rule == 'monthly_day_30') return 'Mensual (día 30)';
    if (rule.startsWith('monthly_day_')) {
      final day = rule.split('_').last;
      return 'Mensual (día $day)';
    }
    if (rule == 'biweekly') return 'Cada 2 semanas';
    if (rule == 'weekly') return 'Cada semana';
    if (rule == 'bimonthly') return 'Cada 2 meses';
    if (rule == 'monthly_last_day') return 'Último día del mes';
    if (rule == 'monthly_last_friday') return 'Mensual (último viernes)';
    return rule;
  }

  String _getNextOccurrencePreview() {
    DateTime next = _fecha;
    final rule = _recurringRule;

    if (rule.startsWith('monthly_day_')) {
      try {
        final day = int.parse(rule.split('_').last);
        int m = _fecha.month;
        int y = _fecha.year;
        if (_fecha.day < day) {} else {
          m++; if (m > 12) { m = 1; y++; }
        }
        final lastDay = DateTime(y, m + 1, 0).day;
        next = DateTime(y, m, day > lastDay ? lastDay : day);
      } catch (_) {}
    } else if (rule == 'quincenal') {
      final lastDay = DateTime(_fecha.year, _fecha.month + 1, 0).day;
      if (_fecha.day < 15) next = DateTime(_fecha.year, _fecha.month, 15);
      else if (_fecha.day < lastDay) next = DateTime(_fecha.year, _fecha.month, lastDay);
      else next = DateTime(_fecha.year, _fecha.month + 1, 15);
    }
    
    // Aplicar ajuste de fin de semana para la vista previa
    if (_weekendAdjustment && (rule == 'quincenal' || rule == 'monthly_day_30')) {
      if (next.weekday == DateTime.saturday) {
        next = next.subtract(const Duration(days: 1));
      } else if (next.weekday == DateTime.sunday) {
        next = next.subtract(const Duration(days: 2));
      }
    }

    return intl.DateFormat('d MMMM, yyyy', 'es').format(next);
  }

  void _insertOperator(String op) {
    final text = _montoController.text;
    final selection = _montoController.selection;
    
    // Si no hay selección válida, poner al final
    if (!selection.isValid) {
      _montoController.text = text + op;
      _montoController.selection = TextSelection.collapsed(offset: _montoController.text.length);
      return;
    }

    final newText = text.replaceRange(selection.start, selection.end, op);
    _montoController.text = newText;
    _montoController.selection = TextSelection.collapsed(offset: selection.start + op.length);
  }

  String _getTipoAction(String tipo) {
    switch (tipo) {
      case 'gasto': return 'gastar';
      case 'ingreso': return 'recibir';
      case 'transferencia': return 'transferir';
      default: return 'registrar';
    }
  }

  Color _getTipoColor(String tipo) {
    switch (tipo) {
      case 'gasto': return Colors.red;
      case 'ingreso': return AppColors.success;
      case 'transferencia': return AppColors.primary;
      case 'deuda_pago': return Colors.orange;
      default: return AppColors.primary;
    }
  }

  Widget _buildTypeButton(String type, String label, IconData icon, Color color, bool isDark) {
    final isSelected = _tipo == type;
    return GestureDetector(
      onTap: () => setState(() {
        _tipo = type;
        if (type != 'transferencia' && type != 'deuda_pago') {
          _cuentaDestinoId = null;
          _deudaId = null;
          _metaId = null;
        } else if (type == 'transferencia') {
          _categoriaId = null;
          _deudaId = null;
          _metaId = null;
        } else if (type == 'deuda_pago') {
           _categoriaId = null;
           _metaId = null;
        }
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: AppColors.md, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100]),
          borderRadius: BorderRadius.circular(AppColors.radiusLarge),
          boxShadow: isSelected ? [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon, 
              color: isSelected ? Colors.white : Colors.grey, 
              size: 18
            ),
            const SizedBox(width: AppColors.sm),
            Text(
              label,
              style: GoogleFonts.montserrat(
                fontSize: AppColors.bodySmall,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: GoogleFonts.montserrat(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
          color: Colors.grey.withOpacity(0.8),
        ),
      ),
    );
  }

  Widget _buildSelectorTile({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppColors.radiusLarge),
      child: Container(
        padding: const EdgeInsets.all(AppColors.md),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
          borderRadius: BorderRadius.circular(AppColors.radiusLarge),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppColors.radiusMedium),
              ),
              child: Icon(icon, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: AppColors.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.montserrat(
                      fontSize: 11, 
                      color: Colors.grey, 
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: GoogleFonts.montserrat(
                      fontSize: AppColors.bodyLarge,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 22, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _showAccountSelector(BuildContext context, AsyncValue<List<AccountModel>> accounts, bool isSource) {
    accounts.whenData((list) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppColors.radiusXLarge)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Text(
                      _tipo == 'transferencia' 
                          ? (isSource ? 'Selecciona origen' : 'Selecciona destino') 
                          : 'Selecciona una cuenta', 
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w800, 
                        fontSize: AppColors.titleSmall
                      )
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppColors.sm),
                    itemBuilder: (context, index) {
                      final acc = list[index];
                      final isSelected = isSource ? _cuentaOrigenId == acc.id : _cuentaDestinoId == acc.id;
                      
                      return InkWell(
                        onTap: () {
                          setState(() {
                            if (isSource) _cuentaOrigenId = acc.id;
                            else _cuentaDestinoId = acc.id;
                          });
                          Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(AppColors.radiusLarge),
                        child: Container(
                          padding: const EdgeInsets.all(AppColors.md),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
                            borderRadius: BorderRadius.circular(AppColors.radiusLarge),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : (isDark ? Colors.white10 : Colors.black12),
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: AppColors.primary.withOpacity(0.1),
                                child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary, size: 20),
                              ),
                              const SizedBox(width: AppColors.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      acc.nombre, 
                                      style: GoogleFonts.montserrat(
                                        fontWeight: FontWeight.w700,
                                        fontSize: AppColors.bodyMedium,
                                      )
                                    ),
                                    Text(
                                      _moneyFormatter.format(acc.saldoActual),
                                      style: GoogleFonts.montserrat(
                                        fontSize: AppColors.bodySmall,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_circle_rounded, color: AppColors.primary),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    });
  }

  void _showCategorySelector(BuildContext context, AsyncValue<List<CategoryModel>> categories) {
    categories.whenData((list) {
      // Filtrar por tipo (gasto/ingreso)
      final initialFiltered = list.where((c) => (_tipo == 'gasto' && c.tipo == 'gasto') || (_tipo == 'ingreso' && c.tipo == 'ingreso')).toList();
      
      showModalBottomSheet(
        context: context,
        isScrollControlled: true, // Permite que el modal crezca según el contenido
        backgroundColor: Colors.transparent,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setStateModal) {
              // Variable para el texto de busqueda (local al modal)
              // Nota: Como StatefulBuilder reconstruye todo, necesitamos mantener el estado fuera o usar un wrapper.
              // En este caso simple, filtramos la lista original 'initialFiltered' basándonos en un controller que definimos aqui.
              // PERO: Definir el controller DENTRO del builder lo reiniciará en cada rebuild. 
              // Solución: Usar un Widget separado para el contenido del modal es lo ideal, 
              // pero para mantenerlo en este archivo usaré un enfoque directo creando el controller una vez.
              
              return _CategorySelectorModal(
                categories: initialFiltered,
                selectedId: _categoriaId,
                onSelected: (id) {
                  setState(() => _categoriaId = id);
                  Navigator.pop(context);
                },
                getIcon: _getIcon,
                getColor: _getColorFromHex,
              );
            }
          );
        },
      );
    });
  }

  String _getAccountName(String? id, AsyncValue<List<AccountModel>> accounts) {
    if (id == null) return 'Seleccionar';
    return accounts.when(
      data: (list) {
        try {
          return list.firstWhere((a) => a.id == id).nombre;
        } catch (_) {
          return 'Seleccionar';
        }
      },
      loading: () => '...',
      error: (_, __) => 'Error',
    );
  }

  String _getCategoryName(String? id, AsyncValue<List<CategoryModel>> categories) {
    if (id == null) return 'Seleccionar';
    return categories.when(
      data: (list) {
         try {
          return list.firstWhere((c) => c.id == id).nombre;
        } catch (_) {
          return 'Seleccionar';
        }
      },
      loading: () => '...',
      error: (_, __) => 'Error',
    );
  }

  String _getDebtName(String? id, List<DebtModel> debts) {
    if (id == null) return 'Seleccionar';
    try {
      return debts.firstWhere((d) => d.id == id).nombre;
    } catch (_) {
      return 'Seleccionar';
    }
  }

  void _showDebtSelector(BuildContext context, List<DebtModel> debts) {
    final activeDebts = debts.where((d) => d.estado == 'activa').toList();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppColors.radiusXLarge)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Text(
                    'Vincular deuda', 
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w800, 
                      fontSize: AppColors.titleSmall
                    )
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (activeDebts.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: Text('No hay deudas activas')),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: activeDebts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final debt = activeDebts[index];
                      final isSelected = _deudaId == debt.id;
                      
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _deudaId = debt.id;
                            if (debt.cuentaAsociadaId != null) {
                              _cuentaDestinoId = debt.cuentaAsociadaId;
                            }
                            if (_montoNumerico == 0) {
                               _montoNumerico = debt.montoRestante;
                               _montoController.text = _moneyFormatter.format(debt.montoRestante);
                               _onMontoChanged();
                            }
                          });
                          Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(AppColors.radiusLarge),
                        child: Container(
                          padding: const EdgeInsets.all(AppColors.md),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.orange.withOpacity(0.1) : Colors.transparent,
                            borderRadius: BorderRadius.circular(AppColors.radiusLarge),
                            border: Border.all(
                              color: isSelected ? Colors.orange : (isDark ? Colors.white10 : Colors.black12),
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.orange.withOpacity(0.1),
                                child: const Icon(Icons.money_off_rounded, color: Colors.orange, size: 20),
                              ),
                              const SizedBox(width: AppColors.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      debt.nombre, 
                                      style: GoogleFonts.montserrat(
                                        fontWeight: FontWeight.w700,
                                        fontSize: AppColors.bodyMedium,
                                      )
                                    ),
                                    Text(
                                      'Monto restante: ${_moneyFormatter.format(debt.montoRestante)}',
                                      style: GoogleFonts.montserrat(
                                        fontSize: AppColors.bodySmall,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_circle_rounded, color: Colors.orange),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  IconData _getIcon(String? iconName) {
    final iconMap = {
      'label_outline': Icons.label_outline,
      'restaurant_outlined': Icons.restaurant_outlined,
      'shopping_cart_outlined': Icons.shopping_cart_outlined,
      'directions_car_outlined': Icons.directions_car_outlined,
      'home_outlined': Icons.home_outlined,
      'checkroom_outlined': Icons.checkroom_outlined,
      'sports_esports_outlined': Icons.sports_esports_outlined,
      'fitness_center_outlined': Icons.fitness_center_outlined,
      'flight_outlined': Icons.flight_outlined,
      'medical_services_outlined': Icons.medical_services_outlined,
      'school_outlined': Icons.school_outlined,
      'work_outline': Icons.work_outline,
      'account_balance_wallet_outlined': Icons.account_balance_wallet_outlined,
      'payments_outlined': Icons.payments_outlined,
      'credit_card_outlined': Icons.credit_card_outlined,
      'trending_up': Icons.trending_up,
      'card_giftcard_outlined': Icons.card_giftcard_outlined,
      'sports_bar_outlined': Icons.sports_bar_outlined,
      'fastfood_outlined': Icons.fastfood_outlined,
      'book_outlined': Icons.book_outlined,
      'content_cut_outlined': Icons.content_cut_outlined,
      'pets_outlined': Icons.pets_outlined,
      'local_florist_outlined': Icons.local_florist_outlined,
      'sports_soccer_outlined': Icons.sports_soccer_outlined,
      'umbrella_outlined': Icons.umbrella_outlined,
      'water_drop_outlined': Icons.water_drop_outlined,
      'directions_bus_outlined': Icons.directions_bus_outlined,
      'directions_bike_outlined': Icons.directions_bike_outlined,
      'train_outlined': Icons.train_outlined,
      'photo_camera_outlined': Icons.photo_camera_outlined,
      'music_note_outlined': Icons.music_note_outlined,
      'movie_outlined': Icons.movie_outlined,
      'local_cafe_outlined': Icons.local_cafe_outlined,
      'local_pizza_outlined': Icons.local_pizza_outlined,
      'icecream_outlined': Icons.icecream_outlined,
      'laptop_outlined': Icons.laptop_outlined,
      'smartphone_outlined': Icons.smartphone_outlined,
      'headset_outlined': Icons.headset_outlined,
      'lightbulb_outline': Icons.lightbulb_outline,
    };
    return iconMap[iconName] ?? Icons.label_outline;
  }

  Color _getColorFromHex(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) return Colors.grey;
    try {
      final hexString = hexColor.replaceFirst('#', '');
      return Color(int.parse('FF$hexString', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }
}

class _CategorySelectorModal extends StatefulWidget {
  final List<CategoryModel> categories;
  final String? selectedId;
  final Function(String) onSelected;
  final IconData Function(String?) getIcon;
  final Color Function(String?) getColor;

  const _CategorySelectorModal({
    Key? key,
    required this.categories,
    required this.selectedId,
    required this.onSelected,
    required this.getIcon,
    required this.getColor,
  }) : super(key: key);

  @override
  State<_CategorySelectorModal> createState() => _CategorySelectorModalState();
}

class _CategorySelectorModalState extends State<_CategorySelectorModal> {
  late TextEditingController _searchController;
  late List<CategoryModel> _filteredCategories;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _filteredCategories = widget.categories;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredCategories = widget.categories.where((c) {
        return c.nombre.toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.95;

    return Container(
      constraints: BoxConstraints(
        maxHeight: maxHeight,
      ),
      padding: EdgeInsets.only(
        top: 24, 
        left: 20, 
        right: 20, 
        bottom: bottomInset > 0 ? bottomInset + 16 : 30 
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Elige una categoría',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w700,
              fontSize: AppColors.titleMedium,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            style: GoogleFonts.montserrat(
              fontSize: AppColors.bodyMedium,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Buscar categoría...',
              hintStyle: TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
              filled: true,
              fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 20),
          Flexible(
            child: _filteredCategories.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        'No hay resultados',
                        style: GoogleFonts.montserrat(color: Colors.grey),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 1.0,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: _filteredCategories.length,
                      itemBuilder: (context, index) {
                        final cat = _filteredCategories[index];
                        final isSelected = widget.selectedId == cat.id;
                        final catColor = widget.getColor(cat.color);
                        
                        return InkWell(
                          onTap: () => widget.onSelected(cat.id),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected 
                                  ? catColor.withOpacity(0.15) 
                                  : isDark 
                                      ? Colors.white.withOpacity(0.05) 
                                      : Colors.grey[50],
                              border: Border.all(
                                color: isSelected ? catColor : Colors.transparent,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: catColor.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    widget.getIcon(cat.icono),
                                    color: catColor,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(
                                    cat.nombre,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.montserrat(
                                      fontSize: AppColors.bodySmall,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      color: isSelected 
                                          ? catColor 
                                          : isDark 
                                              ? Colors.white70 
                                              : Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
