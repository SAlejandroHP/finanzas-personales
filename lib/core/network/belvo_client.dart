import 'package:http/http.dart' as http;
import 'dart:convert';

/// Cliente HTTP para la API pública de Belvo
/// No requiere autenticación para listar instituciones
class BelvoClient {
  static const String _sandboxUrl = 'https://sandbox.belvo.com';
  
  // Usar sandbox por defecto para desarrollo
  static const String _apiUrl = _sandboxUrl;

  /// Obtiene la lista de bancos disponibles
  /// Filtrados por país y tipo
  static Future<List<Map<String, dynamic>>> getInstitutions({
    String countryCode = 'MX',
    String type = 'bank',
    String status = 'healthy',
    int pageSize = 1000,
  }) async {
    try {
      final queryParams = {
        'country_code': countryCode,
        'type': type,
        'status': status,
        'page_size': pageSize.toString(),
      };

      final uri = Uri.parse(
        '$_apiUrl/api/institutions/',
      ).replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Timeout al conectar con Belvo'),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final results = (json['results'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        return results;
      } else {
        throw Exception(
          'Error en API Belvo: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Error al obtener instituciones de Belvo: $e');
    }
  }

  /// Obtiene los detalles de una institución específica
  static Future<Map<String, dynamic>> getInstitution(int institutionId) async {
    try {
      final uri = Uri.parse('$_apiUrl/api/institutions/$institutionId/');

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Timeout al conectar con Belvo'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception(
          'Error en API Belvo: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Error al obtener institución de Belvo: $e');
    }
  }

  /// Obtiene bancos para múltiples países
  static Future<List<Map<String, dynamic>>> getInstitutionsByCountries({
    List<String> countryCodes = const ['MX'],
    String type = 'bank',
    String status = 'healthy',
    int pageSize = 1000,
  }) async {
    try {
      final queryParams = {
        'country_code__in': countryCodes.join(','),
        'type': type,
        'status': status,
        'page_size': pageSize.toString(),
      };

      final uri = Uri.parse(
        '$_apiUrl/api/institutions/',
      ).replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Timeout al conectar con Belvo'),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final results = (json['results'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        return results;
      } else {
        throw Exception(
          'Error en API Belvo: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Error al obtener instituciones de Belvo: $e');
    }
  }
}
