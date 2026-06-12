import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
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

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase().trim();
      });
    });
    
    // Forzar apertura del teclado al iniciar la pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
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
    final transactionsAsync = ref.watch(transactionsListProvider);
    final hasSearch = _searchQuery.isNotEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Theme adaptive colors
    final glassColor = isDark ? const Color(0xFF282828).withOpacity(0.75) : Colors.white.withOpacity(0.9);
    final borderColor = isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.08);
    final textColor = isDark ? Colors.white : Colors.black87;
    final hintColor = isDark ? Colors.white.withOpacity(0.4) : Colors.black45;
    final iconColor = isDark ? Colors.white.withOpacity(0.7) : Colors.black54;
    final closeBtnBgColor = isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.08);
    final closeBtnIconColor = isDark ? Colors.white : Colors.black87;
    final dividerColor = isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background - Subtle darken
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                color: Colors.black.withOpacity(0.2),
              ),
            ),
          ),
          
          // Content - Floating in the upper middle
          SafeArea(
            child: Align(
              alignment: const Alignment(0, -0.75), // Higher up, closer to iOS style
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.65,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16), 
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
                      blurRadius: 30,
                      spreadRadius: -5,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Container(
                      decoration: BoxDecoration(
                        color: glassColor,
                        border: Border.all(color: borderColor, width: 1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min, // Hug content
                        children: [
                          // Custom Symmetrical Search Bar
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(Icons.search_rounded, color: iconColor, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    focusNode: _focusNode,
                                    autofocus: true,
                                    cursorColor: AppColors.primary,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w400,
                                      color: textColor,
                                      letterSpacing: -0.3,
                                      height: 1.2, // Keeps text and cursor centered
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Búsqueda...',
                                      hintStyle: GoogleFonts.montserrat(
                                        color: hintColor,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w400,
                                        letterSpacing: -0.3,
                                        height: 1.2,
                                      ),
                                      filled: true,
                                      fillColor: Colors.transparent, // Fixes white box in HTML renderer
                                      hoverColor: Colors.transparent,
                                      border: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(vertical: 12), // Vertical padding instead of isDense
                                    ),
                                  ),
                                ),
                                if (hasSearch) ...[
                                  const SizedBox(width: 12),
                                  GestureDetector(
                                    onTap: () {
                                      _searchController.clear();
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: closeBtnBgColor,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.close_rounded, color: closeBtnIconColor, size: 14),
                                    ),
                                  ),
                                ]
                              ],
                            ),
                          ),
                          
                          // Divider if showing results
                          if (hasSearch)
                            Container(
                              height: 1,
                              color: dividerColor,
                              margin: EdgeInsets.zero,
                            ),
                          
                          // Results List
                          if (hasSearch)
                            Flexible(
                              child: transactionsAsync.when(
                                data: (transactions) {
                                  final results = transactions.where((t) {
                                    final descMatch = t.descripcion?.toLowerCase().contains(_searchQuery) ?? false;
                                    final amountMatch = t.monto.toString().contains(_searchQuery);
                                    final typeMatch = t.tipo.toLowerCase().contains(_searchQuery);
                                    final categoryMatch = t.categoriaId?.toLowerCase().contains(_searchQuery) ?? false;
                                    return descMatch || amountMatch || typeMatch || categoryMatch;
                                  }).toList();

                                  results.sort((a, b) => b.fecha.compareTo(a.fecha));

                                  if (results.isEmpty) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 30.0),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Sin resultados',
                                            style: GoogleFonts.montserrat(
                                              color: hintColor,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }

                                  return ListView.builder(
                                    // Removed horizontal padding since TransactionTile already has margin
                                    padding: const EdgeInsets.symmetric(vertical: 4), 
                                    physics: const BouncingScrollPhysics(),
                                    shrinkWrap: true,
                                    itemCount: results.length,
                                    itemBuilder: (context, index) {
                                      return Material(
                                        color: Colors.transparent,
                                        child: Transform.scale(
                                          scale: 0.96, // Slightly scale down the tiles to fit better in the overlay
                                          child: TransactionTile(
                                            transaction: results[index],
                                            currencySymbol: '\$',
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                                loading: () => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 30.0),
                                  child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
                                ),
                                error: (e, _) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 30.0),
                                  child: Center(child: Text('Error: $e', style: const TextStyle(color: Colors.redAccent))),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
