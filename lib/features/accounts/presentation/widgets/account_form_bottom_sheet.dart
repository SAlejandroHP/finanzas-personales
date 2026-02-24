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
import '../../../../core/widgets/bank_logo.dart';
import '../../../../core/network/supabase_client.dart';
import '../../models/account_model.dart';
import '../../models/bank_model.dart';
import '../../models/currency_model.dart';
import '../providers/accounts_provider.dart';
import '../providers/banks_provider.dart';
import '../providers/currencies_provider.dart';

/// Widget bottom sheet deslizable para crear o editar una cuenta.
class AccountFormBottomSheet extends ConsumerStatefulWidget {
  const AccountFormBottomSheet({Key? key}) : super(key: key);

  @override
  ConsumerState<AccountFormBottomSheet> createState() =>
      _AccountFormBottomSheetState();
}

class _AccountFormBottomSheetState extends ConsumerState<AccountFormBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _saldoInicialController = TextEditingController();
  final _limiteCreditoController = TextEditingController();
  final _deudaActualController = TextEditingController(text: '0');

  final _saldoInicialFocusNode = FocusNode();
  final _limiteCreditoFocusNode = FocusNode();
  final _deudaActualFocusNode = FocusNode();
  final _calculatorResult = ValueNotifier<double?>(null);
  
  // Formatter para moneda
  late final intl.NumberFormat _moneyFormatter;

  String? _selectedTipo;
  String? _selectedMonedaId;
  BankModel? _selectedBank;
  bool _isLoading = false;
  bool _isDefault = false;

  @override
  void initState() {
    super.initState();
    
    _moneyFormatter = intl.NumberFormat.currency(
      locale: 'es_MX',
      symbol: '\$ ',
      decimalDigits: 2,
    );

    // listeners para calculadora
    _saldoInicialController.addListener(() => _onMontoChanged(_saldoInicialController));
    _limiteCreditoController.addListener(() => _onMontoChanged(_limiteCreditoController));
    _deudaActualController.addListener(() => _onMontoChanged(_deudaActualController));

    _saldoInicialFocusNode.addListener(() => setState(() {}));
    _limiteCreditoFocusNode.addListener(() => setState(() {}));
    _deudaActualFocusNode.addListener(() => setState(() {}));

    // Cargar datos si es edición o hay banco preseleccionado
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final selectedAccount = ref.read(selectedAccountProvider);
      if (selectedAccount != null) {
        _nombreController.text = selectedAccount.nombre;
        _saldoInicialController.text = selectedAccount.saldoInicial.toString();
        setState(() {
          _selectedTipo = selectedAccount.tipo;
          _selectedMonedaId = selectedAccount.monedaId;
          _isDefault = selectedAccount.isDefault;
          if (selectedAccount.bancoId != null) {
            _selectedBank = BankModel(
              id: selectedAccount.bancoId!,
              name: selectedAccount.bancoNombre ?? '',
              displayName: selectedAccount.bancoNombre ?? '',
              logo: selectedAccount.bancoLogo,
              primaryColor: '#000000',
              countryCodes: ['MX'],
              status: 'healthy',
            );
          }
        });
      } else {
        final preselectedBank = ref.read(selectedBankProvider);
        if (preselectedBank != null) {
          setState(() {
            _selectedBank = preselectedBank;
          });
          ref.read(selectedBankProvider.notifier).state = null;
        }
      }
    });
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _saldoInicialController.dispose();
    _limiteCreditoController.dispose();
    _deudaActualController.dispose();
    _saldoInicialFocusNode.dispose();
    _limiteCreditoFocusNode.dispose();
    _deudaActualFocusNode.dispose();
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
    if (_saldoInicialFocusNode.hasFocus) controller = _saldoInicialController;
    else if (_limiteCreditoFocusNode.hasFocus) controller = _limiteCreditoController;
    else if (_deudaActualFocusNode.hasFocus) controller = _deudaActualController;

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

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTipo == null || _selectedMonedaId == null) {
      _showError('Por favor completa los campos requeridos');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final selectedAccount = ref.read(selectedAccountProvider);
      final saldoInicial = double.tryParse(_saldoInicialController.text) ?? 0.0;

      final account = AccountModel(
        id: selectedAccount?.id ?? const Uuid().v4(),
        userId: supabaseClient.auth.currentUser!.id,
        nombre: _nombreController.text.trim(),
        tipo: _selectedTipo!,
        bancoId: _selectedBank?.id,
        bancoNombre: _selectedBank?.displayName,
        bancoLogo: _selectedBank?.logo,
        monedaId: _selectedMonedaId!,
        saldoInicial: saldoInicial,
        saldoActual: selectedAccount?.saldoActual ?? saldoInicial,
        createdAt: selectedAccount?.createdAt ?? DateTime.now(),
        updatedAt: selectedAccount != null ? DateTime.now() : null,
        isDefault: _isDefault,
      );

      if (selectedAccount != null) {
        await ref.read(accountsNotifierProvider.notifier).updateAccount(account);
      } else {
        final limiteCredito = double.tryParse(_limiteCreditoController.text);
        final deudaActual = double.tryParse(_deudaActualController.text) ?? 0.0;
        
        await ref.read(accountsNotifierProvider.notifier).createAccount(
          account,
          limiteCredito: _selectedTipo == 'tarjeta_credito' ? limiteCredito : null,
          deudaActual: _selectedTipo == 'tarjeta_credito' ? deudaActual : null,
        );
      }

      // Si se marcó como default, llamamos al notifier para que gestione la exclusividad
      if (_isDefault) {
        await ref.read(accountsNotifierProvider.notifier).setDefaultAccount(account.id);
      }

      if (mounted) {
        showAppToast(context, message: 'Cuenta guardada', type: ToastType.success);
        Navigator.of(context).pop();
      }
    } catch (e) {
      _showError('Error al guardar: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    showAppToast(context, message: message, type: ToastType.error);
  }

  @override
  Widget build(BuildContext context) {
    final selectedAccount = ref.watch(selectedAccountProvider);
    final isEdit = selectedAccount != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currenciesAsync = ref.watch(currenciesProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppColors.radiusXLarge)),
            ),
            child: Column(
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(isEdit ? 'Editar Cuenta' : 'Nueva Cuenta', style: GoogleFonts.montserrat(fontSize: AppColors.titleMedium, fontWeight: FontWeight.w700)),
                      IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(context).pop()),
                    ],
                  ),
                ),
                Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[100]),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle('INFORMACIÓN BÁSICA', isDark),
                          const SizedBox(height: 12),
                          AppTextField(
                            label: 'Nombre de la cuenta',
                            controller: _nombreController,
                            hintText: 'Ej: Nómina, Ahorros, etc.',
                            prefixIcon: Icons.badge_outlined,
                            enabled: !_isLoading,
                            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                          ),
                          const SizedBox(height: 24),
                          _buildSectionTitle('TIPO DE CUENTA', isDark),
                          const SizedBox(height: 12),
                          _buildTipoSelector(isDark),
                          const SizedBox(height: 24),
                          _buildSectionTitle('CONFIGURACIÓN', isDark),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 2,
                                child: currenciesAsync.when(
                                  loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                  error: (_, __) => const Icon(Icons.error_outline),
                                  data: (currencies) => _buildCurrencyDropdown(currencies, isDark),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 3,
                                child: _buildBankSelectorInRow(context, isDark),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: Text('Establecer como cuenta por default', style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : AppColors.textPrimary)),
                            subtitle: Text('Esta cuenta se seleccionará automáticamente al crear transacciones.', style: GoogleFonts.montserrat(fontSize: 10, color: isDark ? Colors.white38 : Colors.grey[500])),
                            activeColor: AppColors.primary,
                            value: _isDefault,
                            onChanged: _isLoading ? null : (val) => setState(() => _isDefault = val),
                          ),
                          const SizedBox(height: 24),
                          _buildSectionTitle('DETALLE FINANCIERO', isDark),
                          const SizedBox(height: 16),
                          if (_selectedTipo == 'tarjeta_credito') ...[
                            _buildMontoField(label: 'Límite de crédito', controller: _limiteCreditoController, focusNode: _limiteCreditoFocusNode, icon: Icons.speed_rounded, isDark: isDark),
                            const SizedBox(height: 16),
                            _buildMontoField(label: 'Deuda actual', controller: _deudaActualController, focusNode: _deudaActualFocusNode, icon: Icons.credit_score_rounded, isDark: isDark),
                            const SizedBox(height: 12),
                            _buildInfoBox('Disponible: \$${((double.tryParse(_limiteCreditoController.text) ?? 0.0) - (double.tryParse(_deudaActualController.text) ?? 0.0)).toStringAsFixed(2)}', isDark),
                          ] else ...[
                            _buildMontoField(label: 'Saldo inicial', controller: _saldoInicialController, focusNode: _saldoInicialFocusNode, icon: Icons.account_balance_wallet_rounded, isDark: isDark),
                            const SizedBox(height: 12),
                            _buildInfoBox('Este monto se establecerá como tu saldo actual.', isDark, isHelp: true),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                _buildAdaptiveFooter(isDark),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(title, style: GoogleFonts.montserrat(fontSize: AppColors.bodySmall, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: isDark ? Colors.white38 : Colors.grey[500]));
  }

  Widget _buildTipoSelector(bool isDark) {
    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: AccountModel.tiposPermitidos.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final tipo = AccountModel.tiposPermitidos[index];
          final isSelected = _selectedTipo == tipo;
          return GestureDetector(
            onTap: _isLoading ? null : () => setState(() => _selectedTipo = tipo),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 100,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary.withOpacity(0.1) : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50]),
                borderRadius: BorderRadius.circular(AppColors.radiusMedium),
                border: Border.all(color: isSelected ? AppColors.primary : (isDark ? Colors.white10 : Colors.grey[200]!), width: isSelected ? 2 : 1),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_getTipoIcon(tipo), color: isSelected ? AppColors.primary : (isDark ? Colors.white30 : Colors.grey[400]), size: 28),
                  const SizedBox(height: 8),
                  Text(_formatTipoName(tipo), textAlign: TextAlign.center, style: GoogleFonts.montserrat(fontSize: 10, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? AppColors.primary : (isDark ? Colors.white54 : Colors.grey[600]))),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _getTipoIcon(String tipo) {
    switch (tipo) {
      case 'efectivo': return Icons.payments_rounded;
      case 'chequera': return Icons.account_balance_rounded;
      case 'ahorro': return Icons.savings_rounded;
      case 'tarjeta_credito': return Icons.credit_card_rounded;
      case 'inversion': return Icons.trending_up_rounded;
      default: return Icons.help_outline_rounded;
    }
  }

  String _formatTipoName(String tipo) {
    switch (tipo) {
      case 'tarjeta_credito': return 'T. Crédito';
      case 'ahorro': return 'Ahorro';
      case 'inversion': return 'Inversión';
      case 'chequera': return 'Débito';
      default: return tipo.isNotEmpty ? tipo[0].toUpperCase() + tipo.substring(1) : '';
    }
  }

  Widget _buildCurrencyDropdown(List<CurrencyModel> currencies, bool isDark) {
    if (_selectedMonedaId == null && currencies.isNotEmpty) {
      final mxn = currencies.firstWhere(
        (c) => c.codigo == 'MXN', 
        orElse: () => currencies.first,
      );
      _selectedMonedaId = mxn.id;
    }
    return DropdownButtonFormField<String>(
      value: _selectedMonedaId,
      decoration: _getInputDecoration('Moneda', Icons.currency_exchange_rounded, isDark),
      style: GoogleFonts.montserrat(fontSize: 13, color: isDark ? Colors.white : AppColors.textPrimary),
      dropdownColor: isDark ? AppColors.surfaceDark : Colors.white,
      items: currencies.map<DropdownMenuItem<String>>((c) => DropdownMenuItem(
        value: c.id, 
        child: Text(c.codigo),
      )).toList(),
      onChanged: _isLoading ? null : (v) => setState(() => _selectedMonedaId = v),
    );
  }

  Widget _buildBankSelectorInRow(BuildContext context, bool isDark) {
    final banksAsync = ref.watch(banksProvider('MX'));
    return banksAsync.when(
      loading: () => Container(height: 52, decoration: _getBoxDecoration(isDark), child: const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))),
      error: (_, __) => Container(height: 52, decoration: _getBoxDecoration(isDark), child: const Icon(Icons.error_outline)),
      data: (banks) => GestureDetector(
        onTap: _isLoading ? null : () => _showBankPicker(context, banks, isDark),
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: _getBoxDecoration(isDark),
          child: Row(
            children: [
              if (_selectedBank != null)
                ClipRRect(borderRadius: BorderRadius.circular(4), child: BankLogo(bankName: _selectedBank!.displayName, primaryColor: _selectedBank!.primaryColor, size: 20))
              else
                Icon(Icons.account_balance_rounded, size: 20, color: isDark ? Colors.white24 : Colors.grey[400]),
              const SizedBox(width: 8),
              Expanded(child: Text(_selectedBank?.displayName ?? 'Banco', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.montserrat(fontSize: 12, color: _selectedBank == null ? (isDark ? Colors.white24 : Colors.grey[500]) : (isDark ? Colors.white : AppColors.textPrimary)))),
              Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: isDark ? Colors.white24 : Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMontoField({required String label, required TextEditingController controller, required FocusNode focusNode, required IconData icon, required bool isDark}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          label: label,
          controller: controller,
          focusNode: focusNode,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          prefixIcon: icon,
          enabled: !_isLoading,
          onSubmitted: (_) {
            if (_calculatorResult.value != null) controller.text = _calculatorResult.value!.toStringAsFixed(2);
            focusNode.unfocus();
          },
        ),
        if (focusNode.hasFocus)
          ValueListenableBuilder<double?>(
            valueListenable: _calculatorResult,
            builder: (context, result, _) {
              if (result == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 8, left: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.calculate_outlined, size: 14, color: AppColors.success),
                    const SizedBox(width: 6),
                    Text('= ${_moneyFormatter.format(result)}', style: GoogleFonts.montserrat(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w700)),
                  ]),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildInfoBox(String text, bool isDark, {bool isHelp = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isHelp ? (isDark ? Colors.white.withOpacity(0.03) : Colors.grey[50]) : AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppColors.radiusMedium),
        border: Border.all(color: isHelp ? (isDark ? Colors.white10 : Colors.grey[200]!) : AppColors.primary.withOpacity(0.1)),
      ),
      child: Row(children: [
        Icon(isHelp ? Icons.info_outline_rounded : Icons.account_balance_wallet_outlined, size: 18, color: isHelp ? Colors.grey : AppColors.primary),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: GoogleFonts.montserrat(fontSize: 11, color: isDark ? Colors.white60 : Colors.grey[600]))),
      ]),
    );
  }

  InputDecoration _getInputDecoration(String label, IconData icon, bool isDark) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.montserrat(fontSize: 12, color: isDark ? Colors.white38 : Colors.grey[500]),
      filled: true,
      fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppColors.radiusMedium), borderSide: BorderSide.none),
      prefixIcon: Icon(icon, size: 18, color: isDark ? Colors.white38 : Colors.grey[500]),
    );
  }

  BoxDecoration _getBoxDecoration(bool isDark) {
    return BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100], borderRadius: BorderRadius.circular(AppColors.radiusMedium));
  }

  Widget _buildAdaptiveFooter(bool isDark) {
    if (_saldoInicialFocusNode.hasFocus || _limiteCreditoFocusNode.hasFocus || _deudaActualFocusNode.hasFocus) {
      return _buildCalculatorToolbar(isDark);
    }
    if (MediaQuery.of(context).viewInsets.bottom > 0) {
      return Container(
        padding: const EdgeInsets.all(12),
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(onPressed: () => FocusScope.of(context).unfocus(), child: const Text('Ocultar')),
            ElevatedButton(onPressed: () => FocusScope.of(context).nextFocus(), child: const Text('Siguiente')),
          ],
        ),
      );
    }
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(color: isDark ? AppColors.surfaceDark : Colors.white, border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.grey[100]!))),
      child: Row(
        children: [
          Expanded(child: AppButton(label: 'Cancelar', variant: 'secondary', onPressed: () => Navigator.of(context).pop())),
          const SizedBox(width: 12),
          Expanded(child: AppButton(label: (ref.read(selectedAccountProvider) != null) ? 'Actualizar' : 'Crear Cuenta', isLoading: _isLoading, onPressed: _handleSave)),
        ],
      ),
    );
  }

  Widget _buildCalculatorToolbar(bool isDark) {
    final operators = ['+', '-', '*', '/'];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.black12))),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            ...operators.map((op) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  onTap: () => _insertOperator(op),
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50], borderRadius: BorderRadius.circular(12)),
                    child: Text(op, style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  ),
                ),
              ),
            )),
            const SizedBox(width: 8),
            InkWell(
              onTap: () {
                final result = _calculatorResult.value;
                if (result != null) {
                  if (_saldoInicialFocusNode.hasFocus) _saldoInicialController.text = result.toStringAsFixed(2);
                  else if (_limiteCreditoFocusNode.hasFocus) _limiteCreditoController.text = result.toStringAsFixed(2);
                  else if (_deudaActualFocusNode.hasFocus) _deudaActualController.text = result.toStringAsFixed(2);
                }
                FocusScope.of(context).unfocus();
              },
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(Icons.check_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text('HECHO', style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBankPicker(BuildContext context, List<BankModel> banks, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(color: isDark ? AppColors.surfaceDark : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(AppColors.radiusXLarge))),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Bancos', style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w700)),
                    IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: banks.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.not_interested)),
                        title: const Text('Ninguno'),
                        onTap: () { setState(() => _selectedBank = null); Navigator.pop(context); },
                      );
                    }
                    final bank = banks[index - 1];
                    return ListTile(
                      leading: BankLogo(bankName: bank.displayName, primaryColor: bank.primaryColor, size: 40),
                      title: Text(bank.displayName),
                      onTap: () { setState(() => _selectedBank = bank); Navigator.pop(context); },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
