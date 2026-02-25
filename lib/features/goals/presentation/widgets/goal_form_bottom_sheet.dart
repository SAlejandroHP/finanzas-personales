import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
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
  DateTime? _selectedDeadline;
  String _selectedIcon = 'savings';
  String _selectedColorHex = '#0A7075';

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
    _selectedDeadline = widget.goal?.deadline;
    _selectedIcon = widget.goal?.icon ?? 'savings';
    _selectedColorHex = widget.goal?.colorHex ?? '#0A7075';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
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
    );

    try {
      if (widget.goal == null) {
        await ref.read(goalsNotifierProvider.notifier).createGoal(goal);
      } else {
        await ref.read(goalsNotifierProvider.notifier).updateGoal(goal);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      // Manejo de error
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    
    return Container(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 12, 
        bottom: 20 + bottomInset,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4, 
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.goal == null ? 'Nueva Meta' : 'Editar Meta',
                style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 24),
              
              // Icono y Título
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: _showIconPicker,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Color(int.parse(_selectedColorHex.replaceFirst('#', '0xFF'))).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Color(int.parse(_selectedColorHex.replaceFirst('#', '0xFF'))).withOpacity(0.3)),
                      ),
                      child: Icon(
                        _getIconData(_selectedIcon),
                        color: Color(int.parse(_selectedColorHex.replaceFirst('#', '0xFF'))),
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _titleController,
                      style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        labelText: 'Nombre de la Meta',
                        hintText: 'Ej: Viaje a Japón, Auto nuevo...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Monto Objetivo
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 18),
                decoration: InputDecoration(
                  labelText: 'Monto Objetivo',
                  prefixIcon: const Icon(Icons.attach_money),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                ),
                validator: (v) => v == null || v.isEmpty ? 'Ingresa un monto' : null,
              ),
              const SizedBox(height: 16),

              // Fecha Límite
              GestureDetector(
                onTap: _selectDeadline,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_outlined, color: AppColors.primary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedDeadline == null ? '¿Tienes una fecha límite?' : 'Lograr antes de: ${DateFormat('dd MMMM yyyy').format(_selectedDeadline!)}',
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            fontWeight: _selectedDeadline != null ? FontWeight.w600 : FontWeight.w400,
                            color: _selectedDeadline != null ? AppColors.textPrimary : AppColors.description,
                          ),
                        ),
                      ),
                      if (_selectedDeadline != null)
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setState(() => _selectedDeadline = null),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Color Picker (Simple)
              Text(
                'Color representativo',
                style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.description),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: AppColors.categoryColors.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final color = AppColors.categoryColors[index];
                    final hex = '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
                    final isSelected = _selectedColorHex == hex;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColorHex = hex),
                      child: Container(
                        width: 44,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected ? Border.all(color: Colors.black, width: 3) : null,
                          boxShadow: [
                            if (isSelected)
                              BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, spreadRadius: 2),
                          ],
                        ),
                        child: isSelected ? const Icon(Icons.check, color: Colors.white) : null,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              
              // Botón Guardar
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                  ),
                  child: Text(
                    widget.goal == null ? 'CREAR META' : 'ACTUALIZAR META',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 1.1),
                  ),
                ),
              ),
            ],
          ),
        ),
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
