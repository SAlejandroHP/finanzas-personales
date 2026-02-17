import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart' as intl;
import 'package:math_expressions/math_expressions.dart';
import 'package:collection/collection.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/services/finance_service.dart';
import '../../models/account_model.dart';
import '../../models/bank_model.dart';
import '../providers/accounts_provider.dart';
import '../providers/banks_provider.dart';
import '../providers/currencies_provider.dart';

/// Pantalla de formulario para crear o editar una cuenta.
class AccountFormScreen extends ConsumerStatefulWidget {
  const AccountFormScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AccountFormScreen> createState() => _AccountFormScreenState();
}

class _AccountFormScreenState extends ConsumerState<AccountFormScreen> {
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
    
    // Si hay una cuenta seleccionada (modo edición), carga los datos
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final selectedAccount = ref.read(selectedAccountProvider);
      if (selectedAccount != null) {
        _nombreController.text = selectedAccount.nombre;
        _saldoInicialController.text = selectedAccount.saldoInicial.toString();
        setState(() {
          _selectedTipo = selectedAccount.tipo;
          _selectedMonedaId = selectedAccount.monedaId;
          // Si es tarjeta de crédito, cargar los campos correspondientes (asumiendo que saldoInicial es el límite)
          if (_selectedTipo == 'tarjeta_credito') {
            _limiteCreditoController.text = selectedAccount.saldoInicial.toString();
            // La deuda actual es límite - disponible (saldoActual)
            _deudaActualController.text = (selectedAccount.saldoInicial - selectedAccount.saldoActual).toString();
          }
          
          // Crear un BankModel temporal si el banco existe
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

  Widget _buildAdaptiveFooter(bool isDark) {
    if (_saldoInicialFocusNode.hasFocus || _limiteCreditoFocusNode.hasFocus || _deudaActualFocusNode.hasFocus) {
      return _buildCalculatorToolbar(isDark);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: AppButton(
              label: 'Cancelar',
              variant: 'outlined',
              onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AppButton(
              label: (ref.read(selectedAccountProvider) != null) ? 'Actualizar' : 'Crear',
              isLoading: _isLoading,
              onPressed: _isLoading ? null : _handleSave,
            ),
          ),
        ],
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
                    child: Text(op, style: GoogleFonts.montserrat(fontSize: AppColors.titleMedium, fontWeight: FontWeight.w600, color: AppColors.primary)),
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
                    final focusNode = _saldoInicialFocusNode.hasFocus ? _saldoInicialFocusNode : 
                                     _limiteCreditoFocusNode.hasFocus ? _limiteCreditoFocusNode : 
                                     _deudaActualFocusNode;
                    final controller = _saldoInicialFocusNode.hasFocus ? _saldoInicialController : 
                                      _limiteCreditoFocusNode.hasFocus ? _limiteCreditoController : 
                                      _deudaActualController;
                    
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

  /// Valida y guarda la cuenta
  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedTipo == null) {
      _showError('Por favor selecciona un tipo de cuenta');
      return;
    }

    if (_selectedMonedaId == null) {
      _showError('Por favor selecciona una moneda');
      return;
    }

    // Validaciones adicionales para tarjeta de crédito
    if (_selectedTipo == 'tarjeta_credito') {
      if (_limiteCreditoController.text.isEmpty) {
        _showError('Por favor ingresa el límite de crédito');
        return;
      }
      final limiteCredito = double.tryParse(_limiteCreditoController.text);
      if (limiteCredito == null || limiteCredito <= 0) {
        _showError('El límite de crédito debe ser un número válido');
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final selectedAccount = ref.read(selectedAccountProvider);
      final saldoInicialField = double.tryParse(_saldoInicialController.text) ?? 0.0;
      
      // Para tarjeta de crédito, calcular saldo_actual = límite - deuda
      double? limiteCredito;
      double? deudaActual;
      double saldoFinal = saldoInicialField;
      
      if (_selectedTipo == 'tarjeta_credito') {
        limiteCredito = double.tryParse(_limiteCreditoController.text) ?? 0.0;
        deudaActual = double.tryParse(_deudaActualController.text) ?? 0.0;
        saldoFinal = limiteCredito - deudaActual;
      }

      final account = AccountModel(
        id: selectedAccount?.id ?? const Uuid().v4(),
        userId: supabaseClient.auth.currentUser!.id,
        nombre: _nombreController.text.trim(),
        tipo: _selectedTipo!,
        bancoId: _selectedBank?.id,
        bancoNombre: _selectedBank?.displayName,
        bancoLogo: _selectedBank?.logo,
        monedaId: _selectedMonedaId!,
        saldoInicial: _selectedTipo == 'tarjeta_credito' ? (limiteCredito ?? 0.0) : saldoInicialField,
        saldoActual: selectedAccount != null ? selectedAccount.saldoActual : saldoFinal,
        createdAt: selectedAccount?.createdAt ?? DateTime.now(),
        updatedAt: selectedAccount != null ? DateTime.now() : null,
      );

      if (selectedAccount != null) {
        // Modo edición
        await ref.read(accountsNotifierProvider.notifier).updateAccount(account);
      } else {
        // Modo creación
        if (_selectedTipo == 'tarjeta_credito' && limiteCredito != null && deudaActual != null) {
          // Pasar límite y deuda para que se cree la deuda correspondiente
          await ref.read(accountsNotifierProvider.notifier).createAccount(
            account,
            limiteCredito: limiteCredito,
            deudaActual: deudaActual,
          );
        } else {
          await ref.read(accountsNotifierProvider.notifier).createAccount(account);
        }
      }

      // FinanceService: coordina el refresco total después de la operación exitosa
      ref.read(financeServiceProvider).refreshAll(ref);

      if (mounted) {
        showAppToast(
          context,
          message: selectedAccount != null
              ? 'Cuenta actualizada'
              : 'Cuenta creada exitosamente',
          type: ToastType.success,
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      _showError('Error al guardar: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    showAppToast(
      context,
      message: message,
      type: ToastType.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedAccount = ref.watch(selectedAccountProvider);
    final isEdit = selectedAccount != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currenciesAsync = ref.watch(currenciesProvider);
    final banksAsync = ref.watch(banksProvider('MX'));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEdit ? 'Editar cuenta' : 'Nueva cuenta',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Campo de nombre
            AppTextField(
              label: 'Nombre de la cuenta',
              controller: _nombreController,
              prefixIcon: Icons.title_outlined,
              enabled: !_isLoading,
            ),
            const SizedBox(height: 16),

            // Dropdown de tipo
            DropdownButtonFormField<String>(
              value: _selectedTipo,
              decoration: InputDecoration(
                labelText: 'Tipo de cuenta',
                labelStyle: GoogleFonts.montserrat(fontSize: AppColors.bodyMedium),
                filled: true,
                fillColor: isDark ? AppColors.surfaceDark : Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.list_outlined),
              ),
              items: AccountModel.tiposPermitidos.map((tipo) {
                return DropdownMenuItem(
                  value: tipo,
                  child: Text(
                    _formatTipoName(tipo),
                    style: GoogleFonts.montserrat(fontSize: AppColors.bodyMedium),
                  ),
                );
              }).toList(),
              onChanged: _isLoading
                  ? null
                  : (value) {
                      setState(() => _selectedTipo = value);
                    },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Selecciona un tipo';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Selector de banco con logo
            banksAsync.when(
              loading: () => _buildBankLoadingState(),
              error: (error, stack) => _buildBankErrorState(isDark),
              data: (banks) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Banco (Opcional)',
                      style: GoogleFonts.montserrat(
                        fontSize: AppColors.bodyMedium,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceDark : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.withOpacity(0.2),
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _isLoading
                              ? null
                              : () => _showBankSelector(context, banks, isDark),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                if (_selectedBank?.logo != null)
                                  Container(
                                    width: 32,
                                    height: 32,
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.grey.withOpacity(0.3),
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Image.network(
                                      _selectedBank!.logo!,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => Icon(
                                        Icons.account_balance,
                                        size: 20,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    width: 32,
                                    height: 32,
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(
                                      Icons.account_balance_outlined,
                                      size: 18,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                Expanded(
                                  child: Text(
                                    _selectedBank?.displayName ??
                                        'Selecciona un banco',
                                    style: GoogleFonts.montserrat(
                                      fontSize: AppColors.bodyMedium,
                                      color: _selectedBank == null
                                          ? Colors.grey
                                          : (isDark ? Colors.white : Colors.black),
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.keyboard_arrow_down,
                                  color: Colors.grey,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),

            // Dropdown de moneda
            currenciesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Text(
                'Error al cargar monedas',
                style: GoogleFonts.montserrat(color: AppColors.secondary),
              ),
              data: (currencies) {
                // Si no hay moneda seleccionada y hay monedas disponibles, selecciona MXN por defecto
                if (_selectedMonedaId == null && currencies.isNotEmpty) {
                  final mxn = currencies.firstWhereOrNull(
                    (c) => c.codigo == 'MXN',
                  ) ?? currencies.first;
                  _selectedMonedaId = mxn.id;
                }

                return DropdownButtonFormField<String>(
                  value: _selectedMonedaId,
                  decoration: InputDecoration(
                    labelText: 'Moneda',
                    labelStyle: GoogleFonts.montserrat(fontSize: AppColors.bodyMedium),
                    filled: true,
                    fillColor: isDark ? AppColors.surfaceDark : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.payments_outlined),
                  ),
                  items: currencies.map((currency) {
                    return DropdownMenuItem(
                      value: currency.id,
                      child: Text(
                        '${currency.codigo} - ${currency.nombre}',
                        style: GoogleFonts.montserrat(fontSize: AppColors.bodyMedium),
                      ),
                    );
                  }).toList(),
                  onChanged: _isLoading
                      ? null
                      : (value) {
                          setState(() => _selectedMonedaId = value);
                        },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Selecciona una moneda';
                    }
                    return null;
                  },
                );
              },
            ),
            const SizedBox(height: 16),

            // Campos específicos para tarjeta de crédito
            if (_selectedTipo == 'tarjeta_credito') ...[
              Column(
                children: [
                  AppTextField(
                    label: 'Límite de crédito',
                    controller: _limiteCreditoController,
                    focusNode: _limiteCreditoFocusNode,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    prefixIcon: Icons.credit_card_outlined,
                    enabled: !_isLoading,
                    onSubmitted: (_) {
                      if (_calculatorResult.value != null) {
                        _limiteCreditoController.text = _calculatorResult.value!.toStringAsFixed(2);
                      }
                      _limiteCreditoFocusNode.unfocus();
                    },
                  ),
                  if (_limiteCreditoFocusNode.hasFocus)
                    ValueListenableBuilder<double?>(
                      valueListenable: _calculatorResult,
                      builder: (context, result, _) {
                        if (result == null) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('= ${_moneyFormatter.format(result)}', style: GoogleFonts.montserrat(fontSize: AppColors.bodySmall, color: Colors.green, fontWeight: FontWeight.w600)),
                        );
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              
              Column(
                children: [
                  AppTextField(
                    label: 'Deuda actual / Monto utilizado',
                    controller: _deudaActualController,
                    focusNode: _deudaActualFocusNode,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    prefixIcon: Icons.trending_down_outlined,
                    enabled: !_isLoading,
                    onSubmitted: (_) {
                      if (_calculatorResult.value != null) {
                        _deudaActualController.text = _calculatorResult.value!.toStringAsFixed(2);
                      }
                      _deudaActualFocusNode.unfocus();
                    },
                  ),
                  if (_deudaActualFocusNode.hasFocus)
                    ValueListenableBuilder<double?>(
                      valueListenable: _calculatorResult,
                      builder: (context, result, _) {
                        if (result == null) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('= ${_moneyFormatter.format(result)}', style: GoogleFonts.montserrat(fontSize: AppColors.bodySmall, color: Colors.green, fontWeight: FontWeight.w600)),
                        );
                      },
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Ej. \$7,000 MXN (default: \$0)',
                  style: GoogleFonts.montserrat(
                    fontSize: AppColors.bodySmall,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  'El saldo disponible será: límite - deuda actual',
                  style: GoogleFonts.montserrat(
                    fontSize: AppColors.bodySmall,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Campo de saldo inicial (solo para cuentas que no sean crédito)
            if (_selectedTipo != 'tarjeta_credito')
              Column(
                children: [
                  AppTextField(
                    label: 'Saldo inicial',
                    controller: _saldoInicialController,
                    focusNode: _saldoInicialFocusNode,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    prefixIcon: Icons.account_balance_wallet_outlined,
                    enabled: !_isLoading,
                    onSubmitted: (_) {
                      if (_calculatorResult.value != null) {
                        _saldoInicialController.text = _calculatorResult.value!.toStringAsFixed(2);
                      }
                      _saldoInicialFocusNode.unfocus();
                    },
                  ),
                  if (_saldoInicialFocusNode.hasFocus)
                    ValueListenableBuilder<double?>(
                      valueListenable: _calculatorResult,
                      builder: (context, result, _) {
                        if (result == null) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('= ${_moneyFormatter.format(result)}', style: GoogleFonts.montserrat(fontSize: AppColors.bodySmall, color: Colors.green, fontWeight: FontWeight.w600)),
                        );
                      },
                    ),
                ],
              )
            else
              // Para tarjetas de crédito, mostrar el saldo disponible calculado
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Saldo disponible (calculado)',
                    style: GoogleFonts.montserrat(
                      fontSize: AppColors.bodyMedium,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey.withOpacity(0.2),
                      ),
                    ),
                    child: Text(
                      _moneyFormatter.format((double.tryParse(_limiteCreditoController.text) ?? 0.0) - (double.tryParse(_deudaActualController.text) ?? 0.0)),
                      style: GoogleFonts.montserrat(
                        fontSize: AppColors.bodyLarge,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            
            // Ayuda sobre el saldo (solo para cuentas normales)
            if (_selectedTipo != 'tarjeta_credito')
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'El saldo inicial se establecerá como saldo actual al crear la cuenta',
                  style: GoogleFonts.montserrat(
                    fontSize: AppColors.bodySmall,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            const SizedBox(height: 32),

            // Botones de acción o toolbar de calculadora
            _buildAdaptiveFooter(isDark),
          ],
        ),
      ),
    );
  }

  /// Construye el estado de carga para los bancos
  Widget _buildBankLoadingState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          Expanded(
            child: Container(
              height: 16,
              color: Colors.grey.withOpacity(0.2),
            ),
          ),
        ],
      ),
    );
  }

  /// Construye el estado de error para los bancos
  Widget _buildBankErrorState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        'No se pudieron cargar los bancos',
        style: GoogleFonts.montserrat(
          fontSize: AppColors.bodySmall,
          color: Colors.red,
        ),
      ),
    );
  }

  /// Muestra un diálogo para seleccionar banco
  void _showBankSelector(
    BuildContext context,
    List<BankModel> banks,
    bool isDark,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Selecciona un banco',
                      style: GoogleFonts.montserrat(
                        fontSize: AppColors.bodyLarge,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: banks.length,
                  itemBuilder: (context, index) {
                    final bank = banks[index];
                    final isSelected = _selectedBank?.id == bank.id;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: isSelected
                          ? AppColors.primary.withOpacity(0.1)
                          : Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.grey.withOpacity(0.2),
                        ),
                      ),
                      child: ListTile(
                        onTap: () {
                          setState(() => _selectedBank = bank);
                          Navigator.pop(context);
                        },
                        leading: bank.logo != null
                            ? Container(
                                width: 40,
                                height: 40,
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.withOpacity(0.2),
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Image.network(
                                  bank.logo!,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => Icon(
                                    Icons.account_balance,
                                    color: AppColors.primary,
                                  ),
                                ),
                              )
                            : Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.account_balance_outlined,
                                  color: AppColors.primary,
                                ),
                              ),
                        title: Text(
                          bank.displayName,
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          bank.name,
                          style: GoogleFonts.montserrat(fontSize: AppColors.bodySmall),
                        ),
                        trailing: isSelected
                            ? Icon(
                                Icons.check_circle,
                                color: AppColors.primary,
                              )
                            : null,
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: AppButton(
                  label: 'Sin banco (Otra institución)',
                  variant: 'outlined',
                  onPressed: () {
                    setState(() => _selectedBank = null);
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Formatea el nombre del tipo para mostrarlo mejor
  String _formatTipoName(String tipo) {
    switch (tipo) {
      case 'efectivo':
        return 'Efectivo';
      case 'chequera':
        return 'Cuenta de cheques';
      case 'ahorro':
        return 'Cuenta de ahorro';
      case 'tarjeta_credito':
        return 'Tarjeta de crédito';
      case 'inversion':
        return 'Inversión';
      case 'otro':
        return 'Otro';
      default:
        return tipo;
    }
  }
}
