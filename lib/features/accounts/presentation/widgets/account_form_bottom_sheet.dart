import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../providers/accounts_provider.dart';
import '../providers/banks_provider.dart';
import '../providers/currencies_provider.dart';

/// Widget bottom sheet deslizable para crear o editar una cuenta.
/// Usa DraggableScrollableSheet para permitir redimensionamiento.
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
          // Cargar banco si existe
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
        // Si no es edición, verifica si hay un banco preseleccionado desde el catálogo
        final preselectedBank = ref.read(selectedBankProvider);
        if (preselectedBank != null) {
          setState(() {
            _selectedBank = preselectedBank;
            // Limpiar el provider después de usarlo
            Future.microtask(() => ref.read(selectedBankProvider.notifier).state = null);
          });
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
      );

      if (selectedAccount != null) {
        // Modo edición
        await ref.read(accountsNotifierProvider.notifier).updateAccount(account);
      } else {
        // Modo creación
        final limiteCredito = double.tryParse(_limiteCreditoController.text);
        final deudaActual = double.tryParse(_deudaActualController.text) ?? 0.0;
        
        await ref.read(accountsNotifierProvider.notifier).createAccount(
          account,
          limiteCredito: _selectedTipo == 'tarjeta_credito' ? limiteCredito : null,
          deudaActual: _selectedTipo == 'tarjeta_credito' ? deudaActual : null,
        );
      }

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

    // Corrección: Usar DraggableScrollableSheet para homologar con otros canvas
    return DraggableScrollableSheet(
      initialChildSize: 0.85,  // Altura inicial
      minChildSize: 0.4,        // Altura mínima
      maxChildSize: 0.85,       // Altura máxima
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header con título y botón cerrar
              // Corrección: Padding homologado (horizontal 16, vertical 8)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEdit ? 'Editar cuenta' : 'Nueva cuenta',
                      style: GoogleFonts.montserrat(
                        fontSize: AppColors.titleSmall,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      color: isDark ? Colors.white70 : Colors.grey[700],
                      onPressed: () => Navigator.of(context).pop(),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              
              // Línea divisora
              Divider(
                height: 1,
                color: isDark ? Colors.white10 : Colors.grey[300],
              ),
              
              // Contenido con scroll
              Flexible(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Form(
                    key: _formKey,
                    child: Column(
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

                        // Dropdown de moneda
                        currenciesAsync.when(
                          loading: () => const Center(
                            child: CircularProgressIndicator(),
                          ),
                          error: (error, stack) => Text(
                            'Error al cargar monedas',
                            style: GoogleFonts.montserrat(
                              color: AppColors.secondary,
                            ),
                          ),
                          data: (currencies) {
                            // Si no hay moneda seleccionada y hay monedas disponibles, selecciona MXN por defecto
                            if (_selectedMonedaId == null && currencies.isNotEmpty) {
                              final mxn = currencies.firstWhere(
                                (c) => c.codigo == 'MXN',
                                orElse: () => currencies.first,
                              );
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

                        // Selector de banco de Belvo
                        _buildBankSelector(context, isDark),

                        const SizedBox(height: 16),

                        // Campos específicos para Tarjeta de Crédito
                        if (_selectedTipo == 'tarjeta_credito') ...[
                          Column(
                            children: [
                              AppTextField(
                                label: 'Límite de crédito',
                                controller: _limiteCreditoController,
                                focusNode: _limiteCreditoFocusNode,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                prefixIcon: Icons.speed_outlined,
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
                                prefixIcon: Icons.credit_score_outlined,
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
                              'El disponible será: \$${((double.tryParse(_limiteCreditoController.text) ?? 0.0) - (double.tryParse(_deudaActualController.text) ?? 0.0)).toStringAsFixed(2)}',
                              style: GoogleFonts.montserrat(
                                fontSize: AppColors.bodySmall,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Campo de saldo inicial (Ocultar si es TC para no confundir, se calcula de limite-deuda)
                        if (_selectedTipo != 'tarjeta_credito') ...[
                          Column(
                            children: [
                              AppTextField(
                                label: 'Saldo inicial',
                                controller: _saldoInicialController,
                                focusNode: _saldoInicialFocusNode,
                                keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
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
                          ),
                          const SizedBox(height: 8),

                          // Ayuda sobre el saldo
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
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              
              // Botones de acción o toolbar de calculadora
              _buildAdaptiveFooter(isDark),
            ],
          ),
        );
      },
    );
  }

  /// Construye el selector de banco usando banksProvider
  Widget _buildBankSelector(BuildContext context, bool isDark) {
    final banksAsync = ref.watch(banksProvider('MX'));

    return banksAsync.when(
      loading: () => _buildBankLoadingState(),
      error: (error, stack) => _buildBankErrorState(),
      data: (banks) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Banco (Opcional)',
            style: GoogleFonts.montserrat(
              fontSize: AppColors.bodyMedium,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.black12,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isLoading ? null : () => _showBankPicker(context, banks, isDark),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      if (_selectedBank?.logo != null)
                        Container(
                          width: 28,
                          height: 28,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                          child: BankLogo(
                            bankName: _selectedBank!.displayName,
                            primaryColor: _selectedBank!.primaryColor,
                            size: 28,
                          ),
                          ),
                        )
                      else
                        Container(
                          width: 28,
                          height: 28,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.account_balance_outlined,
                            size: 16,
                            color: AppColors.primary,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          _selectedBank?.displayName ?? 'Selecciona un banco',
                          style: GoogleFonts.montserrat(
                            fontSize: AppColors.bodyMedium,
                            color: _selectedBank == null
                                ? (isDark ? Colors.white38 : Colors.grey)
                                : (isDark ? Colors.white : Colors.black87),
                          ),
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_right, size: 20, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankLoadingState() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
    );
  }

  Widget _buildBankErrorState() {
    return Text(
      'No se pudieron cargar los bancos',
      style: GoogleFonts.montserrat(fontSize: AppColors.bodySmall, color: Colors.red),
    );
  }

  void _showBankPicker(BuildContext context, List<BankModel> banks, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Selecciona un banco',
                      style: GoogleFonts.montserrat(
                        fontSize: AppColors.titleSmall,
                        fontWeight: FontWeight.w600,
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
                child: banks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.account_balance_outlined,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No hay bancos disponibles',
                              style: GoogleFonts.montserrat(
                                fontSize: AppColors.bodyMedium,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 24),
                            ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Colors.grey,
                                child: Icon(Icons.not_interested, color: Colors.white, size: 20),
                              ),
                              title: Text('Ninguno', style: GoogleFonts.montserrat(fontWeight: FontWeight.w500)),
                              onTap: () {
                                setState(() => _selectedBank = null);
                                Navigator.pop(context);
                              },
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: banks.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Colors.grey,
                                child: Icon(Icons.not_interested, color: Colors.white, size: 20),
                              ),
                              title: Text('Ninguno', style: GoogleFonts.montserrat(fontWeight: FontWeight.w500)),
                              onTap: () {
                                setState(() => _selectedBank = null);
                                Navigator.pop(context);
                              },
                            );
                          }
                          
                          final bank = banks[index - 1];
                          return ListTile(
                            leading: BankLogo(
                              bankName: bank.displayName,
                              primaryColor: bank.primaryColor,
                              size: 36,
                            ),
                            title: Text(
                              bank.displayName,
                              style: GoogleFonts.montserrat(fontWeight: FontWeight.w500),
                            ),
                            onTap: () {
                              setState(() => _selectedBank = bank);
                              Navigator.pop(context);
                            },
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

  /// Formatea el nombre del tipo para mostrarlo mejor
  String _formatTipoName(String tipo) {
    switch (tipo) {
      case 'efectivo':
        return 'Efectivo';
      case 'chequera':
        return 'Cuenta de débito';
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
