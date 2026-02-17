import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/utils/toast_utils.dart';
import '../../../../core/network/supabase_client.dart';
import '../../models/category_model.dart';
import '../providers/categories_provider.dart';

/// Lista extendida de nombres de ícono Material disponibles (30+)
const List<String> commonIconNames = [
  'label_outline',
  'restaurant_outlined',
  'shopping_cart_outlined',
  'directions_car_outlined',
  'home_outlined',
  'checkroom_outlined',
  'sports_esports_outlined',
  'fitness_center_outlined',
  'flight_outlined',
  'medical_services_outlined',
  'school_outlined',
  'work_outline',
  'account_balance_wallet_outlined',
  'payments_outlined',
  'credit_card_outlined',
  'trending_up',
  'card_giftcard_outlined',
  'sports_bar_outlined',
  'fastfood_outlined',
  'book_outlined',
  'content_cut_outlined',
  'pets_outlined',
  'local_florist_outlined',
  'sports_soccer_outlined',
  'umbrella_outlined',
  'water_drop_outlined',
  'directions_bus_outlined',
  'directions_bike_outlined',
  'train_outlined',
  'photo_camera_outlined',
  'music_note_outlined',
  'movie_outlined',
  'local_cafe_outlined',
  'local_pizza_outlined',
  'icecream_outlined',
  'laptop_outlined',
  'smartphone_outlined',
  'headset_outlined',
  'lightbulb_outline',
  'wifi',
  'network_wifi',
  'commute',
  'local_taxi',
  'subway',
  'house',
  'apartment',
  'cottage',
  'cleaning_services',
  'local_gas_station',
  'celebration',
  'event',
  'theater_comedy',
  'local_pharmacy',
  'medication',
  'receipt_long',
  'savings',
  'build',
  'brush',
  'camera_alt',
  'videogame_asset',
];

/// Mapeo de etiquetas en español para los íconos
const Map<String, List<String>> iconKeywords = {
  'wifi': ['wifi', 'internet', 'red', 'conexión', 'módem', 'wifo'],
  'network_wifi': ['wifi', 'internet', 'red', 'señal'],
  'restaurant_outlined': ['comida', 'restaurante', 'cenar', 'almuerzo', 'hambre', 'alim'],
  'fastfood_outlined': ['comida', 'hamburguesa', 'chatarra', 'rapida', 'antojo'],
  'local_cafe_outlined': ['cafe', 'starbucks', 'bebida', 'taza', 'desayuno'],
  'local_pizza_outlined': ['pizza', 'comida', 'italiana', 'antojo'],
  'directions_car_outlined': ['carro', 'coche', 'auto', 'transporte', 'gasolina', 'mantenimiento'],
  'local_gas_station': ['gasolina', 'combustible', 'pemex', 'coche', 'auto'],
  'directions_bus_outlined': ['bus', 'camion', 'transporte', 'publico', 'viaje'],
  'directions_bike_outlined': ['bici', 'bicicleta', 'ejercicio', 'transporte'],
  'commute': ['transporte', 'viaje', 'trabajo', 'movilidad', 'uber', 'didi'],
  'local_taxi': ['taxi', 'uber', 'didi', 'transporte', 'viaje'],
  'subway': ['metro', 'tren', 'transporte', 'subterraneo'],
  'home_outlined': ['casa', 'hogar', 'renta', 'vivienda', 'hipoteca'],
  'house': ['casa', 'hogar', 'renta', 'vivienda', 'propiedad'],
  'apartment': ['departamento', 'depa', 'renta', 'vivienda', 'edificio'],
  'cottage': ['vacaciones', 'casa', 'campo', 'descanso'],
  'cleaning_services': ['limpieza', 'aseo', 'casa', 'mantenimiento', 'servicio'],
  'shopping_cart_outlined': ['super', 'compras', 'mandado', 'mercado', 'tienda'],
  'checkroom_outlined': ['ropa', 'closet', 'vestimenta', 'moda', 'shopping'],
  'medical_services_outlined': ['doctor', 'salud', 'medico', 'hospital', 'seguro'],
  'local_pharmacy': ['farmacia', 'medicina', 'pastillas', 'salud'],
  'medication': ['medicina', 'pastillas', 'tratamiento', 'salud'],
  'fitness_center_outlined': ['gym', 'gimnasio', 'ejercicio', 'pesas', 'salud', 'deporte'],
  'sports_soccer_outlined': ['futbol', 'deporte', 'soccer', 'ejercicio', 'balon'],
  'celebration': ['fiesta', 'cumpleaños', 'evento', 'diversion', 'party'],
  'event': ['evento', 'calendario', 'cita', 'agenda'],
  'theater_comedy': ['cine', 'teatro', 'entretenimiento', 'diversion', 'ocio'],
  'sports_esports_outlined': ['juegos', 'consola', 'xbox', 'playstation', 'gaming', 'ocio'],
  'videogame_asset': ['videojuegos', 'control', 'gaming', 'ocio'],
  'account_balance_wallet_outlined': ['cartera', 'dinero', 'billetera', 'efectivo'],
  'payments_outlined': ['pago', 'dinero', 'billetes', 'efectivo', 'sueldo'],
  'savings': ['ahorro', 'alcancia', 'metas', 'guardar'],
  'receipt_long': ['factura', 'recibo', 'ticket', 'gasto', 'impuestos'],
  'school_outlined': ['escuela', 'colegio', 'universidad', 'estudio', 'clases', 'educacion'],
  'book_outlined': ['libro', 'lectura', 'estudio', 'educacion', 'cultura'],
  'work_outline': ['trabajo', 'oficina', 'empleo', 'negocio'],
  'lightbulb_outline': ['luz', 'electricidad', 'idea', 'energia', 'servicios'],
  'water_drop_outlined': ['agua', 'servicio', 'bebida', 'hidratacion'],
  'pets_outlined': ['perro', 'gato', 'mascota', 'animal', 'veterinario'],
  'build': ['herramientas', 'reparacion', 'mantenimiento', 'obra'],
  'brush': ['pintura', 'arte', 'decoracion', 'mantenimiento'],
  'camera_alt': ['fotos', 'camara', 'recuerdos', 'viaje'],
};

/// Widget bottom sheet deslizable para crear o editar una categoría.
/// Usa DraggableScrollableSheet para permitir redimensionamiento.
class CategoryFormBottomSheet extends ConsumerStatefulWidget {
  const CategoryFormBottomSheet({Key? key}) : super(key: key);

  @override
  ConsumerState<CategoryFormBottomSheet> createState() =>
      _CategoryFormBottomSheetState();
}

class _CategoryFormBottomSheetState
    extends ConsumerState<CategoryFormBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _iconSearchController = TextEditingController();

  String? _selectedTipo;
  String? _selectedIcono;
  Color? _selectedColor;
  bool _isLoading = false;
  List<String> _filteredIcons = commonIconNames;

  @override
  void initState() {
    super.initState();

    // Si hay una categoría seleccionada (modo edición), carga los datos
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final selectedCategory = ref.read(selectedCategoryProvider);
      if (selectedCategory != null) {
        _nombreController.text = selectedCategory.nombre;
        setState(() {
          _selectedTipo = selectedCategory.tipo;
          _selectedIcono = selectedCategory.icono;
          _selectedColor = _getColorFromHex(selectedCategory.color);
        });
      } else {
        // Modo creación: inicializa tipo como 'gasto' y color por defecto
        setState(() {
          _selectedTipo = 'gasto';
          _selectedIcono = 'label_outline';
          _selectedColor = AppColors.primary;
        });
      }
    });

    // Listener para filtrar íconos
    _iconSearchController.addListener(_filterIcons);
  }

  @override
  void dispose() {
    _iconSearchController.removeListener(_filterIcons);
    _nombreController.dispose();
    _iconSearchController.dispose();
    _formKey.currentState?.dispose(); // Opcional, pero formKey no tiene dispose generalmente
    super.dispose();
  }

  /// Filtra los íconos según el texto de búsqueda
  void _filterIcons() {
    final query = _iconSearchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredIcons = commonIconNames;
      } else {
        _filteredIcons = commonIconNames.where((icon) {
          // Buscar en el nombre del icono
          if (icon.toLowerCase().contains(query)) return true;
          
          // Buscar en las palabras clave en español
          final keywords = iconKeywords[icon];
          if (keywords != null) {
            return keywords.any((k) => k.toLowerCase().contains(query));
          }
          
          return false;
        }).toList();
      }
    });
  }

  /// Valida y guarda la categoría
  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Valida nombre
    if (_nombreController.text.trim().isEmpty) {
      showAppToast(context, 'El nombre es requerido', isError: true);
      return;
    }

    if (_selectedTipo == null || _selectedTipo!.isEmpty) {
      showAppToast(context, 'Por favor selecciona un tipo', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final selectedCategory = ref.read(selectedCategoryProvider);

      final category = CategoryModel(
        id: selectedCategory?.id ?? const Uuid().v4(),
        userId: supabaseClient.auth.currentUser!.id,
        nombre: _nombreController.text.trim(),
        tipo: _selectedTipo!,
        icono: _selectedIcono,
        color: _selectedColor != null ? _colorToHex(_selectedColor!) : null,
        createdAt: selectedCategory?.createdAt ?? DateTime.now(),
      );

      if (selectedCategory != null) {
        // Modo edición
        await ref.read(categoriesRepositoryProvider).updateCategory(category);
      } else {
        // Modo creación
        await ref.read(categoriesRepositoryProvider).createCategory(category);
      }

      if (mounted) {
        showAppToast(
          context,
          selectedCategory != null
              ? 'Categoría actualizada'
              : 'Categoría creada exitosamente',
          isError: false,
        );
        
        // Limpia la categoría seleccionada
        ref.read(selectedCategoryProvider.notifier).state = null;
        
        // Fuerza la actualización de las listas de categorías
        ref.invalidate(categoriesListProvider); // Invalida lista general de categorías
        ref.invalidate(incomeCategoriesProvider);
        ref.invalidate(expenseCategoriesProvider);
        
        Navigator.of(context).pop();
      }
    } catch (e) {
      showAppToast(context, 'Error al guardar: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Obtiene el ícono IconData a partir del nombre
  IconData _getIcon(String? iconName) {
    // Map de íconos de Material (compatibilidad con keys de ionicons existentes)
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
      
      // Compatibilidad v1
      'tag_outline': Icons.label_outline,
      'restaurant_outline': Icons.restaurant_outlined,
      'cart_outline': Icons.shopping_cart_outlined,
      'car_sport_outline': Icons.directions_car_outlined,
      'home_outline': Icons.home_outlined,
      'shirt_outline': Icons.checkroom_outlined,
      'game_controller_outline': Icons.sports_esports_outlined,
      'fitness_outline': Icons.fitness_center_outlined,
      'airplane_outline': Icons.flight_outlined,
      'medical_outline': Icons.medical_services_outlined,
      'school_outline': Icons.school_outlined,
      'briefcase_outline': Icons.work_outline,
      'pricetags_outline': Icons.label_outline,
      'wallet_outline': Icons.account_balance_wallet_outlined,
      'cash_outline': Icons.payments_outlined,
      'card_outline': Icons.credit_card_outlined,
      'trending_up_outline': Icons.trending_up,
      'gift_outline': Icons.card_giftcard_outlined,
      'beer_outline': Icons.sports_bar_outlined,
      'fast_food_outline': Icons.fastfood_outlined,
      'book_outline': Icons.book_outlined,
      'cut_outline': Icons.content_cut_outlined,
      'paw_outline': Icons.pets_outlined,
      'flower_outline': Icons.local_florist_outlined,
      'football_outline': Icons.sports_soccer_outlined,
      'umbrella_outline': Icons.umbrella_outlined,
      'water_outline': Icons.water_drop_outlined,
      'bus_outline': Icons.directions_bus_outlined,
      'bicycle_outline': Icons.directions_bike_outlined,
      'train_outline': Icons.train_outlined,
      'camera_outline': Icons.photo_camera_outlined,
      'musical_notes_outline': Icons.music_note_outlined,
      'film_outline': Icons.movie_outlined,
      'cafe_outline': Icons.local_cafe_outlined,
      'pizza_outline': Icons.local_pizza_outlined,
      'ice_cream_outline': Icons.icecream_outlined,
      'phone_portrait_outline': Icons.smartphone_outlined,
      'bulb_outline': Icons.lightbulb_outline,
      'wifi': Icons.wifi,
      'network_wifi': Icons.network_wifi,
      'commute': Icons.commute,
      'local_taxi': Icons.local_taxi,
      'subway': Icons.subway,
      'house': Icons.house,
      'apartment': Icons.apartment,
      'cottage': Icons.cottage,
      'cleaning_services': Icons.cleaning_services,
      'local_gas_station': Icons.local_gas_station,
      'celebration': Icons.celebration,
      'event': Icons.event,
      'theater_comedy': Icons.theater_comedy,
      'local_pharmacy': Icons.local_pharmacy,
      'medication': Icons.medication,
      'receipt_long': Icons.receipt_long,
      'savings': Icons.savings,
      'build': Icons.build,
      'brush': Icons.brush,
      'camera_alt': Icons.camera_alt,
      'videogame_asset': Icons.videogame_asset,
    };
    
    if (iconName == null || iconName.isEmpty) {
      return Icons.label_outline;
    }
    
    return iconMap[iconName] ?? Icons.label_outline;
  }

  /// Convierte un string hex a Color
  Color? _getColorFromHex(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) {
      return null;
    }
    
    try {
      final hexString = hexColor.replaceFirst('#', '');
      return Color(int.parse('FF$hexString', radix: 16));
    } catch (e) {
      return null;
    }
  }

  /// Convierte un Color a string hex
  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final isEdit = selectedCategory != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: () async {
        ref.read(selectedCategoryProvider.notifier).state = null;
        return true;
      },
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,  // Corrección: homologado con otros canvas
        minChildSize: 0.4,        // Corrección: reducido a 0.4
        maxChildSize: 0.85,       // Corrección: reducido a 0.85
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
              children: [
                // Header con título y botón cerrar
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEdit ? 'Editar categoría' : 'Nueva categoría',
                        style: GoogleFonts.montserrat(
                          fontSize: AppColors.titleSmall,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        color: isDark ? Colors.white70 : Colors.grey[700],
                        onPressed: () {
                          ref.read(selectedCategoryProvider.notifier).state = null;
                          Navigator.of(context).pop();
                        },
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
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Campo de nombre
                          AppTextField(
                            label: 'Nombre de la categoría',
                            controller: _nombreController,
                            prefixIcon: Icons.title_outlined,
                            enabled: !_isLoading,
                          ),
                          const SizedBox(height: 20),

                          // Tipo de categoría como "radio divs"
                          Text(
                            'Tipo',
                            style: GoogleFonts.montserrat(
                              fontSize: AppColors.bodyMedium,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTypeCard(
                                  'ingreso',
                                  'Ingreso',
                                  Icons.trending_up,
                                  isDark,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildTypeCard(
                                  'gasto',
                                  'Gasto',
                                  Icons.trending_down,
                                  isDark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Selector de color visual
                          Text(
                            'Color',
                            style: GoogleFonts.montserrat(
                              fontSize: AppColors.bodyMedium,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: AppColors.categoryColors.map((color) {
                              final isSelected = _selectedColor == color;
                              return GestureDetector(
                                onTap: _isLoading
                                    ? null
                                    : () {
                                        setState(() => _selectedColor = color);
                                      },
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? (isDark ? Colors.white : Colors.black)
                                          : Colors.transparent,
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: color.withOpacity(0.4),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: isSelected
                                      ? const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 24,
                                        )
                                      : null,
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 20),

                          // Buscador y selector de ícono
                          Text(
                            'Ícono',
                            style: GoogleFonts.montserrat(
                              fontSize: AppColors.bodyMedium,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _iconSearchController,
                            decoration: InputDecoration(
                              hintText: 'Buscar ícono...',
                              hintStyle: GoogleFonts.montserrat(fontSize: AppColors.bodyMedium),
                              prefixIcon: const Icon(Icons.search_outlined, size: 20),
                              filled: true,
                              fillColor: isDark ? AppColors.surfaceDark : Colors.grey[100],
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            enabled: !_isLoading,
                          ),
                          const SizedBox(height: 12),
                          
                          // Grid de íconos filtrados
                          Container(
                            height: 90,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.black12 : Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: GridView.builder(
                              padding: const EdgeInsets.all(8),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 6,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio: 1.0,
                              ),
                              itemCount: _filteredIcons.length,
                              itemBuilder: (context, index) {
                                final iconName = _filteredIcons[index];
                                final isSelected = _selectedIcono == iconName;
                                return GestureDetector(
                                  onTap: _isLoading
                                      ? null
                                      : () {
                                          setState(() => _selectedIcono = iconName);
                                        },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.primary.withOpacity(0.15)
                                          : (isDark ? Colors.white10 : Colors.white),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.primary
                                            : (isDark ? Colors.white10 : Colors.grey[300]!),
                                        width: isSelected ? 2 : 1,
                                      ),
                                    ),
                                    child: Icon(
                                      _getIcon(iconName),
                                      size: 24,
                                      color: isSelected
                                          ? AppColors.primary
                                          : (isDark ? Colors.white70 : Colors.grey[700]),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          
                          // Preview del ícono seleccionado
                          if (_selectedIcono != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white10 : Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _getIcon(_selectedIcono),
                                    size: 28,
                                    color: _selectedColor ?? AppColors.primary,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _selectedIcono!,
                                      style: GoogleFonts.montserrat(
                                        fontSize: AppColors.bodySmall,
                                        color: isDark ? Colors.white70 : Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Botones de acción (fijo inferior)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 120,
                        child: AppButton(
                          label: 'Cancelar',
                          onPressed: _isLoading
                              ? null
                              : () {
                                  ref.read(
                                      selectedCategoryProvider
                                          .notifier)
                                      .state = null;
                                  Navigator.of(context)
                                      .pop();
                                },
                          variant: 'secondary',
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 120,
                        child: AppButton(
                          label: 'Guardar',
                          onPressed:
                              _isLoading ? null : _handleSave,
                          isLoading: _isLoading,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Construye una tarjeta de tipo de categoría (Ingreso/Gasto)
  Widget _buildTypeCard(String value, String label, IconData icon, bool isDark) {
    final isSelected = _selectedTipo == value;
    return GestureDetector(
      onTap: _isLoading
          ? null
          : () {
              setState(() => _selectedTipo = value);
            },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.1)
              : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? Colors.white10 : Colors.grey[300]!),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected
                  ? AppColors.primary
                  : (isDark ? Colors.white70 : Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.montserrat(
                fontSize: AppColors.bodyMedium,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? Colors.white70 : Colors.grey[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
