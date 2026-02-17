import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/bank_model.dart';
import '../../../../core/network/belvo_client.dart';

/// Provider para obtener la lista de bancos disponibles de Belvo
/// Filtrado por país y tipo
final banksProvider = FutureProvider.family<List<BankModel>, String>(
  (ref, countryCode) async {
    try {
      final institutionsData = await BelvoClient.getInstitutions(
        countryCode: countryCode,
        type: 'bank',
        status: 'healthy',
      );

      final banks = institutionsData
          .map((json) => BankModel.fromJson(json))
          .toList();
      
      // Si se obtuvieron bancos, retorna la lista ordenada
      if (banks.isNotEmpty) {
        banks.sort((a, b) => a.displayName.compareTo(b.displayName));
        return banks;
      }
      
      // Si la lista está vacía, retorna lista vacía
      return [];
    } catch (e) {
      // Si hay error, retorna lista vacía
      return [];
    }
  },
);

/// Provider para obtener un banco específico por ID
final bankByIdProvider = FutureProvider.family<BankModel?, int>(
  (ref, bankId) async {
    try {
      final allBanks = await ref.watch(banksProvider('MX').future);
      return allBanks.firstWhere(
        (bank) => bank.id == bankId,
        orElse: () => throw Exception('Banco no encontrado'),
      );
    } catch (e) {
      return null;
    }
  },
);

/// Provider para obtener bancos de múltiples países
final banksByCountriesProvider = FutureProvider.family<List<BankModel>, List<String>>(
  (ref, countryCodes) async {
    try {
      final institutionsData = await BelvoClient.getInstitutionsByCountries(
        countryCodes: countryCodes,
        type: 'bank',
        status: 'healthy',
      );

      return institutionsData
          .map((json) => BankModel.fromJson(json))
          .toList()
        ..sort((a, b) => a.displayName.compareTo(b.displayName));
    } catch (e) {
      return [];
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
