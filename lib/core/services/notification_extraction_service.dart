import 'dart:convert';
import 'groq_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../features/accounts/models/account_model.dart';

class ExtractedNotification {
  final double amount;
  final bool isExpense;
  final String concept;
  final String packageName;

  ExtractedNotification({
    required this.amount,
    required this.isExpense,
    required this.concept,
    required this.packageName,
  });

  factory ExtractedNotification.fromJson(Map<String, dynamic> json, String packageName) {
    return ExtractedNotification(
      amount: (json['amount'] as num).toDouble(),
      isExpense: json['is_expense'] as bool? ?? true,
      concept: json['concept'] as String? ?? 'Desconocido',
      packageName: packageName,
    );
  }
}

class NotificationExtractionService {
  late final GenerativeModel _model;

  NotificationExtractionService({String? apiKey}) {
    final key = apiKey ?? dotenv.env['GROQ_API_KEY'] ?? '';
    if (key.isEmpty) {
      throw Exception('GROQ_API_KEY no encontrada.');
    }

    // Prompt estructurado para la IA como fallback
    const systemInstruction = '''
Eres un asistente experto en extraer información de notificaciones bancarias.
Tu ÚNICO objetivo es analizar el título y cuerpo de una notificación push de un banco y devolver un JSON estricto.
No uses formato markdown, ni bloques de código, solo texto JSON puro.
Formato requerido:
{
  "amount": <número decimal, extraer solo el valor>,
  "is_expense": <booleano, true si es una compra/retiro/pago, false si es un depósito/ingreso/transferencia recibida>,
  "concept": "<String, nombre del comercio, concepto o descripción corta>"
}
Si la notificación no parece una transacción financiera válida, devuelve un JSON con amount 0 y concepto "Inválido".
''';

    _model = GenerativeModel(
      model: 'llama-3.1-8b-instant',
      apiKey: key,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
      ),
      systemInstruction: Content.system(systemInstruction),
    );
  }

  /// Diccionario de Expresiones Regulares específicas por banco
  final Map<String, RegExp> _bankRegexDict = {
    'com.bbva.bbvacontigo': RegExp(r'(?:Compra|Retiro).*?\$?\s?(\d{1,3}(?:,\d{3})*(?:\.\d{2})?).*?(?:en|de)\s+(.+)', caseSensitive: false),
    'com.nu.production': RegExp(r'Compraste\s+\$?\s?(\d{1,3}(?:,\d{3})*(?:\.\d{2})?)\s+en\s+(.+)', caseSensitive: false),
    'com.banamex.mexico': RegExp(r'(?:Compra|Cargo).*?\$?\s?(\d{1,3}(?:,\d{3})*(?:\.\d{2})?).*?(?:en)\s+(.+)', caseSensitive: false),
    'com.santander.mxbanking': RegExp(r'(?:Compra|Cargo).*?\$?\s?(\d{1,3}(?:,\d{3})*(?:\.\d{2})?).*?(?:en)\s+(.+)', caseSensitive: false),
    'com.banorte.mob': RegExp(r'(?:Compra|Cargo).*?\$?\s?(\d{1,3}(?:,\d{3})*(?:\.\d{2})?).*?(?:en)\s+(.+)', caseSensitive: false),
  };

  /// Nivel 1: Motor de Extracción por Regex (Rápido)
  ExtractedNotification? extractWithRegex(String packageName, String title, String text) {
    final combinedText = "\$title. \$text";
    
    // 1. Intentar con Regex específico del banco
    final specificRegex = _bankRegexDict[packageName];
    if (specificRegex != null) {
      final match = specificRegex.firstMatch(combinedText);
      if (match != null && match.groupCount >= 2) {
         final amountStr = match.group(1)?.replaceAll(',', '');
         final concept = match.group(2)?.trim();
         
         if (amountStr != null && concept != null) {
           final amount = double.tryParse(amountStr);
           if (amount != null) {
              return ExtractedNotification(
                amount: amount,
                isExpense: true, // La mayoría de Regex específicos son de gasto por ahora
                concept: concept.length > 30 ? concept.substring(0, 30) : concept,
                packageName: packageName,
              );
           }
         }
      }
    }

    // 2. Fallback de Regex General si el específico falla o no existe
    final amountRegex = RegExp(r'\$\s?(\d{1,3}(?:,\d{3})*(?:\.\d{2})?)');
    final match = amountRegex.firstMatch(combinedText);

    if (match != null) {
      final amountStr = match.group(1)?.replaceAll(',', '');
      if (amountStr != null) {
        final amount = double.tryParse(amountStr);
        if (amount != null) {
          
          bool isExpense = true;
          String concept = "Transacción detectada";

          // Lógica heurística de palabras clave para deducir gasto vs ingreso
          final lowerText = combinedText.toLowerCase();
          if (lowerText.contains("depósito") || 
              lowerText.contains("deposito") || 
              lowerText.contains("transferencia recibida") ||
              lowerText.contains("te transfirió") ||
              lowerText.contains("te depositó") ||
              lowerText.contains("abono")) {
            isExpense = false;
          }

          // Intentar extraer el concepto (heurística simple)
          if (lowerText.contains("en ")) {
            final parts = combinedText.split(RegExp(r'\ben\b', caseSensitive: false));
            if (parts.length > 1) {
              concept = parts.last.trim().replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '');
              if (concept.length > 30) concept = concept.substring(0, 30);
            }
          } else if (lowerText.contains("de ")) {
             final parts = combinedText.split(RegExp(r'\bde\b', caseSensitive: false));
             if (!isExpense && parts.length > 1) {
                concept = "Transferencia de " + parts.last.trim().replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '');
                if (concept.length > 30) concept = concept.substring(0, 30);
             }
          }

          if (concept.trim().isEmpty || concept == "Transacción detectada") {
            concept = isExpense ? "Gasto detectado" : "Ingreso detectado";
          }

          return ExtractedNotification(
            amount: amount,
            isExpense: isExpense,
            concept: concept,
            packageName: packageName,
          );
        }
      }
    }
    return null; // Si todo falla, devuelve null para usar IA
  }

  /// Nivel 2: Motor de Extracción por IA (Fallback)
  Future<ExtractedNotification> extractWithAI(String packageName, String title, String text) async {
    final prompt = '''
    App Package: $packageName
    Title: $title
    Text: $text
    ''';

    final response = await _model.generateContent([Content.text(prompt)]);
    final responseText = response.text;

    if (responseText == null || responseText.isEmpty) {
      throw Exception("El modelo IA devolvió una respuesta vacía.");
    }

    final jsonMap = jsonDecode(responseText) as Map<String, dynamic>;
    return ExtractedNotification.fromJson(jsonMap, packageName);
  }

  /// Método principal que orquesta ambos niveles
  Future<ExtractedNotification> processNotification(String packageName, String title, String text) async {
    // 1. Intentamos primero con Regex (Nivel 1)
    final regexResult = extractWithRegex(packageName, title, text);
    if (regexResult != null) {
      return regexResult;
    }

    // 2. Si falla, usamos el Fallback de Gemini (Nivel 2)
    return await extractWithAI(packageName, title, text);
  }

  /// Busca la cuenta correspondiente a este paquete en la lista de cuentas del usuario
  String? matchAccountByPackageName(List<AccountModel> userAccounts, String packageName) {
    // Intentar buscar por etiqueta (tag) que coincida exactamente con el packageName
    try {
      final accountByTag = userAccounts.firstWhere(
        (acc) => acc.tags.any((tag) => tag.toLowerCase() == packageName.toLowerCase()),
      );
      return accountByTag.id;
    } catch (_) {}

    // Intentar hacer match heurístico por el nombre del banco dentro del packageName
    final lowercasePackage = packageName.toLowerCase();
    String? hint;
    if (lowercasePackage.contains('bbva')) hint = 'bbva';
    else if (lowercasePackage.contains('nu.production')) hint = 'nu';
    else if (lowercasePackage.contains('banamex')) hint = 'banamex';
    else if (lowercasePackage.contains('santander')) hint = 'santander';
    else if (lowercasePackage.contains('banorte')) hint = 'banorte';
    else if (lowercasePackage.contains('hsbc')) hint = 'hsbc';
    else if (lowercasePackage.contains('scotiabank')) hint = 'scotiabank';
    else if (lowercasePackage.contains('bancoazteca') || lowercasePackage.contains('baz')) hint = 'azteca';
    else if (lowercasePackage.contains('klar')) hint = 'klar';
    else if (lowercasePackage.contains('stori')) hint = 'stori';
    else if (lowercasePackage.contains('uala')) hint = 'uala';
    else if (lowercasePackage.contains('mercadopago')) hint = 'mercado pago';
    else if (lowercasePackage.contains('spin')) hint = 'spin';

    if (hint != null) {
      try {
        final accountByHint = userAccounts.firstWhere(
          (acc) => acc.nombre.toLowerCase().contains(hint!) || 
                   (acc.bancoNombre != null && acc.bancoNombre!.toLowerCase().contains(hint)),
        );
        return accountByHint.id;
      } catch (_) {}
    }

    // Si no se encuentra un match seguro, devolvemos null para que el usuario elija
    return null;
  }
}
