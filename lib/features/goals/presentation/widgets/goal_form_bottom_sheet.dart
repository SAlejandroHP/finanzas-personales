import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/finance_service.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_toast.dart';
import '../providers/goals_provider.dart';
import '../../models/goal_model.dart';

class GoalFormBottomSheet extends ConsumerStatefulWidget {
  final GoalModel? goal;

  const GoalFormBottomSheet({Key? key, this.goal}) : super(key: key);

  @override
  ConsumerState<GoalFormBottomSheet> createState() => _GoalFormBottomSheetState();
}

class _GoalFormBottomSheetState extends ConsumerState<GoalFormBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _amountController;
  late TextEditingController _descriptionController;
  late TextEditingController _sharedEmailController;
  final _titleFocusNode = FocusNode();
  final _amountFocusNode = FocusNode();
  final _descriptionFocusNode = FocusNode();
  final _sharedEmailFocusNode = FocusNode();
  
  DateTime? _selectedDeadline;
  String _selectedIcon = 'savings';
  String _selectedColorHex = '#0A7075';
  
  bool _isShared = false;
  String _selectedPermission = 'view';

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.goal?.title);
    // Formatear monto inicial sin decimales innecesarios para el input
    final amountText = widget.goal?.targetAmount != null 
        ? (widget.goal!.targetAmount % 1 == 0 
            ? widget.goal!.targetAmount.toInt().toString() 
            : widget.goal!.targetAmount.toString())
        : '';
    _amountController = TextEditingController(text: amountText);
    _descriptionController = TextEditingController(text: widget.goal?.description);
    _sharedEmailController = TextEditingController(text: widget.goal?.sharedWithEmail);
    
    _selectedDeadline = widget.goal?.deadline;
    _selectedIcon = widget.goal?.icon ?? 'savings';
    _selectedColorHex = widget.goal?.colorHex ?? '#0A7075';
    
    _isShared = widget.goal?.isShared ?? false;
    _selectedPermission = widget.goal?.sharedPermission ?? 'view';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _sharedEmailController.dispose();
    _titleFocusNode.dispose();
    _amountFocusNode.dispose();
    _descriptionFocusNode.dispose();
    _sharedEmailFocusNode.dispose();
    super.dispose();
  }

  Future<void> _selectDeadline() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDeadline ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 10)),
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

    if (pickedDate != null) {
      setState(() {
        _selectedDeadline = pickedDate;
      });
    }
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Validación de correo al compartir
    if (_isShared) {
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(_sharedEmailController.text.trim())) {
        showAppToast(context, message: 'Ingresa un correo válido', type: ToastType.error);
        return;
      }
    }

    final title = _titleController.text.trim();
    final amount = double.tryParse(_amountController.text) ?? 0;
    final description = _descriptionController.text.trim();

    final goal = widget.goal?.copyWith(
      title: title,
      targetAmount: amount,
      description: description,
      deadline: _selectedDeadline,
      icon: _selectedIcon,
      colorHex: _selectedColorHex,
      updatedAt: DateTime.now(),
      isShared: _isShared,
      sharedWithEmail: _isShared ? _sharedEmailController.text.trim() : null,
      sharedPermission: _selectedPermission,
    ) ?? GoalModel(
      id: const Uuid().v4(),
      userId: '', // Se asigna en repo
      title: title,
      targetAmount: amount,
      currentAmount: 0,
      description: description,
      deadline: _selectedDeadline,
      icon: _selectedIcon,
      colorHex: _selectedColorHex,
      createdAt: DateTime.now(),
      isShared: _isShared,
      sharedId: _isShared ? const Uuid().v4() : null,
      sharedWithEmail: _isShared ? _sharedEmailController.text.trim() : null,
      sharedPermission: _selectedPermission,
    );

    try {
      if (widget.goal == null) {
        await ref.read(goalsNotifierProvider.notifier).createGoal(goal);
      } else {
        await ref.read(goalsNotifierProvider.notifier).updateGoal(goal);
      }
      
      if (mounted) {
        showAppToast(context, message: 'Meta guardada', type: ToastType.success);
        Navigator.pop(context);
      }
      
      // Refrescar después del pop
      Future.delayed(const Duration(milliseconds: 300), () {
        if (ref.context.mounted) {
          ref.read(financeServiceProvider).refreshAll();
        }
      });
    } catch (e) {
      if (mounted) {
         showAppToast(context, message: 'Error al guardar meta', type: ToastType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.surfaceDark : Colors.white;
    
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppColors.radiusXLarge)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40, height: 4, 
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12, 
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header con botón cerrar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.goal == null ? 'Nueva Meta' : 'Editar Meta',
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

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('IDENTIDAD DE LA META', isDark),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: _showIconPicker,
                            child: Container(
                              height: 56, width: 56,
                              decoration: BoxDecoration(
                                color: Color(int.parse(_selectedColorHex.replaceFirst('#', '0xFF'))).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(AppColors.radiusMedium),
                                border: Border.all(
                                  color: Color(int.parse(_selectedColorHex.replaceFirst('#', '0xFF'))).withOpacity(0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: Icon(
                                _getIconData(_selectedIcon),
                                color: Color(int.parse(_selectedColorHex.replaceFirst('#', '0xFF'))),
                                size: 28,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppTextField(
                              label: 'NOMBRE DE LA META',
                              controller: _titleController,
                              focusNode: _titleFocusNode,
                              hintText: 'Ej: Viaje a Japón, Auto nuevo...',
                              textCapitalization: TextCapitalization.sentences,
                              validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      AppTextField(
                        label: 'MONTO OBJETIVO',
                        controller: _amountController,
                        focusNode: _amountFocusNode,
                        prefixIcon: Icons.attach_money_rounded,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        hintText: '0.00',
                        validator: (v) => v == null || v.isEmpty ? 'Ingresa un monto' : null,
                      ),
                      const SizedBox(height: 24),

                      _buildSectionHeader('DETALLES Y TIEMPO', isDark),
                      const SizedBox(height: 12),
                      _buildSelectorTile(
                        label: 'LOGRAR ANTES DE',
                        value: _selectedDeadline == null 
                            ? 'Opcional' 
                            : DateFormat('dd MMMM yyyy', 'es').format(_selectedDeadline!),
                        icon: Icons.calendar_today_rounded,
                        onTap: _selectDeadline,
                        isDark: isDark,
                        trailing: _selectedDeadline != null 
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () => setState(() => _selectedDeadline = null),
                              visualDensity: VisualDensity.compact,
                            )
                          : null,
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        label: 'DESCRIPCIÓN',
                        controller: _descriptionController,
                        focusNode: _descriptionFocusNode,
                        prefixIcon: Icons.description_outlined,
                        hintText: '¿Por qué quieres lograr esta meta?',
                        maxLines: 2,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 24),

                      _buildSectionHeader('COLOR REPRESENTATIVO', isDark),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 48,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: AppColors.categoryColors.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final color = AppColors.categoryColors[index];
                            final hex = '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
                            final isSelected = _selectedColorHex == hex;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedColorHex = hex),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 44,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? (isDark ? Colors.white : Colors.black) : Colors.transparent,
                                    width: 3,
                                  ),
                                  boxShadow: isSelected ? [
                                    BoxShadow(color: color.withOpacity(0.4), blurRadius: 10, spreadRadius: 2)
                                  ] : null,
                                ),
                                child: isSelected ? Icon(Icons.check_rounded, color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white, size: 20) : null,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      _buildSectionHeader('COLABORACIÓN (OPCIONAL)', isDark),
                      const SizedBox(height: 8),
                      // Switch para compartir
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Compartir Meta',
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          'Invita a alguien a colaborar en esta meta',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.grey[600],
                          ),
                        ),
                        activeColor: AppColors.primary,
                        value: _isShared,
                        onChanged: (bool value) {
                          setState(() {
                            _isShared = value;
                            if (value && widget.goal?.sharedId == null) {
                               // No hacemos nada especial aquí, el ID se crea al guardar
                            }
                          });
                        },
                      ),
                      
                      // Campos que se muestran cuando está compartido
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: _isShared ? Padding(
                          padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppTextField(
                                label: 'CORREO DEL INVITADO',
                                controller: _sharedEmailController,
                                focusNode: _sharedEmailFocusNode,
                                keyboardType: TextInputType.emailAddress,
                                prefixIcon: Icons.email_outlined,
                                hintText: 'ejemplo@correo.com',
                              ),
                              const SizedBox(height: 16),
                              
                              Text(
                                'PERMISOS DEL INVITADO',
                                style: GoogleFonts.montserrat(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                  color: isDark ? Colors.white38 : Colors.grey[500],
                                ),
                              ),
                              const SizedBox(height: 8),
                              
                              // Dropdown de permisos usando decoraciones similares a la vista
                              Container(
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
                                  borderRadius: BorderRadius.circular(AppColors.radiusMedium),
                                  border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!, width: 1),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: ButtonTheme(
                                    alignedDropdown: true,
                                    child: DropdownButton<String>(
                                      value: _selectedPermission,
                                      isExpanded: true,
                                      icon: Icon(Icons.arrow_drop_down, color: isDark ? Colors.white70 : Colors.grey[600]),
                                      elevation: 0,
                                      dropdownColor: isDark ? AppColors.surfaceDark : Colors.white,
                                      style: GoogleFonts.montserrat(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: isDark ? Colors.white : AppColors.textPrimary,
                                      ),
                                      onChanged: (String? newValue) {
                                        if (newValue != null) {
                                          setState(() => _selectedPermission = newValue);
                                        }
                                      },
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'view',
                                          child: Text('Solo lectura (ver progreso)'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'contribute',
                                          child: Text('Contribuidor (hacer abonos)'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'edit',
                                          child: Text('Editor (editar datos y abonar)'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ) : const SizedBox(height: 0),
                      ),
                      
                      const SizedBox(height: 32),
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
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: GoogleFonts.montserrat(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: isDark ? Colors.white38 : Colors.grey[500],
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
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppColors.radiusMedium),
      child: Container(
        padding: const EdgeInsets.all(AppColors.md),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
          borderRadius: BorderRadius.circular(AppColors.radiusMedium),
          border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!, width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: isDark ? Colors.white70 : AppColors.textPrimary.withOpacity(0.8), size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: GoogleFonts.montserrat(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
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
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing,
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: Colors.grey[400], size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAdaptiveFooter(bool isDark) {
    if (MediaQuery.of(context).viewInsets.bottom > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? Colors.white10 : Colors.grey[100]!,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AppButton(
              label: 'Ocultar teclado',
              variant: 'outlined',
              height: 40,
              onPressed: () => FocusScope.of(context).unfocus(),
            ),
            AppButton(
              label: 'Siguiente',
              variant: 'primary',
              height: 40,
              onPressed: () => FocusScope.of(context).nextFocus(),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : Colors.grey[100]!,
          ),
        ),
      ),
      child: AppButton(
        label: widget.goal != null ? 'ACTUALIZAR META' : 'CREAR META',
        onPressed: _save,
        isFullWidth: true,
      ),
    );
  }

  void _showIconPicker() {
    final icons = [
      {'val': 'savings', 'icon': Icons.savings_outlined},
      {'val': 'flight', 'icon': Icons.flight_takeoff},
      {'val': 'home', 'icon': Icons.home_outlined},
      {'val': 'car', 'icon': Icons.directions_car_outlined},
      {'val': 'laptop', 'icon': Icons.laptop_mac_outlined},
      {'val': 'beach', 'icon': Icons.beach_access_outlined},
      {'val': 'gift', 'icon': Icons.card_giftcard_outlined},
      {'val': 'star', 'icon': Icons.star_border},
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: GridView.builder(
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 10, crossAxisSpacing: 10),
          itemCount: icons.length,
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () {
                setState(() => _selectedIcon = icons[index]['val'] as String);
                Navigator.pop(context);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: _selectedIcon == icons[index]['val'] ? AppColors.primary.withOpacity(0.1) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icons[index]['icon'] as IconData, color: _selectedIcon == icons[index]['val'] ? AppColors.primary : Colors.grey[600]),
              ),
            );
          },
        ),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'savings': return Icons.savings_outlined;
      case 'flight': return Icons.flight_takeoff;
      case 'home': return Icons.home_outlined;
      case 'car': return Icons.directions_car_outlined;
      case 'laptop': return Icons.laptop_mac_outlined;
      case 'beach': return Icons.beach_access_outlined;
      case 'gift': return Icons.card_giftcard_outlined;
      default: return Icons.star_border;
    }
  }
}
