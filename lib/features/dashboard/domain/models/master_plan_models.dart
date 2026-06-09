import 'package:flutter/material.dart';

enum ActionType {
  income,      // Verde
  expense,     // Naranja/Rojo
  rule,        // Rojo (No usar tarjeta)
  payment,     // Azul/Primario
  leverage,    // Morado/Secundario
  info         // Gris
}

class PlanAction {
  final String label;
  final String description;
  final ActionType type;

  const PlanAction({
    required this.label,
    required this.description,
    required this.type,
  });
}

class PlanMilestone {
  final DateTime date;
  final String title;
  final List<PlanAction> actions;
  final List<String> bulletPoints; // Para "Blindaje Inmediato" u otros listados
  final String? note;

  const PlanMilestone({
    required this.date,
    required this.title,
    this.actions = const [],
    this.bulletPoints = const [],
    this.note,
  });
}

class PlanPhase {
  final String title;
  final String subtitle;
  final List<PlanMilestone> milestones;

  const PlanPhase({
    required this.title,
    required this.subtitle,
    required this.milestones,
  });
}
