import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/bank_model.dart';
import '../../../../core/network/supabase_client.dart';

/// Provider para obtener la lista de bancos disponibles desde Supabase
/// Filtrado por país
final banksProvider = FutureProvider.family<List<BankModel>, String>(
  (ref, countryCode) async {
    try {
      final response = await supabaseClient
          .from('bancos')
          .select()
          .contains('country_codes', [countryCode])
          .eq('status', 'active');

      final banks = (response as List)
          .map((json) => BankModel.fromJson(json))
          .toList();
      
      // Si se obtuvieron bancos, inyectar algunos bancos Fintech locales si faltan
      if (banks.isNotEmpty) {
        // Inyectar Kueski Pay
        if (!banks.any((b) => b.name.toLowerCase() == 'kueski_pay' || b.displayName.toLowerCase().contains('kueski'))) {
          banks.add(BankModel(
            id: 'mock_kueski_pay',
            name: 'kueski_pay',
            displayName: 'Kueski Pay',
            primaryColor: '#00D1B2',
            countryCodes: ['MX'],
            status: 'active',
          ));
        }

        banks.sort((a, b) => a.displayName.compareTo(b.displayName));
        return banks;
      }
      
      return [];
    } catch (e) {
      // Si hay error, retorna lista vacía
      return [];
    }
  },
);

/// Provider para obtener un banco específico por ID
final bankByIdProvider = FutureProvider.family<BankModel?, String>(
  (ref, bankId) async {
    try {
      final response = await supabaseClient
          .from('bancos')
          .select()
          .eq('id', bankId)
          .maybeSingle();

      if (response != null) {
        return BankModel.fromJson(response);
      }
      return null;
    } catch (e) {
      return null;
    }
  },
);

/// Provider para búsqueda de bancos por nombre
final bankSearchProvider = FutureProvider.family<List<BankModel>, String>(
  (ref, query) async {
    if (query.isEmpty) return [];

    try {
      final allBanks = await ref.watch(banksProvider('MX').future);
      final lowerQuery = query.toLowerCase();

      return allBanks
          .where((bank) =>
              bank.displayName.toLowerCase().contains(lowerQuery) ||
              bank.name.toLowerCase().contains(lowerQuery))
          .toList();
    } catch (e) {
      return [];
    }
  },
);

/// Provider que mantiene el banco seleccionado desde el catálogo
/// Se usa para preseleccionar el banco en el formulario
final selectedBankProvider = StateProvider<BankModel?>((ref) => null);
