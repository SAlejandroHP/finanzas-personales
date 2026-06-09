import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/models/master_plan_models.dart';
import '../../../accounts/presentation/providers/accounts_provider.dart';
import '../../../debts/presentation/providers/debts_provider.dart';
import '../../../transactions/presentation/providers/transactions_provider.dart';

final masterPlanProvider = Provider<List<PlanPhase>>((ref) {
  final accountsAsync = ref.watch(accountsWithBalanceProvider);
  final debtsAsync = ref.watch(debtsListProvider);
  final transactionsAsync = ref.watch(transactionsListProvider);

  final accounts = accountsAsync.value ?? [];
  final debts = debtsAsync.value ?? [];
  final transactions = transactionsAsync.value ?? [];

  final now = DateTime.now();
  final startDate = DateTime(now.year, now.month, now.day);
  final endDate = startDate.add(const Duration(days: 45));

  final Map<DateTime, PlanMilestone> milestoneMap = {};

  void _addMilestoneAction(DateTime date, String title, PlanAction action, {String? note, List<String>? bullets}) {
    final cleanDate = DateTime(date.year, date.month, date.day);
    if (cleanDate.isBefore(startDate) || cleanDate.isAfter(endDate)) return;

    if (!milestoneMap.containsKey(cleanDate)) {
      milestoneMap[cleanDate] = PlanMilestone(
        date: cleanDate,
        title: title,
        actions: [action],
        bulletPoints: bullets ?? [],
        note: note,
      );
    } else {
      final existing = milestoneMap[cleanDate]!;
      // Evitar duplicar el mismo título exacto si caen en el mismo día
      String newTitle = existing.title;
      if (!newTitle.contains(title)) {
        newTitle = '$newTitle & $title';
      }

      milestoneMap[cleanDate] = PlanMilestone(
        date: existing.date,
        title: newTitle,
        actions: [...existing.actions, action],
        bulletPoints: bullets != null ? [...existing.bulletPoints, ...bullets] : existing.bulletPoints,
        note: note ?? existing.note,
      );
    }
  }

  // 1. Tarjetas de Crédito (Cortes y Pagos)
  for (final account in accounts) {
    if (account.tipo == 'tarjeta_credito' && account.fechaCorte != null && account.fechaLimitePago != null) {
      final corteDate1 = DateTime(startDate.year, startDate.month, account.fechaCorte!);
      final corteDate2 = DateTime(startDate.year, startDate.month + 1, account.fechaCorte!);

      for (final cDate in [corteDate1, corteDate2]) {
        _addMilestoneAction(
          cDate,
          'Corte de ${account.nombre}',
          PlanAction(
            label: 'Regla',
            description: 'NO usar ${account.nombre} hoy',
            type: ActionType.rule,
          ),
        );

        // Apalancamiento al día siguiente
        final apalancamientoDate = cDate.add(const Duration(days: 1));
        _addMilestoneAction(
          apalancamientoDate,
          'Apalancamiento ${account.nombre}',
          PlanAction(
            label: 'Estrategia',
            description: 'Ganas ~50 días para pagar',
            type: ActionType.leverage,
          ),
          note: 'Ventana de oro para hacer compras necesarias sin descapitalizarte hoy.',
        );

        // Límite de pago
        DateTime pagoDate = DateTime(cDate.year, cDate.month, account.fechaLimitePago!);
        if (pagoDate.isBefore(cDate) || pagoDate.difference(cDate).inDays < 5) {
          pagoDate = DateTime(cDate.year, cDate.month + 1, account.fechaLimitePago!);
        }

        _addMilestoneAction(
          pagoDate,
          'Límite Pago ${account.nombre}',
          PlanAction(
            label: 'Pago',
            description: 'Cubrir saldo para no generar intereses',
            type: ActionType.payment,
          ),
        );
      }
    }
  }

  // 2. Deudas
  for (final debt in debts) {
    if (debt.estado != 'pagada' && debt.fechaVencimiento != null) {
      _addMilestoneAction(
        debt.fechaVencimiento!,
        'Límite Pago Deuda',
        PlanAction(
          label: 'Obligación',
          description: 'Pagar \$${debt.montoTotal.toStringAsFixed(2)} de ${debt.nombre}',
          type: ActionType.expense,
        ),
      );
    }
  }

  // 3. Transacciones recurrentes (Ingresos y Gastos Fijos)
  final currencyFormatter = NumberFormat.currency(locale: 'es_MX', symbol: '\$', decimalDigits: 2);
  for (final tx in transactions) {
    if (tx.isRecurring) {
      // Proyectar para los próximos 2 meses basándose en el día
      final date1 = DateTime(startDate.year, startDate.month, tx.fecha.day);
      final date2 = DateTime(startDate.year, startDate.month + 1, tx.fecha.day);

      for (final pDate in [date1, date2]) {
        if (tx.tipo == 'ingreso') {
          _addMilestoneAction(
            pDate,
            'Quincena / Ingreso',
            PlanAction(
              label: 'Ingreso',
              description: '+${currencyFormatter.format(tx.monto)} (${tx.descripcion ?? "Fijo"})',
              type: ActionType.income,
            ),
          );
        } else {
          _addMilestoneAction(
            pDate,
            'Gasto Fijo Programado',
            PlanAction(
              label: 'Blindaje',
              description: 'Separar ${currencyFormatter.format(tx.monto)} (${tx.descripcion ?? "Gasto"})',
              type: ActionType.expense,
            ),
          );
        }
      }
    }
  }

  if (milestoneMap.isEmpty) {
    return []; // Estado vacío
  }

  // Ordenar hitos cronológicamente
  final sortedDates = milestoneMap.keys.toList()..sort();
  final sortedMilestones = sortedDates.map((d) => milestoneMap[d]!).toList();

  // Agrupar por Mes (Fases)
  final Map<String, List<PlanMilestone>> phasesMap = {};
  for (final milestone in sortedMilestones) {
    final monthName = DateFormat('MMMM', 'es_MX').format(milestone.date);
    final capitalizedMonth = monthName[0].toUpperCase() + monthName.substring(1);
    final phaseTitle = capitalizedMonth;
    
    if (!phasesMap.containsKey(phaseTitle)) {
      phasesMap[phaseTitle] = [];
    }
    phasesMap[phaseTitle]!.add(milestone);
  }

  int phaseIndex = 1;
  final List<PlanPhase> phases = [];
  for (final entry in phasesMap.entries) {
    final firstDate = entry.value.first.date;
    final lastDate = entry.value.last.date;
    final formatter = DateFormat('d MMM', 'es_MX');
    
    phases.add(PlanPhase(
      title: 'Fase $phaseIndex: Ejecución ${entry.key}',
      subtitle: '${formatter.format(firstDate)} al ${formatter.format(lastDate)}',
      milestones: entry.value,
    ));
    phaseIndex++;
  }

  return phases;
});
