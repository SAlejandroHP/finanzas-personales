import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;
import 'package:uuid/uuid.dart';
import 'package:math_expressions/math_expressions.dart';
import 'package:collection/collection.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../accounts/presentation/providers/accounts_provider.dart';
import '../../../accounts/models/account_model.dart';
import '../../models/debt_model.dart';
import '../providers/debts_provider.dart';
import '../../../transactions/models/transaction_model.dart';
import '../../../transactions/presentation/providers/transactions_provider.dart';

/// Función que abre el bottom sheet para agregar/editar una deuda
Future<void> showDebtFormSheet(
  BuildContext context, {
  DebtModel? debt,
}) async {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.5),
    builder: (context) => DebtFormSheet(debt: debt),
  );
}

class DebtFormSheet extends ConsumerStatefulWidget {
  final DebtModel? debt;

  const DebtFormSheet({super.key, this.debt});

  @override
  ConsumerState<DebtFormSheet> createState() => _DebtFormSheetState();
}

class _DebtFormSheetState extends ConsumerState<DebtFormSheet> {
  late String _tipo;
  late double _montoTotal;
  late DateTime? _fechaVencimiento;
  late String? _cuentaAsociadaId;

  final _calculatorResult = ValueNotifier<double?>(null);
  late TextEditingController _montoController;
  late TextEditingController _nombreController;
  late TextEditingController _descripcionController;
  final _montoFocusNode = FocusNode();
  final _nombreFocusNode = FocusNode();
  final _descripcionFocusNode = FocusNode();

  late final intl.NumberFormat _moneyFormatter;

  @override
  void initState() {
    super.initState();
    _moneyFormatter = intl.NumberFormat.currency(
      locale: 'es_MX',
      symbol: '\$ ',
      decimalDigits: 2,
    );

    if (widget.debt != null) {
      _tipo = widget.debt!.tipo;
      _montoTotal = widget.debt!.montoTotal;
      _fechaVencimiento = widget.debt!.fechaVencimiento;
      _cuentaAsociadaId = widget.debt!.cuentaAsociadaId;
    } else {
      _tipo = 'prestamo_personal';
      _montoTotal = 0.0;
      _fechaVencimiento = null;
      _cuentaAsociadaId = null;
    }

    _montoController = TextEditingController(
      text: _montoTotal > 0 ? _moneyFormatter.format(_montoTotal) : '',
    );
    _nombreController = TextEditingController(text: widget.debt?.nombre ?? '');
    _descripcionController = TextEditingController(text: widget.debt?.descripcion ?? '');

    _montoController.addListener(_onMontoChanged);
    _montoFocusNode.addListener(() => setState(() {}));
    _nombreFocusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _montoController.dispose();
    _nombreController.dispose();
    _descripcionController.dispose();
    _montoFocusNode.dispose();
    _nombreFocusNode.dispose();
    _descripcionFocusNode.dispose();
    _calculatorResult.dispose();
    super.dispose();
  }

  void _onMontoChanged() {
    final text = _montoController.text.trim();
    final cleanText = text.replaceAll(RegExp(r'[^0-9.\+\-\*\/()]'), '').trim();

    if (cleanText.isEmpty) {
      _calculatorResult.value = null;
      _montoTotal = 0.0;
      return;
    }

    final result = _evaluateExpressionSafely(cleanText);
    if (result != null && result > 0) {
      _montoTotal = result;
      _calculatorResult.value = result;
    } else {
      final numValue = double.tryParse(cleanText);
      if (numValue != null && numValue > 0) {
        _montoTotal = numValue;
        _calculatorResult.value = null;
      } else {
        _calculatorResult.value = null;
      }
    }
  }

  double? _evaluateExpressionSafely(String expr) {
    try {
      if (!RegExp(r'^[0-9+\-*/().\s]+$').hasMatch(expr)) return null;
      final parser = ShuntingYardParser();
      final expression = parser.parse(expr);
      final contextModel = ContextModel();
      final result = expression.evaluate(EvaluationType.REAL, contextModel);
      if (result is num && result.isFinite && result > 0) return result.toDouble();
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fechaVencimiento ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked != null) {
      setState(() => _fechaVencimiento = picked);
    }
  }

  Future<void> _saveDebt() async {
    final nombre = _nombreController.text.trim();
    if (nombre.isEmpty || _montoTotal <= 0) {
      showAppToast(context, message: 'Nombre y monto son obligatorios', type: ToastType.error);
      return;
    }

    try {
      final debtId = widget.debt?.id ?? const Uuid().v4();
      final debt = DebtModel(
        id: debtId,
        userId: '',
        nombre: nombre,
        tipo: _tipo,
        montoTotal: _montoTotal,
        montoRestante: widget.debt?.montoRestante ?? _montoTotal,
        fechaVencimiento: _fechaVencimiento,
        cuentaAsociadaId: _cuentaAsociadaId,
        descripcion: _descripcionController.text.trim().isEmpty ? null : _descripcionController.text.trim(),
        estado: _montoTotal <= 0 ? 'pagada' : 'activa',
        createdAt: widget.debt?.createdAt ?? DateTime.now(),
      );

      if (widget.debt == null) {
        await ref.read(debtsNotifierProvider.notifier).createDebt(debt);
        if (_cuentaAsociadaId != null) {
           final transaction = TransactionModel(
             id: const Uuid().v4(),
             userId: '',
             tipo: 'ingreso',
             monto: _montoTotal,
             fecha: DateTime.now(),
             estado: 'completa',
             descripcion: 'Préstamo: $nombre',
             cuentaOrigenId: _cuentaAsociadaId!,
             deudaId: debtId,
             createdAt: DateTime.now(),
           );
           await ref.read(transactionsNotifierProvider.notifier).createTransaction(transaction);
        }
      } else {
        await ref.read(debtsNotifierProvider.notifier).updateDebt(debt);
      }

      if (mounted) {
        showAppToast(context, message: 'Deuda registrada exitosamente', type: ToastType.success);
        Navigator.pop(context);
      }
    } catch (e) {
       if (mounted) showAppToast(context, message: 'Error: ${e.toString()}', type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.surfaceDark : Colors.white;
    final accounts = ref.watch(accountsWithBalanceProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppColors.radiusXLarge)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.debt != null ? 'Editar Deuda' : 'Nueva Deuda',
                        style: GoogleFonts.montserrat(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                        style: IconButton.styleFrom(
                          backgroundColor: isDark ? Colors.white10 : Colors.grey[100],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        Center(
                          child: Column(
                            children: [
                              Text(
                                'MONTO TOTAL DE LA DEUDA',
                                style: GoogleFonts.montserrat(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.grey,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _montoController,
                                focusNode: _montoFocusNode,
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.none,
                                showCursor: true,
                                style: GoogleFonts.montserrat(
                                  fontSize: 44,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.secondary,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: '\$ 0.00',
                                  hintStyle: TextStyle(color: Colors.grey),
                                ),
                              ),
                              ValueListenableBuilder<double?>(
                                valueListenable: _calculatorResult,
                                builder: (context, result, _) {
                                  if (result == null) return const SizedBox(height: 20);
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.secondary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '= ${_moneyFormatter.format(result)}',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.secondary,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        _buildSectionHeader('INFORMACIÓN BÁSICA'),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _nombreController,
                          focusNode: _nombreFocusNode,
                          label: 'Nombre de la deuda',
                          hint: 'Ej: Préstamo Banco, Deuda Familiar...',
                          icon: Icons.edit_note_rounded,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 16),
                        _buildTypePills(isDark),
                        const SizedBox(height: 24),
                        _buildSectionHeader('DETALLES Y VENCIMIENTO'),
                        const SizedBox(height: 16),
                        _buildSelectorTile(
                          label: 'Fecha de vencimiento',
                          value: _fechaVencimiento != null 
                              ? intl.DateFormat('dd MMM, yyyy', 'es').format(_fechaVencimiento!)
                              : 'Opcional',
                          icon: Icons.calendar_today_rounded,
                          onTap: _selectDate,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 16),
                        _buildSelectorTile(
                          label: '¿Dónde recibes el dinero?',
                          value: _getAccountName(_cuentaAsociadaId, accounts),
                          icon: Icons.account_balance_wallet_rounded,
                          onTap: () => _showAccountSelector(context, accounts),
                          isDark: isDark,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _descripcionController,
                          focusNode: _descripcionFocusNode,
                          label: 'Notas adicionales',
                          hint: 'Opcional...',
                          icon: Icons.notes_rounded,
                          isDark: isDark,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
                _buildAdaptiveFooter(isDark),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
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

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    int maxLines = 1,
    bool isAmount = false, // Añadido para identificar el campo de monto
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: isDark ? Colors.white38 : Colors.grey[400], size: 20),
              const SizedBox(width: 12),
              Text(
                label.toUpperCase(),
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: Colors.grey.withOpacity(0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            focusNode: focusNode,
            maxLines: maxLines,
            style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w500, color: isDark ? Colors.white : AppColors.textPrimary),
            keyboardType: isAmount ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.montserrat(color: isDark ? Colors.white24 : Colors.grey[400]),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          // Homologación: Muestra el resultado de la calculadora si existe
          if (isAmount)
            ValueListenableBuilder<double?>(
              valueListenable: _calculatorResult,
              builder: (context, value, child) {
                if (value == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    '= ${_moneyFormatter.format(value)}',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTypePills(bool isDark) {
    final types = [
      {'id': 'prestamo_personal', 'name': 'Personal', 'icon': Icons.people_outline},
      {'id': 'prestamo_bancario', 'name': 'Bancario', 'icon': Icons.account_balance_outlined},
      {'id': 'servicio', 'name': 'Servicio', 'icon': Icons.receipt_long_outlined},
      {'id': 'otro', 'name': 'Otro', 'icon': Icons.more_horiz_outlined},
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: types.map((t) {
          final isSelected = _tipo == t['id'];
          return GestureDetector(
            onTap: () => setState(() => _tipo = t['id'] as String),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : (isDark ? Colors.white10 : Colors.grey[100]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(t['icon'] as IconData, color: isSelected ? Colors.white : Colors.grey, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    t['name'] as String,
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSelectorTile({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
    Widget? trailing, // Añadido para consistencia
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Icon(icon, color: isDark ? Colors.white70 : AppColors.textPrimary.withOpacity(0.8), size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing,
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildAdaptiveFooter(bool isDark) {
    if (_montoFocusNode.hasFocus) {
      return _buildCalculatorToolbar(isDark);
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: AppButton(
        label: widget.debt != null ? 'Actualizar Deuda' : 'Registrar Deuda',
        onPressed: _saveDebt,
        isFullWidth: true,
      ),
    );
  }

  Widget _buildCalculatorToolbar(bool isDark) {
    final operators = ['+', '-', '*', '/'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            ...operators.map((op) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: IconButton(
                  onPressed: () => _insertOperator(op),
                  icon: Text(op, style: GoogleFonts.montserrat(fontSize: 24, color: AppColors.primary, fontWeight: FontWeight.w600)),
                  style: IconButton.styleFrom(backgroundColor: isDark ? Colors.white10 : Colors.grey[100]),
                ),
              ),
            )),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () {
                _montoFocusNode.unfocus();
                if (_calculatorResult.value != null) {
                  setState(() {
                    _montoController.text = _moneyFormatter.format(_calculatorResult.value);
                    _onMontoChanged();
                  });
                }
              },
              icon: const Icon(Icons.check_rounded, color: Colors.white, size: 28),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _insertOperator(String op) {
    final text = _montoController.text;
    final selection = _montoController.selection;
    final newText = text.replaceRange(selection.start.clamp(0, text.length), selection.end.clamp(0, text.length), op);
    _montoController.text = newText;
    _montoController.selection = TextSelection.collapsed(offset: (selection.start + op.length).clamp(0, _montoController.text.length));
  }

  String _getAccountName(String? id, AsyncValue<List<AccountModel>> accounts) {
    if (id == null) return 'Ninguna';
    return accounts.maybeWhen(
      data: (list) => list.firstWhereOrNull((a) => a.id == id)?.nombre ?? 'Ninguna',
      orElse: () => '...',
    );
  }

  void _showAccountSelector(BuildContext context, AsyncValue<List<AccountModel>> accounts) {
    accounts.whenData((list) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppColors.radiusXLarge)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('¿Dónde cae el dinero?', style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 18)),
                const SizedBox(height: 12),
                Text('Si seleccionas una cuenta, se creará un ingreso por el monto de la deuda.', 
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 20),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final acc = list[index];
                      return ListTile(
                        onTap: () {
                          setState(() => _cuentaAsociadaId = acc.id);
                          Navigator.pop(context);
                        },
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                          child: Icon(Icons.account_balance_wallet_outlined, color: AppColors.primary, size: 20),
                        ),
                        title: Text(acc.nombre, style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
                        subtitle: Text(acc.tipo),
                        trailing: _cuentaAsociadaId == acc.id ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    setState(() => _cuentaAsociadaId = null);
                    Navigator.pop(context);
                  }, 
                  child: const Text('Ninguna (Solo registrar deuda)')
                ),
              ],
            ),
          );
        },
      );
    });
  }
}
