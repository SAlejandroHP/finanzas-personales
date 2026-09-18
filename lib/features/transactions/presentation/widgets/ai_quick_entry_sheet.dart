import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../accounts/presentation/providers/accounts_provider.dart';
import '../../../categories/presentation/providers/categories_provider.dart';
import '../providers/transactions_provider.dart';
import '../models/transaction_model.dart';
import '../../../../core/network/supabase_client.dart';

class AiQuickEntrySheet extends ConsumerStatefulWidget {
  const AiQuickEntrySheet({super.key});

  @override
  ConsumerState<AiQuickEntrySheet> createState() => _AiQuickEntrySheetState();
}

class _AiQuickEntrySheetState extends ConsumerState<AiQuickEntrySheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _processAiEntry() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _isLoading = true);
    
    try {
      final apiKey = dotenv.env['GROQ_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('API Key de Groq no configurada');
      }

      final accounts = ref.read(accountsListProvider).value ?? [];
      final categories = ref.read(categoriesListProvider).value ?? [];
      
      final contextMap = {
        'accounts': accounts.map((a) => {'id': a.id, 'nombre': a.nombre}).toList(),
        'categories': categories.map((c) => {'id': c.id, 'nombre': c.nombre, 'tipo': c.tipo}).toList(),
      };

      final systemPrompt = '''
      Eres un asistente financiero rápido. El usuario te dará un comando de texto para registrar un movimiento.
      Extrae la información y devuelve ÚNICAMENTE un JSON válido con las siguientes llaves (sin markdown):
      - tipo: "ingreso" o "gasto"
      - monto: número (float, ejemplo: 500.0)
      - descripcion: un resumen corto de qué fue el gasto/ingreso
      - cuentaOrigenId: busca el UUID de la cuenta que mencione el usuario (ej: nu, bbva) de aquí: \${jsonEncode(contextMap['accounts'])}. Si no menciona, elige la primera o devuelve null.
      - categoriaId: busca el UUID de la categoría que mejor encaje de aquí: \${jsonEncode(contextMap['categories'])}. Si no encaja ninguna, devuelve null.
      No agregues texto extra, solo devuelve el objeto JSON.
      ''';

      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer \$apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "model": "llama3-8b-8192",
          "messages": [
            {"role": "system", "content": systemPrompt},
            {"role": "user", "content": text}
          ],
          "response_format": {"type": "json_object"}
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Error al comunicarse con la IA');
      }

      final data = jsonDecode(response.body);
      final contentStr = data['choices'][0]['message']['content'];
      final Map<String, dynamic> txData = jsonDecode(contentStr);

      final newTx = TransactionModel(
        id: '', // Se genera en el repositorio o en base de datos
        userId: supabaseClient.auth.currentUser!.id,
        monto: (txData['monto'] as num).toDouble(),
        tipo: txData['tipo'] ?? 'gasto',
        categoriaId: txData['categoriaId'],
        cuentaOrigenId: txData['cuentaOrigenId'],
        fecha: DateTime.now(),
        descripcion: txData['descripcion'] ?? 'Registro rápido',
        estado: 'completada',
        createdAt: DateTime.now(),
      );

      await ref.read(transactionsRepositoryProvider).createTransaction(newTx);
      
      if (mounted) {
        Navigator.pop(context);
        showAppToast(context, 'Movimiento registrado con éxito', icon: Icons.check_circle_outline);
      }
    } catch (e) {
      if (mounted) {
        showAppToast(context, 'Error al registrar: \${e.toString()}', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.backgroundDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Registro Rápido con IA',
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _controller,
                focusNode: _focusNode,
                maxLines: 3,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _processAiEntry(),
                decoration: InputDecoration(
                  hintText: 'Ej. Gaste \$500 en despensa con Nu...',
                  hintStyle: GoogleFonts.montserrat(
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontSize: 15,
                  ),
                  filled: true,
                  fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
                style: GoogleFonts.montserrat(
                  fontSize: 15,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: AppColors.interactiveHeight,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _processAiEntry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          'Registrar',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
