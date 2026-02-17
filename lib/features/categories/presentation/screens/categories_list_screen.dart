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
          'Categorías',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: AppColors.titleMedium,
            color: isDark ? AppColors.textSecondary : AppColors.textPrimary,
          ),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: backgroundColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showCategoryForm(context, ref: ref),
            tooltip: 'Crear categoría',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Selector de Tipo Estilizado (Tab Alternativo)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: AppColors.pagePadding, vertical: 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(AppColors.radiusMedium),
            ),
            child: Row(
              children: [
                _buildTabItem(context, ref, 'ingreso', 'Ingresos', typeFilter == 'ingreso'),
                _buildTabItem(context, ref, 'gasto', 'Gastos', typeFilter == 'gasto'),
              ],
            ),
          ),

          // Buscador Rápido
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                ),
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
                  fontSize: 13,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Buscar categoría...',
                  hintStyle: GoogleFonts.montserrat(
                    fontSize: 13,
                    color: isDark ? Colors.white38 : Colors.grey[400],
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: isDark ? Colors.white38 : Colors.grey[400],
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  suffixIcon: ref.watch(categorySearchQueryProvider).isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16),
                          onPressed: () => ref.read(categorySearchQueryProvider.notifier).state = '',
                        )
                      : null,
                ),
              ),
            ),
          ),
          
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
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 120),
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.9,
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCategoryForm(context, ref: ref),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildTabItem(BuildContext context, WidgetRef ref, String type, String label, bool isSelected) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Expanded(
      child: GestureDetector(
        onTap: () => ref.read(categoryTypeFilterProvider.notifier).state = type,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected 
                ? (isDark ? AppColors.primary : Colors.white) 
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              if (isSelected && !isDark)
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected 
                  ? (isDark ? Colors.white : AppColors.primary)
                  : (isDark ? Colors.white54 : Colors.grey[600]),
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
              color: isDark ? Colors.white.withOpacity(0.05) : AppColors.primary.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isSearch ? Icons.search_off_rounded : Icons.folder_open_rounded,
              size: 64,
              color: AppColors.primary.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isSearch ? 'Sin coincidencias' : 'Sin categorías',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isSearch 
              ? 'No encontramos categorías que coincidan'
              : 'Crea tu primera categoría de ${type == 'ingreso' ? 'ingreso' : 'gasto'}',
            style: GoogleFonts.montserrat(
              color: isDark ? Colors.white70 : AppColors.textPrimary.withOpacity(0.6),
              fontSize: 14,
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
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(color: Colors.grey, fontSize: 12),
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
