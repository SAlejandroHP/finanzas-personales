import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;
import 'package:uuid/uuid.dart';
import 'package:math_expressions/math_expressions.dart';
import 'package:collection/collection.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
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
    useRootNavigator: true, // Esto asegura que aparezca sobre la barra de navegación
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(24),
        topRight: Radius.circular(24),
      ),
    ),
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

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        expand: false,
        builder: (context, scrollController) {
        final body = Column(
          children: [
            // Header Minimalista
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 12, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Text(
                    widget.transaction != null ? 'Editar Movimiento' : 'Nuevo Movimiento',
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: isDark ? Colors.white38 : Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Formulario
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sección de Monto (Héroe)
                      Center(
                        child: Column(
                          children: [
                            Text(
                              '¿Cuánto vas a ${_getTipoAction(_tipo)}?',
                              style: GoogleFonts.montserrat(
                                fontSize: 13,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 12),
                            IntrinsicWidth(
                              child: TextField(
                                controller: _montoController,
                                focusNode: _montoFocusNode,
                                textAlign: TextAlign.center,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) {
                                  // Al presionar "Listo" en el teclado, aplicamos el cálculo y cerramos
                                  if (_calculatorResult.value != null) {
                                    setState(() {
                                      _montoController.text = _moneyFormatter.format(_calculatorResult.value);
                                      _onMontoChanged();
                                    });
                                  }
                                  _montoFocusNode.unfocus();
                                },
                                style: GoogleFonts.montserrat(
                                  fontSize: 42,
                                  fontWeight: FontWeight.w700,
                                  color: _getTipoColor(_tipo),
                                ),
                                decoration: InputDecoration(
                                  hintText: '\$ 0.00',
                                  hintStyle: TextStyle(color: (isDark ? Colors.white : AppColors.textPrimary).withOpacity(0.3)),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                            ValueListenableBuilder<double?>(
                              valueListenable: _calculatorResult,
                              builder: (context, result, _) {
                                if (result == null) return const SizedBox(height: 14);
                                return Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '= ${_moneyFormatter.format(result)}',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Selector de Tipo (Compacto M3)
                      Row(
                        children: [
                          Expanded(child: _buildTypeButton('gasto', 'Gasto', Icons.south_west_rounded, Colors.red, isDark)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildTypeButton('ingreso', 'Ingreso', Icons.north_east_rounded, Colors.green, isDark)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildTypeButton('transferencia', 'Transf.', Icons.swap_horiz_rounded, AppColors.primary, isDark)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildTypeButton('deuda_pago', 'Pago Deuda', Icons.credit_score_rounded, Colors.orange, isDark)),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Campos en lista limpia
                      _buildFormSectionHeader('DETALLES'),
                      
                      const SizedBox(height: 8),
                      // Selector de Cuenta
                      _buildSelectorTile(
                        label: (_tipo == 'transferencia' || _tipo == 'deuda_pago') ? 'Origen' : 'Cuenta',
                        value: _getAccountName(_cuentaOrigenId, accounts),
                        icon: Icons.account_balance_wallet_outlined,
                        onTap: () => _showAccountSelector(context, accounts, true),
                        isDark: isDark,
                      ),
                      
                      if (_tipo == 'transferencia' || _tipo == 'deuda_pago') ...[
                        const SizedBox(height: 12),
                        _buildSelectorTile(
                          label: 'Destino',
                          value: _getAccountName(_cuentaDestinoId, accounts),
                          icon: Icons.login_rounded,
                          onTap: () => _showAccountSelector(context, accounts, false),
                          isDark: isDark,
                        ),
                      ],
                      if (_tipo == 'gasto' || _tipo == 'ingreso') ...[
                        const SizedBox(height: 12),
                        _buildSelectorTile(
                          label: 'Categoría',
                          value: _getCategoryName(_categoriaId, categories),
                          icon: Icons.category_outlined,
                          onTap: () => _showCategorySelector(context, categories),
                          isDark: isDark,
                        ),
                      ],

                      if (_tipo == 'deuda_pago') ...[
                        const SizedBox(height: 12),
                        ref.watch(debtsListProvider).when(
                          data: (debts) => _buildSelectorTile(
                            label: 'Deuda a pagar',
                            value: _getDebtName(_deudaId, debts),
                            icon: Icons.money_off_rounded,
                            onTap: () => _showDebtSelector(context, debts),
                            isDark: isDark,
                          ),
                          loading: () => const LinearProgressIndicator(),
                          error: (_, __) => const Text('Error al cargar deudas'),
                        ),
                      ],

                      const SizedBox(height: 12),
                      _buildSelectorTile(
                        label: 'Fecha',
                        value: intl.DateFormat('d MMMM, yyyy', 'es').format(_fecha),
                        icon: Icons.calendar_today_rounded,
                        onTap: _selectDate,
                        isDark: isDark,
                      ),

                      const SizedBox(height: 24),
                      _buildFormSectionHeader('OPCIONAL'),
                      const SizedBox(height: 8),
                      
                      AppTextField(
                        controller: _descripcionController,
                        focusNode: _descripcionFocusNode,
                        label: 'Nota o descripción',
                        prefixIcon: Icons.notes_rounded,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 24),
                      
                      // Sección Recurrente
                      _buildFormSectionHeader('RECURRENCIA'),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                          borderRadius: BorderRadius.circular(16),
                          border: _isRecurring 
                              ? Border.all(color: AppColors.primary.withOpacity(0.5))
                              : null,
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.repeat_rounded, 
                                  color: _isRecurring ? AppColors.primary : Colors.grey
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Hacer recurrente',
                                    style: GoogleFonts.montserrat(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Switch(
                                  value: _isRecurring,
                                  activeColor: AppColors.primary,
                                  onChanged: (val) {
                                    setState(() {
                                      _isRecurring = val;
                                      if (val) {
                                        // Update rule to match current date day if switching on
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
                              const Divider(height: 24),
                              
                              // Frecuencia Dropdown
                              Row(
                                children: [
                                  const Icon(Icons.update, size: 20, color: Colors.grey),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Frecuencia',
                                          style: GoogleFonts.montserrat(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: _recurringRule,
                                            isExpanded: true,
                                            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                                            style: GoogleFonts.montserrat(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? Colors.white : Colors.black,
                                            ),
                                            items: [
                                              const DropdownMenuItem(
                                                value: 'quincenal',
                                                child: Text('Quincenal (15 y último)'),
                                              ),
                                              const DropdownMenuItem(
                                                value: 'monthly_day_13',
                                                child: Text('Mensual (día 13)'),
                                              ),
                                              const DropdownMenuItem(
                                                value: 'monthly_day_30',
                                                child: Text('Mensual (día 30)'),
                                              ),
                                              // Opción actual si no está en la lista estándar (para evitar crash)
                                              if (_recurringRule != 'quincenal' && 
                                                  _recurringRule != 'monthly_day_13' && 
                                                  _recurringRule != 'monthly_day_30')
                                                DropdownMenuItem(
                                                  value: _recurringRule,
                                                  child: Text(_getRuleLabel(_recurringRule)),
                                                ),
                                            ],
                                            onChanged: (val) {
                                              if (val != null) setState(() => _recurringRule = val);
                                            },
                                          ),
                                        ),
                                        
                                        // Ajuste fin de semana (solo para Quincenal y Día 30)
                                        if (_recurringRule == 'quincenal' || _recurringRule == 'monthly_day_30') ...[
                                          const SizedBox(height: 12),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Ajuste fin de semana',
                                                      style: GoogleFonts.montserrat(
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w600,
                                                        color: isDark ? Colors.white : Colors.black87,
                                                      ),
                                                    ),
                                                    Text(
                                                      'Adelanta al viernes si cae Sáb/Dom',
                                                      style: GoogleFonts.montserrat(
                                                        fontSize: 11,
                                                        color: Colors.grey,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Switch.adaptive(
                                                value: _weekendAdjustment,
                                                onChanged: (val) => setState(() => _weekendAdjustment = val),
                                                activeColor: AppColors.primary,
                                              ),
                                            ],
                                          ),
                                        ],

                                        const SizedBox(height: 8),
                                        // Vista previa de la próxima fecha
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4, left: 2),
                                          child: Text(
                                            'Próximo cobro: ${_getNextOccurrencePreview()}',
                                            style: GoogleFonts.montserrat(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Auto-completar Toggle
                              Row(
                                children: [
                                  Icon(
                                    Icons.check_circle_outline_rounded,
                                    size: 20, 
                                    color: _autoComplete ? Colors.green : Colors.grey
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Auto-completar',
                                          style: GoogleFonts.montserrat(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          'Marcar como completa automáticamente',
                                          style: GoogleFonts.montserrat(
                                            fontSize: 10,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: _autoComplete,
                                    activeColor: Colors.green,
                                    onChanged: (val) => setState(() => _autoComplete = val),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Estado
                      Row(
                        children: [
                           _buildFormSectionHeader('YA ESTÁ PAGADO?'),
                           const Spacer(),
                           Transform.scale(
                             scale: 0.7,
                             child: Switch(
                               value: _estado == 'completa',
                               activeTrackColor: AppColors.primary,
                               onChanged: (val) => setState(() => _estado = val ? 'completa' : 'pendiente'),
                             ),
                           ),
                        ],
                      ),
                      
                      const SizedBox(height: 80), // Espacio para el footer
                    ],
                  ),
                ),
              ),
            ),
            // Footer Adaptativo o Toolbar de Teclado
            _buildAdaptiveFooter(isDark),

          ],
        );
        return body;
      },
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
        height: AppSizes.buttonHeight,
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
                        fontSize: 20,
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
      case 'ingreso': return Colors.green;
      case 'transferencia': return AppColors.primary;
      default: return AppColors.primary;
    }
  }

  Widget _buildTypeButton(String type, String label, IconData icon, Color color, bool isDark) {
    final isSelected = _tipo == type;
    return GestureDetector(
      onTap: () => setState(() {
        _tipo = type;
        if (type != 'transferencia') {
          _cuentaDestinoId = null;
          _deudaId = null;
          _metaId = null;
        } else {
          _categoriaId = null;
        }
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.montserrat(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? color : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.montserrat(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: Colors.grey[500],
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500),
                ),
                Text(
                  value,
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
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
        builder: (context) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _tipo == 'transferencia' 
                    ? (isSource ? 'Selecciona origen' : 'Selecciona destino') 
                    : 'Selecciona una cuenta', 
                style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 18)
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final acc = list[index];
                    return ListTile(
                      leading: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.primary),
                      title: Text(acc.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(_moneyFormatter.format(acc.saldoActual)),
                      onTap: () {
                        setState(() {
                          if (isSource) _cuentaOrigenId = acc.id;
                          else _cuentaDestinoId = acc.id;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Selecciona la deuda', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            if (activeDebts.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: Text('No hay deudas activas')),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: activeDebts.length,
                  itemBuilder: (context, index) {
                    final debt = activeDebts[index];
                    return ListTile(
                      leading: const Icon(Icons.money_off_rounded, color: Colors.orange),
                      title: Text(debt.nombre),
                      subtitle: Text('Resta: ${_moneyFormatter.format(debt.montoRestante)}'),
                      onTap: () {
                        setState(() {
                          _deudaId = debt.id;
                          // Si la deuda tiene una cuenta asociada (ej. Tarjeta de Crédito), la ponemos como destino
                          if (debt.cuentaAsociadaId != null) {
                            _cuentaDestinoId = debt.cuentaAsociadaId;
                          }
                          if (_montoNumerico == 0) {
                             // Sugerir el monto a pagar
                             _montoNumerico = debt.montoRestante;
                             _montoController.text = _moneyFormatter.format(debt.montoRestante);
                          }
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
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
              fontSize: 20,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            style: GoogleFonts.montserrat(
              fontSize: 14,
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
                                      fontSize: 11,
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
