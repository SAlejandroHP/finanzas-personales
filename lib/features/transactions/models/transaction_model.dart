/// Modelo de datos para una transacción financiera.
/// Representa un movimiento de dinero en una cuenta.
class TransactionModel {
  /// ID único de la transacción
  final String id;

  /// ID del usuario propietario de la transacción
  final String userId;

  /// Tipo de transacción: 'gasto', 'ingreso', 'transferencia', 'deuda_pago', 'meta_aporte'
  final String tipo;

  /// Monto de la transacción
  final double monto;

  /// Fecha de la transacción
  final DateTime fecha;

  /// Estado de la transacción: 'pendiente', 'completada', 'cancelada'
  final String estado;

  /// Descripción de la transacción
  final String? descripcion;

  /// ID de la cuenta origen
  final String cuentaOrigenId;

  /// ID de la cuenta destino (para transferencias)
  final String? cuentaDestinoId;

  /// ID de la categoría
  final String? categoriaId;

  /// ID de la deuda asociada (si aplica)
  final String? deudaId;

  /// ID de la meta asociada (si aplica)
  final String? metaId;

  /// Fecha de creación de la transacción
  final DateTime createdAt;

  /// Fecha de última actualización
  final DateTime? updatedAt;

  /// Indica si la transacción es recurrente
  final bool isRecurring;

  /// Regla de recurrencia: 'monthly_day_15', 'weekly', etc.
  final String? recurringRule;

  /// Fecha de la próxima ocurrencia
  final DateTime? nextOccurrence;

  /// Fecha de la última ocurrencia (o generación)
  final DateTime? lastOccurrence;

  /// Indica si se debe completar automáticamente cuando llegue la fecha
  final bool autoComplete;

  const TransactionModel({
    required this.id,
    required this.userId,
    required this.tipo,
    required this.monto,
    required this.fecha,
    required this.estado,
    this.descripcion,
    required this.cuentaOrigenId,
    this.cuentaDestinoId,
    this.categoriaId,
    this.deudaId,
    this.metaId,
    required this.createdAt,
    this.updatedAt,
    this.isRecurring = false,
    this.recurringRule,
    this.nextOccurrence,
    this.lastOccurrence,
    this.autoComplete = false,
    this.weekendAdjustment = false,
  });

  /// Indica si se debe ajustar al viernes si cae en fin de semana
  final bool weekendAdjustment;

  /// Valores permitidos para el campo 'tipo'
  static const List<String> tiposPermitidos = [
    'gasto',
    'ingreso',
    'transferencia',
    'deuda_pago',
    'meta_aporte',
  ];

  /// Valores permitidos para el campo 'estado'
  static const List<String> estadosPermitidos = [
    'pendiente',
    'completa',
    'cancelada',
  ];

  /// Crea una instancia de TransactionModel desde un JSON de Supabase
  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    // Mapeo inverso: Si es 'transferencia' pero tiene deuda_id o meta_id, recuperar tipo original
    String tipoFinal = json['tipo'] as String;
    if (tipoFinal == 'transferencia') {
      if (json['deuda_id'] != null) tipoFinal = 'deuda_pago';
      else if (json['meta_id'] != null) tipoFinal = 'meta_aporte';
    }

    return TransactionModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      tipo: tipoFinal,
      monto: (json['monto'] as num).toDouble(),
      fecha: DateTime.parse(json['fecha'] as String),
      estado: json['estado'] as String,
      descripcion: json['descripcion'] as String?,
      cuentaOrigenId: json['cuenta_origen_id'] as String,
      cuentaDestinoId: json['cuenta_destino_id'] as String?,
      categoriaId: json['categoria_id'] as String?,
      deudaId: json['deuda_id'] as String?,
      metaId: json['meta_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      isRecurring: json['is_recurring'] as bool? ?? false,
      recurringRule: json['recurring_rule'] as String?,
      nextOccurrence: json['next_occurrence'] != null
          ? DateTime.parse(json['next_occurrence'] as String)
          : null,
      lastOccurrence: json['last_occurrence'] != null
          ? DateTime.parse(json['last_occurrence'] as String)
          : null,
      autoComplete: json['auto_complete'] as bool? ?? false,
      weekendAdjustment: json['weekend_adjustment'] as bool? ?? false,
    );
  }

  /// Convierte la instancia a JSON para enviar a Supabase
  Map<String, dynamic> toJson() {
    // Mapeo para DB: La DB solo acepta 'gasto', 'ingreso', 'transferencia'
    // 'deuda_pago' y 'meta_aporte' se guardan como 'transferencia'
    String tipoDB = tipo;
    if (tipo == 'deuda_pago' || tipo == 'meta_aporte') {
      tipoDB = 'transferencia';
    }

    return {
      'id': id,
      'user_id': userId,
      'tipo': tipoDB,
      'monto': monto,
      'fecha': fecha.toIso8601String(),
      'estado': estado,
      'descripcion': descripcion,
      'cuenta_origen_id': cuentaOrigenId,
      'cuenta_destino_id': cuentaDestinoId,
      'categoria_id': categoriaId,
      'deuda_id': deudaId,
      'meta_id': metaId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'is_recurring': isRecurring,
      'recurring_rule': recurringRule,
      'next_occurrence': nextOccurrence?.toIso8601String(),
      'last_occurrence': lastOccurrence?.toIso8601String(),
      'auto_complete': autoComplete,
      'weekend_adjustment': weekendAdjustment,
    };
  }

  /// Crea una copia de la transacción con algunos campos modificados
  TransactionModel copyWith({
    String? id,
    String? userId,
    String? tipo,
    double? monto,
    DateTime? fecha,
    String? estado,
    String? descripcion,
    String? cuentaOrigenId,
    String? cuentaDestinoId,
    String? categoriaId,
    String? deudaId,
    String? metaId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isRecurring,
    String? recurringRule,
    DateTime? nextOccurrence,
    DateTime? lastOccurrence,
    bool? autoComplete,
    bool? weekendAdjustment,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      tipo: tipo ?? this.tipo,
      monto: monto ?? this.monto,
      fecha: fecha ?? this.fecha,
      estado: estado ?? this.estado,
      descripcion: descripcion ?? this.descripcion,
      cuentaOrigenId: cuentaOrigenId ?? this.cuentaOrigenId,
      cuentaDestinoId: cuentaDestinoId ?? this.cuentaDestinoId,
      categoriaId: categoriaId ?? this.categoriaId,
      deudaId: deudaId ?? this.deudaId,
      metaId: metaId ?? this.metaId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringRule: recurringRule ?? this.recurringRule,
      nextOccurrence: nextOccurrence ?? this.nextOccurrence,
      lastOccurrence: lastOccurrence ?? this.lastOccurrence,
      autoComplete: autoComplete ?? this.autoComplete,
      weekendAdjustment: weekendAdjustment ?? this.weekendAdjustment,
    );
  }

  @override
  String toString() {
    return 'TransactionModel(id: $id, tipo: $tipo, monto: $monto, fecha: $fecha, isRecurring: $isRecurring)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is TransactionModel &&
        other.id == id &&
        other.userId == userId &&
        other.tipo == tipo &&
        other.monto == monto &&
        other.fecha == fecha &&
        other.estado == estado &&
        other.descripcion == descripcion &&
        other.cuentaOrigenId == cuentaOrigenId &&
        other.cuentaDestinoId == cuentaDestinoId &&
        other.categoriaId == categoriaId &&
        other.deudaId == deudaId &&
        other.metaId == metaId &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.isRecurring == isRecurring &&
        other.recurringRule == recurringRule &&
        other.nextOccurrence == nextOccurrence &&
        other.lastOccurrence == lastOccurrence &&
        other.autoComplete == autoComplete &&
        other.weekendAdjustment == weekendAdjustment;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      userId,
      tipo,
      monto,
      fecha,
      estado,
      descripcion,
      cuentaOrigenId,
      cuentaDestinoId,
      categoriaId,
      deudaId,
      metaId,
      createdAt,
      updatedAt,
      isRecurring,
      recurringRule,
      nextOccurrence,
      lastOccurrence,
      autoComplete,
      weekendAdjustment,
    );
  }
}
