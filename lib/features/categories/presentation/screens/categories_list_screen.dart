import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/ui_provider.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../providers/categories_provider.dart';
import '../widgets/category_card.dart';
import '../widgets/category_form_bottom_sheet.dart';

/// Pantalla que muestra la lista de categorías del usuario en formato de rejilla creativa.
class CategoriesListScreen extends ConsumerWidget {
  const CategoriesListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.backgroundDark : AppColors.backgroundColor;
    final typeFilter = ref.watch(categoryTypeFilterProvider);
    
    final categoriesAsync = typeFilter == 'ingreso'
        ? ref.watch(incomeCategoriesProvider)
        : ref.watch(expenseCategoriesProvider);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Mis Categorías',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: isDark ? Colors.white : AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_rounded, size: 20, color: AppColors.primary),
              ),
              onPressed: () => _showCategoryForm(context, ref: ref),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Selector de Tipo Premium (Tab Alternativo)
          Container(
            margin: const EdgeInsets.fromLTRB(AppColors.pagePadding, 8, AppColors.pagePadding, 16),
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                _buildTabItem(context, ref, 'ingreso', 'Ingresos', typeFilter == 'ingreso'),
                _buildTabItem(context, ref, 'gasto', 'Gastos', typeFilter == 'gasto'),
              ],
            ),
          ),

          // Buscador Rápido (Estilo Premium)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppColors.pagePadding, vertical: 0),
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  if (!isDark)
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                ],
              ),
              child: TextField(
                onChanged: (value) => ref.read(categorySearchQueryProvider.notifier).state = value,
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre...',
                  hintStyle: GoogleFonts.montserrat(
                    fontSize: 14,
                    color: Colors.grey[400],
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: isDark ? Colors.white38 : Colors.grey[400],
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  suffixIcon: ref.watch(categorySearchQueryProvider).isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () => ref.read(categorySearchQueryProvider.notifier).state = '',
                        )
                      : null,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          Expanded(
            child: categoriesAsync.when(
              loading: () => const Center(child: LoadingIndicator()),
              error: (error, stack) => _buildErrorState(context, ref, error.toString(), isDark),
              data: (categories) {
                final query = ref.watch(categorySearchQueryProvider).toLowerCase();
                final filteredCategories = categories.where((c) {
                  return c.nombre.toLowerCase().contains(query);
                }).toList();

                if (filteredCategories.isEmpty) {
                  return _buildEmptyState(context, isDark, typeFilter, isSearch: query.isNotEmpty);
                }

                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.95,
                  ),
                  itemCount: filteredCategories.length,
                  itemBuilder: (context, index) {
                    final category = filteredCategories[index];
                    return CategoryCard(
                      category: category,
                      onEdit: () {
                        ref.read(selectedCategoryProvider.notifier).state = category;
                        _showCategoryForm(context, ref: ref);
                      },
                      onDelete: () async {
                        final confirm = await _showDeleteDialog(context, category.nombre);
                        if (confirm && context.mounted) {
                          _handleDelete(context, ref, category.id);
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(BuildContext context, WidgetRef ref, String type, String label, bool isSelected) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Expanded(
      child: GestureDetector(
        onTap: () => ref.read(categoryTypeFilterProvider.notifier).state = type,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: isSelected 
                ? (isDark ? AppColors.primary.withOpacity(0.9) : Colors.white) 
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              if (isSelected && !isDark)
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected 
                  ? (isDark ? Colors.white : AppColors.primary)
                  : (isDark ? Colors.white38 : Colors.grey[500]),
              letterSpacing: -0.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark, String type, {bool isSearch = false}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20), // Squircle
            ),
            child: Icon(
              isSearch ? Icons.search_off_rounded : Icons.label_important_rounded,
              size: 48,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isSearch ? 'Sin coincidencias' : 'Aún no hay categorías',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: isDark ? Colors.white : AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isSearch 
              ? 'Prueba con otros términos de búsqueda'
              : 'Organiza tus ${type == 'ingreso' ? 'ingresos' : 'gastos'} hoy',
            style: GoogleFonts.montserrat(
              color: Colors.grey,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, String error, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, size: 64, color: Colors.redAccent),
          const SizedBox(height: 16),
          Text(
            'Error al cargar categorías',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: AppColors.bodyLarge),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(color: Colors.grey, fontSize: AppColors.bodySmall),
            ),
          ),
        ],
      ),
    );
  }

  void _showCategoryForm(BuildContext context, {required WidgetRef ref}) {
    ref.read(isCanvasOpenProvider.notifier).state = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => const CategoryFormBottomSheet(),
    ).then((_) {
      ref.read(isCanvasOpenProvider.notifier).state = false;
      ref.read(selectedCategoryProvider.notifier).state = null;
    });
  }

  Future<bool> _showDeleteDialog(BuildContext context, String categoryName) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar categoría'),
        content: Text('¿Estás seguro de que deseas eliminar la categoría "$categoryName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _handleDelete(BuildContext context, WidgetRef ref, String id) async {
    try {
      await ref.read(categoriesRepositoryProvider).deleteCategory(id);
      if (context.mounted) {
        showAppToast(context, message: 'Categoría eliminada', type: ToastType.success);
      }
    } catch (e) {
      if (context.mounted) {
        showAppToast(context, message: 'Error: $e', type: ToastType.error);
      }
    }
  }
}
