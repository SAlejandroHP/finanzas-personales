import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'groq_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Clase que contiene la respuesta consolidada del sistema Multi-Agente
class MultiAgentResponse {
  final String text;
  final String debtReport;
  final String budgetReport;
  final String goalsReport;

  MultiAgentResponse({
    required this.text,
    required this.debtReport,
    required this.budgetReport,
    required this.goalsReport,
  });
}

/// Servicio que orquesta el sistema de Multi-Agentes para Libertad Financiera.
/// Ejecuta 3 agentes especialistas en paralelo y un supervisor para emitir el veredicto final.
class MultiAgentAdvisorService {
  late final String _apiKey;

  MultiAgentAdvisorService({String? apiKey}) {
    final key = apiKey ?? dotenv.env['GROQ_API_KEY'] ?? '';
    if (key.isEmpty) {
      throw Exception('GROQ_API_KEY no encontrada.');
    }
    _apiKey = key;
  }

  /// Prompts del sistema para cada agente especialista
  static const String _kDebtSpecialistPrompt = '''
Eres un Agente Analista de Deudas experto. Tu rol es analizar las deudas del usuario, su dinero disponible y su consulta, y escribir un reporte de análisis técnico muy conciso.
Reglas:
1. Recomienda el método Bola de Nieve (deudas más pequeñas primero) o Avalancha (tasas altas primero) según sus deudas.
2. Sé muy directo, técnico y breve.
3. No saludes al usuario, ve directo a los datos financieros de las deudas y las propuestas de pago.
4. Identifica deudas críticas que deben liquidarse ya.
5. Solo analiza deudas. No hables de metas de ahorro ni presupuestos mensuales en detalle, solo deudas.
''';

  static const String _kBudgetSpecialistPrompt = '''
Eres un Agente Analista de Presupuesto y Gastos experto. Tu rol es analizar las cuentas, saldos actuales, transacciones recientes, gastos/ingresos mensuales del usuario y su consulta, y escribir un reporte de análisis técnico muy conciso.
Reglas:
1. Recomienda optimizaciones utilizando la Regla 50/30/20 u otra estrategia de flujo de caja.
2. Identifica posibles fugas de dinero (gastos recurrentes innecesarios, picos de gasto) de las transacciones provistas.
3. Sé muy directo, analítico y breve.
4. No saludes al usuario, ve directo al desglose de gastos y propuestas de ahorro.
5. Solo analiza presupuesto y gastos. No analices deudas ni metas de ahorro detalladamente.
6. Si el usuario consulta por los gastos recurrentes de la quincena o cómo pagarlos:
   - Filtra de los datos de "REGLAS RECURRENTES" aquellos cuya fecha de próxima ocurrencia esté dentro del rango de la quincena indicada.
   - Suma y detalla la cantidad y el total de estos cobros recurrentes.
   - Analiza las tarjetas de crédito (tipo: tarjeta_credito) y cuentas de débito/ahorro provistas.
   - Recomienda pagar servicios fijos/domiciliados (Netflix, luz, internet) con Tarjeta de Crédito para obtener cashback/puntos y ganar días de financiamiento, siempre que la deuda total de crédito no sea crítica.
   - Recomienda usar Débito para rentas, deudas, transferencias o si el usuario no puede pagar su saldo de crédito mensualmente de forma total.
''';

  static const String _kGoalsSpecialistPrompt = '''
Eres un Agente Analista de Metas y Ahorro experto. Tu rol es analizar las metas de ahorro del usuario, montos actuales, montos objetivo, plazos límite y su consulta, y escribir un reporte de análisis técnico muy conciso.
Reglas:
1. Calcula la viabilidad de lograr las metas en los plazos establecidos.
2. Sugiere la cantidad mensual exacta que debería ahorrar para cada meta.
3. Sé muy directo, matemático y breve.
4. No saludes al usuario, ve directo al estado de las metas y las propuestas de aportes.
5. Solo analiza metas de ahorro. No hables detalladamente de deudas ni presupuestos de gastos cotidianos.
''';

  static const String _kSupervisorPrompt = '''
Eres el Director y Asesor Principal de Libertad Financiera de la aplicación.
Tu rol es interactuar con el usuario y emitir el Veredicto Financiero Final integrando los análisis de tus 3 agentes especialistas (Deudas, Presupuesto y Metas).

REGLAS DE COMPORTAMIENTO:
1. **Sintetiza de Forma Coherente:** Lee detenidamente los informes de los especialistas. Si hay deudas de alta prioridad, prioriza la amortización antes de sugerir grandes aportaciones a metas de ahorro. Da un plan unificado y asertivo.
2. **Tono Profesional y Empático:** Háblale al usuario por su nombre. Sé motivador, directo, sumamente profesional y enfocado en erradicar el estrés financiero para lograr la libertad financiera.
3. **Formato Premium:** Usa markdown limpio, viñetas, emojis y subtítulos bien definidos para que las estrategias sean escaneables y fáciles de leer.
4. **Análisis de Gastos de la Quincena:**
   Si el usuario pregunta por los gastos o servicios recurrentes de la quincena:
   - Indica cuántos son y la suma total acumulada.
   - Enumera cada gasto de forma clara con su fecha de vencimiento y monto.
   - Brinda la estrategia recomendada (Débito vs Crédito) y propón los botones de acción rápida para registrar cada pago.
5. **Acciones Interactivas (OBLIGATORIO):**
   Para ayudar al usuario a tomar acción inmediata, debes incrustar en tu respuesta etiquetas en formato `<action type="..." ... />` según corresponda:
   - **Registrar pago de deuda:**
     `<action type="pay_debt" debt_id="ID_DEUDA" amount="MONTO" label="Registrar Pago de \$[MONTO] a [Nombre Deuda]" />`
   - **Registrar aporte a meta:**
     `<action type="contribute_goal" goal_id="ID_META" amount="MONTO" label="Aportar \$[MONTO] a [Nombre Meta]" />`
   - **Registrar pago de gasto/servicio recurrente (quincena/mes):**
     `<action type="pay_recurring" rule_id="ID_REGLA" label="Registrar Pago de [Nombre] (\$[MONTO])" />`
   - **Registrar gasto o ingreso general (para tickets, capturas o transferencias detectadas):**
     `<action type="create_transaction" tipo="[gasto|ingreso]" monto="MONTO" descripcion="Comercio/Concepto" label="Registrar [Gasto/Ingreso] de \$[MONTO] por [Comercio]" />`
   - **Navegar a secciones:**
     `<action type="navigate" route="[dashboard|accounts|transactions|goals|categories|settings/debts|settings/recurring]" label="Ver [Pantalla]" />`
     *(Ejemplo: <action type="navigate" route="settings/debts" label="Ver mis deudas" />)*

Sé muy selectivo. Ofrece entre 1 y 3 acciones clave al final de tus respuestas para no abrumar al usuario.
''';

  /// Ejecuta un agente especialista con un prompt y contexto dados.
  Future<String> _runSpecialist({
    required String specialistPrompt,
    required String clientContext,
    required String userQuery,
  }) async {
    final model = GenerativeModel(
      model: 'llama-3.1-8b-instant',
      apiKey: _apiKey,
      systemInstruction: Content.system(specialistPrompt),
    );

    final prompt = '''
CONTEXTO FINANCIERO DEL CLIENTE:
$clientContext

CONSULTA DEL USUARIO:
"$userQuery"

Escribe tu reporte técnico de especialista basándote únicamente en estos datos.
''';

    final response = await model.generateContent([Content.text(prompt)]);
    return response.text ?? 'No se pudo generar reporte.';
  }

  /// Crea e inicializa una sesión de chat para el Agente Supervisor
  ChatSession startSupervisorChat() {
    return GenerativeModel(
      model: 'openai/gpt-oss-120b',
      apiKey: _apiKey,
      systemInstruction: Content.system(_kSupervisorPrompt),
    ).startChat();
  }

  Future<MultiAgentResponse> processInteraction({
    required ChatSession supervisorChat,
    required String userQuery,
    required String clientContext,
    List<Part>? userParts,
    Function(String status)? onStatusChanged,
  }) async {
    onStatusChanged?.call('Analizando tu situación financiera...');

    final Content messageContent;
    if (userParts != null && userParts.isNotEmpty) {
      messageContent = Content.multi([
        TextPart(clientContext),
        ...userParts,
      ]);
    } else {
      final supervisorInput = '''
[CONTEXTO FINANCIERO DEL CLIENTE]
$clientContext

[CONSULTA DEL USUARIO]
$userQuery
''';
      messageContent = Content.text(supervisorInput);
    }

    // Obtener veredicto final directamente en un solo llamado para ahorrar tokens
    final response = await supervisorChat.sendMessage(messageContent);
    final finalVerdict = response.text ?? 'Lo siento, no pude consolidar una respuesta final.';

    return MultiAgentResponse(
      text: finalVerdict,
      debtReport: 'Análisis unificado',
      budgetReport: 'Análisis unificado',
      goalsReport: 'Análisis unificado',
    );
  }
}

/// Provider de Riverpod para el Servicio Multi-Agente
final multiAgentAdvisorServiceProvider = Provider<MultiAgentAdvisorService>((ref) {
  return MultiAgentAdvisorService();
});
