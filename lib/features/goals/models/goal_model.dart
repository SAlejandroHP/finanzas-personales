import 'package:flutter/material.dart';

/// Modelo que representa una Meta de Ahorro.
class GoalModel {
  final String id;
  final String userId;
  final String title;
  final String? description;
  
  /// Monto total que se desea alcanzar
  final double targetAmount;
  
  /// Monto que se ha ahorrado hasta el momento (Actualización en cascada)
  final double currentAmount;
  
  /// Fecha límite para alcanzar la meta (Opcional)
  final DateTime? deadline;
  
  /// Icono representativo (String para mapeo en UI)
  final String icon;
  
  /// Color representativo (Para barras de progreso y acentos)
  final String colorHex;
  
  final DateTime createdAt;
  final DateTime? updatedAt;

  const GoalModel({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.targetAmount,
    this.currentAmount = 0.0,
    this.deadline,
    this.icon = 'savings',
    this.colorHex = '#0A7075',
    required this.createdAt,
    this.updatedAt,
  });

  /// Calcula el porcentaje de progreso (0.0 a 1.0)
  double get progress {
    if (targetAmount <= 0) return 0.0;
    final p = currentAmount / targetAmount;
    return p > 1.0 ? 1.0 : p;
  }

  /// Indica si la meta ya fue alcanzada
  bool get isCompleted => currentAmount >= targetAmount;

  /// Calcula cuánto falta para llegar a la meta
  double get remainingAmount => targetAmount - currentAmount;

  /// Sugiere un ahorro mensual si hay una fecha límite
  double? get suggestedMonthlySavings {
    if (deadline == null || isCompleted) return null;
    
    final now = DateTime.now();
    if (deadline!.isBefore(now)) return remainingAmount;

    final monthsDifference = ((deadline!.year - now.year) * 12) + deadline!.month - now.month;
    
    // Si falta menos de un mes, el objetivo es el monto restante completo
    final divisor = monthsDifference <= 0 ? 1 : monthsDifference;
    return remainingAmount / divisor;
  }

  GoalModel copyWith({
    String? title,
    String? description,
    double? targetAmount,
    double? currentAmount,
    DateTime? deadline,
    String? icon,
    String? colorHex,
    DateTime? updatedAt,
  }) {
    return GoalModel(
      id: this.id,
      userId: this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      deadline: deadline ?? this.deadline,
      icon: icon ?? this.icon,
      colorHex: colorHex ?? this.colorHex,
      createdAt: this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'target_amount': targetAmount,
      'current_amount': currentAmount,
      'deadline': deadline?.toIso8601String(),
      'icon': icon,
      'color_hex': colorHex,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory GoalModel.fromJson(Map<String, dynamic> json) {
    return GoalModel(
      id: json['id'],
      userId: json['user_id'],
      title: json['title'],
      description: json['description'],
      targetAmount: (json['target_amount'] as num).toDouble(),
      currentAmount: (json['current_amount'] as num).toDouble(),
      deadline: json['deadline'] != null ? DateTime.parse(json['deadline']) : null,
      icon: json['icon'] ?? 'savings',
      colorHex: json['color_hex'] ?? '#0A7075',
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }
}
