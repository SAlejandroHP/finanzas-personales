import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart' as intl;
import 'package:math_expressions/math_expressions.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../accounts/presentation/providers/accounts_provider.dart';
import 'package:finanzas/features/debts/models/debt_model.dart';
import '../providers/debts_provider.dart';

/// Bottom sheet para crear o editar una deuda.
class DebtFormSheet extends ConsumerStatefulWidget {
  final DebtModel? debt;

  const DebtFormSheet({Key? key, this.debt}) : super(key: key);

  @override
  ConsumerState<DebtFormSheet> createState() => _DebtFormSheetState();
}

class _DebtFormSheetState extends ConsumerState<DebtFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _montoTotalController = TextEditingController();
  final _montoRestanteController = TextEditingController();
  final _descripcionController = TextEditingController();

  final _montoTotalFocusNode = FocusNode();
  final _montoRestanteFocusNode = FocusNode();
  final _calculatorResult = ValueNotifier<double?>(null);
  
  // Formatter para moneda
  late final intl.NumberFormat _moneyFormatter;
  
  String _tipo = 'prestamo_personal';
  DateTime? _fechaVencimiento;
  String? _cuentaAsociadaId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    _moneyFormatter = intl.NumberFormat.currency(
      locale: 'es_MX',
      symbol: '\$ ',
      decimalDigits: 2,
    );

    // listeners para calculadora
    _montoTotalController.addListener(() => _onMontoChanged(_montoTotalController));
    _montoRestanteController.addListener(() => _onMontoChanged(_montoRestanteController));

    _montoTotalFocusNode.addListener(() => setState(() {}));
    _montoRestanteFocusNode.addListener(() => setState(() {}));

    if (widget.debt != null) {
      _nombreController.text = widget.debt!.nombre;
      _montoTotalController.text = widget.debt!.montoTotal.toString();
      _montoRestanteController.text = widget.debt!.montoRestante.toString();
      _descripcionController.text = widget.debt!.descripcion ?? '';
      _tipo = widget.debt!.tipo;
      _fechaVencimiento = widget.debt!.fechaVencimiento;
      _cuentaAsociadaId = widget.debt!.cuentaAsociadaId;
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _montoTotalController.dispose();
    _montoRestanteController.dispose();
    _descripcionController.dispose();
    _montoTotalFocusNode.dispose();
    _montoRestanteFocusNode.dispose();
    _calculatorResult.dispose();
    super.dispose();
  }

  void _onMontoChanged(TextEditingController controller) {
    final text = controller.text.trim();
    final cleanText = text.replaceAll(RegExp(r'[^\d\.\+\-\*\/\(\)]'), '').trim();
    
    if (cleanText.isEmpty) {
      _calculatorResult.value = null;
      return;
    }

    final result = _evaluateExpressionSafely(cleanText);
    if (result != null && result > 0) {
      _calculatorResult.value = result;
    } else {
      _calculatorResult.value = null;
    }
  }

  double? _evaluateExpressionSafely(String expr) {
    try {
      if (!RegExp(r'^[\d+\-*/().\s]+$').hasMatch(expr)) return null;
      final parser = Parser();
      final expression = parser.parse(expr);
      final contextModel = ContextModel();
      final result = expression.evaluate(EvaluationType.REAL, contextModel);
      if (result is num && result.isFinite && result > 0) return result.toDouble();
      return null;
    } catch (e) {
      return null;
    }
  }

  void _insertOperator(String op) {
    TextEditingController? controller;
    if (_montoTotalFocusNode.hasFocus) controller = _montoTotalController;
    else if (_montoRestanteFocusNode.hasFocus) controller = _montoRestanteController;

    if (controller == null) return;

    final text = controller.text;
    final selection = controller.selection;
    
    if (!selection.isValid) {
      controller.text = text + op;
      controller.selection = TextSelection.collapsed(offset: controller.text.length);
      return;
    }

    final newText = text.replaceRange(selection.start, selection.end, op);
    controller.text = newText;
    controller.selection = TextSelection.collapsed(offset: selection.start + op.length);
  }

  Widget _buildAdaptiveFooter(bool isDark) {
    if (_montoTotalFocusNode.hasFocus || _montoRestanteFocusNode.hasFocus) {
      return _buildCalculatorToolbar(isDark);
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: AppButton(
        label: widget.debt != null ? 'Actualizar Deuda' : 'Guardar Deuda',
        isLoading: _isLoading,
        onPressed: _save,
        isFullWidth: true,
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
                    child: Text(op, style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  ),
                ),
              ),
            )),
            const SizedBox(width: 8),
            ValueListenableBuilder<double?>(
              valueListenable: _calculatorResult,
              builder: (context, result, _) {
                return InkWell(
                  onTap: () {
                    final focusNode = _montoTotalFocusNode.hasFocus ? _montoTotalFocusNode : _montoRestanteFocusNode;
                    final controller = _montoTotalFocusNode.hasFocus ? _montoTotalController : _montoRestanteController;
                    
                    if (result != null) {
                      controller.text = result.toStringAsFixed(2);
                    }
                    focusNode.unfocus();
                  },
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                    child: const Center(child: Icon(Icons.check_rounded, color: Colors.white, size: 24)),
                  ),
                );
              }
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaVencimiento ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _fechaVencimiento = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final montoTotal = double.parse(_montoTotalController.text);
      final montoRestante = _montoRestanteController.text.isEmpty 
          ? montoTotal 
          : double.parse(_montoRestanteController.text);

      final debt = DebtModel(
        id: widget.debt?.id ?? const Uuid().v4(),
        userId: '', // Se asigna en el repositorio
        nombre: _nombreController.text.trim(),
        tipo: _tipo,
        montoTotal: montoTotal,
        montoRestante: montoRestante,
        fechaVencimiento: _fechaVencimiento,
        cuentaAsociadaId: _cuentaAsociadaId,
        descripcion: _descripcionController.text.trim().isEmpty ? null : _descripcionController.text.trim(),
        estado: montoRestante <= 0 ? 'pagada' : 'activa',
        createdAt: widget.debt?.createdAt ?? DateTime.now(),
      );

      if (widget.debt != null) {
        await ref.read(debtsNotifierProvider.notifier).updateDebt(debt);
      } else {
        await ref.read(debtsNotifierProvider.notifier).createDebt(debt);
      }

      if (mounted) {
        showAppToast(context, message: 'Deuda guardada', type: ToastType.success);
        Navigator.pop(context);
      }
    } catch (e) {
      showAppToast(context, message: 'Error: $e', type: ToastType.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accounts = ref.watch(accountsWithBalanceProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.debt != null ? 'Editar Deuda' : 'Nueva Deuda',
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              
              // Form
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppTextField(
                            controller: _nombreController,
                            label: 'Nombre de la deuda',
                            hintText: 'ej. Préstamo a mi hermano',
                            prefixIcon: Icons.title,
                            validator: (v) => v?.isEmpty ?? true ? 'Requerido' : null,
                          ),
                          const SizedBox(height: 16),
                          
                          // Tipo de deuda
                          Text(
                            'Tipo de deuda',
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _tipo,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'prestamo_personal', child: Text('Préstamo Personal')),
                              DropdownMenuItem(value: 'prestamo_bancario', child: Text('Préstamo Bancario')),
                              DropdownMenuItem(value: 'servicio', child: Text('Servicio (Luz, Agua, etc.)')),
                              DropdownMenuItem(value: 'otro', child: Text('Otro')),
                            ],
                            onChanged: (v) => setState(() => _tipo = v!),
                          ),
                          const SizedBox(height: 16),
                          
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    AppTextField(
                                      controller: _montoTotalController,
                                      focusNode: _montoTotalFocusNode,
                                      label: 'Monto Total',
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      prefixIcon: Icons.attach_money,
                                      validator: (v) => v?.isEmpty ?? true ? 'Requerido' : null,
                                      onChanged: (v) {
                                        if (widget.debt == null) {
                                          _montoRestanteController.text = v;
                                        }
                                      },
                                      onSubmitted: (_) {
                                        if (_calculatorResult.value != null) {
                                          _montoTotalController.text = _calculatorResult.value!.toStringAsFixed(2);
                                        }
                                        _montoTotalFocusNode.unfocus();
                                      },
                                    ),
                                    if (_montoTotalFocusNode.hasFocus)
                                      ValueListenableBuilder<double?>(
                                        valueListenable: _calculatorResult,
                                        builder: (context, result, _) {
                                          if (result == null) return const SizedBox.shrink();
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Text('= ${_moneyFormatter.format(result)}', style: GoogleFonts.montserrat(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600)),
                                          );
                                        },
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  children: [
                                    AppTextField(
                                      controller: _montoRestanteController,
                                      focusNode: _montoRestanteFocusNode,
                                      label: 'Monto Restante',
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      prefixIcon: Icons.money_off,
                                      hintText: 'Default: Total',
                                      onSubmitted: (_) {
                                        if (_calculatorResult.value != null) {
                                          _montoRestanteController.text = _calculatorResult.value!.toStringAsFixed(2);
                                        }
                                        _montoRestanteFocusNode.unfocus();
                                      },
                                    ),
                                    if (_montoRestanteFocusNode.hasFocus)
                                      ValueListenableBuilder<double?>(
                                        valueListenable: _calculatorResult,
                                        builder: (context, result, _) {
                                          if (result == null) return const SizedBox.shrink();
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Text('= ${_moneyFormatter.format(result)}', style: GoogleFonts.montserrat(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600)),
                                          );
                                        },
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Fecha de vencimiento
                          _buildSelectorTile(
                            label: 'Fecha de vencimiento (Opcional)',
                            value: _fechaVencimiento != null 
                                ? intl.DateFormat('dd/MM/yyyy').format(_fechaVencimiento!) 
                                : 'No seleccionada',
                            icon: Icons.calendar_today,
                            onTap: _selectDate,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 16),
                          
                          // Cuenta asociada
                          accounts.when(
                            data: (list) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Cuenta asociada (Opcional)',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  value: _cuentaAsociadaId,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                  hint: const Text('Ninguna'),
                                  items: [
                                    const DropdownMenuItem(value: null, child: Text('Ninguna')),
                                    ...list.map((acc) => DropdownMenuItem(
                                      value: acc.id,
                                      child: Text(acc.nombre),
                                    )),
                                  ],
                                  onChanged: (v) => setState(() => _cuentaAsociadaId = v),
                                ),
                              ],
                            ),
                            loading: () => const LinearProgressIndicator(),
                            error: (_, __) => const Text('Error al cargar cuentas'),
                          ),
                          const SizedBox(height: 16),
                          
                          AppTextField(
                            controller: _descripcionController,
                            label: 'Descripción / Notas',
                            maxLines: 3,
                            prefixIcon: Icons.notes,
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _buildAdaptiveFooter(isDark),
            ],
          ),
        );
      },
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
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
            const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
