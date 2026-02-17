import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/supabase_client.dart';
import '../../models/currency_model.dart';

/// Provider para obtener la lista de todas las monedas disponibles.
final currenciesProvider = FutureProvider<List<CurrencyModel>>((ref) async {
  try {
    final response = await supabaseClient
        .from('monedas')
        .select('id, codigo, nombre, simbolo')
        .order('codigo');

    return (response as List)
        .map((json) => CurrencyModel.fromJson(json))
        .toList();
  } catch (e) {
    // Lista por defecto en caso de error
    return [
      CurrencyModel(
        id: 'default-mxn',
        codigo: 'MXN',
        nombre: 'Peso Mexicano',
        simbolo: '\$',
      ),
    ];
  }
});

/// Provider para obtener una moneda específica por su ID.
final currencyByIdProvider = Provider.family<AsyncValue<CurrencyModel?>, String>((ref, id) {
  final currenciesAsync = ref.watch(currenciesProvider);
  
  return currenciesAsync.when(
    data: (currencies) => AsyncValue.data(
      currencies.where((c) => c.id == id).firstOrNull,
    ),
    loading: () => const AsyncValue.loading(),
    error: (err, stack) => AsyncValue.error(err, stack),
  );
});
