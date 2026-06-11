import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../models/transaction_model.dart';
import '../providers/transactions_provider.dart';
import 'transaction_tile.dart';

class SpotlightSearchOverlay extends ConsumerStatefulWidget {
  const SpotlightSearchOverlay({Key? key}) : super(key: key);

  @override
  ConsumerState<SpotlightSearchOverlay> createState() => _SpotlightSearchOverlayState();
}

class _SpotlightSearchOverlayState extends ConsumerState<SpotlightSearchOverlay> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _searchQuery = '';
  String _selectedFilter = 'Todos'; // Todos, Ingresos, Gastos, Pendientes

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final transactionsAsync = ref.watch(transactionsListProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Blur background
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  color: isDark ? Colors.black.withOpacity(0.6) : Colors.white.withOpacity(0.8),
                ),
              ),
            ),
          ),
          
          // Content
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),
                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Hero(
                    tag: 'search_bar_spotlight',
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          focusNode: _focusNode,
                          autofocus: true,
                          style: GoogleFonts.montserrat(
                            fontSize: 18,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Buscar transacciones...',
                            hintStyle: GoogleFonts.montserrat(
                              color: isDark ? Colors.white54 : Colors.grey,
                            ),
                            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, color: Colors.grey),
                                    onPressed: () {
                                      _searchController.clear();
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Quick Filters
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _buildFilterChip('Todos', isDark),
                      const SizedBox(width: 8),
                      _buildFilterChip('Ingresos', isDark),
                      const SizedBox(width: 8),
                      _buildFilterChip('Gastos', isDark),
                      const SizedBox(width: 8),
                      _buildFilterChip('Pendientes', isDark),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Results List
                Expanded(
                  child: transactionsAsync.when(
                    data: (transactions) {
                      final results = transactions.where((t) {
                        // Apply Text Search
                        final descMatch = t.descripcion?.toLowerCase().contains(_searchQuery) ?? false;
                        final amountMatch = t.monto.toString().contains(_searchQuery);
                        final typeMatch = t.tipo.toLowerCase().contains(_searchQuery);
                        final matchesSearch = _searchQuery.isEmpty || descMatch || amountMatch || typeMatch;
                        
                        // Apply Chip Filter
                        bool matchesFilter = true;
                        if (_selectedFilter == 'Ingresos') {
                          matchesFilter = t.tipo == 'ingreso';
                        } else if (_selectedFilter == 'Gastos') {
                          matchesFilter = t.tipo == 'gasto';
                        } else if (_selectedFilter == 'Pendientes') {
                          matchesFilter = t.estado == 'pendiente';
                        }
                        
                        return matchesSearch && matchesFilter;
                      }).toList();

                      // Sort by date descending
                      results.sort((a, b) => b.fecha.compareTo(a.fecha));

                      if (results.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.withOpacity(0.5)),
                              const SizedBox(height: 16),
                              Text(
                                'No se encontraron resultados',
                                style: GoogleFonts.montserrat(
                                  color: Colors.grey,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8).copyWith(bottom: 40),
                        physics: const BouncingScrollPhysics(),
                        itemCount: results.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Material(
                              color: Colors.transparent,
                              child: TransactionTile(
                                transaction: results[index],
                                currencySymbol: '\$',
                              ),
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                    error: (e, _) => Center(child: Text('Error: $e')),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isDark) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = label;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppColors.primary 
              : (isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.montserrat(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected 
                ? Colors.white 
                : (isDark ? Colors.white70 : AppColors.textPrimary.withOpacity(0.7)),
          ),
        ),
      ),
    );
  }
}
