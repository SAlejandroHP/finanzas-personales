/// Modelo de datos para una deuda externa o préstamo.
class DebtModel {
  /// ID único de la deuda
  final String id;

  /// ID del usuario propietario
  final String userId;

  /// Nombre de la deuda (ej. "Préstamo personal", "Deuda Totalplay")
  final String nombre;

  /// Tipo de deuda: 'prestamo_personal', 'prestamo_bancario', 'servicio', 'otro'
  final String tipo;

  /// Monto total de la deuda
  final double montoTotal;

  /// Monto que queda por pagar
  final double montoRestante;

  /// Fecha de vencimiento (opcional)
  final DateTime? fechaVencimiento;

  /// ID de la cuenta asociada (opcional, para pagos automáticos o tarjetas)
  final String? cuentaAsociadaId;

  /// Notas o descripción adicional
  final String? descripcion;

  /// Estado de la deuda: 'activa', 'pagada', 'vencida'
  final String estado;

  /// Fecha de creación
  final DateTime createdAt;

  /// Fecha de última actualización
  final DateTime? updatedAt;

  const DebtModel({
    required this.id,
    required this.userId,
    required this.nombre,
    required this.tipo,
    required this.montoTotal,
    required this.montoRestante,
    this.fechaVencimiento,
    this.cuentaAsociadaId,
    this.descripcion,
    required this.estado,
    required this.createdAt,
    this.updatedAt,
  });

  /// Valores permitidos para el campo 'tipo'
  static const List<String> tiposDeuda = [
    'prestamo_personal',
    'prestamo_bancario',
    'servicio',
    'otro',
  ];

  /// Crea una instancia desde un JSON de Supabase
  factory DebtModel.fromJson(Map<String, dynamic> json) {
    return DebtModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      nombre: json['nombre'] as String,
      tipo: json['tipo'] ?? 'otro',
      montoTotal: (json['monto_total'] as num).toDouble(),
      montoRestante: (json['monto_restante'] as num).toDouble(),
      fechaVencimiento: json['fecha_vencimiento'] != null
          ? DateTime.parse(json['fecha_vencimiento'] as String)
          : null,
      cuentaAsociadaId: json['cuenta_asociada_id'] as String?,
      descripcion: json['descripcion'] as String?,
      estado: json['estado'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// Convierte la instancia a JSON para enviar a Supabase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'nombre': nombre,
      'tipo': tipo,
      'monto_total': montoTotal,
      'monto_restante': montoRestante,
      'fecha_vencimiento': fechaVencimiento?.toIso8601String(),
      'cuenta_asociada_id': cuentaAsociadaId,
      'descripcion': descripcion,
      'estado': estado,
      'created_at': createdAt.toIso8601String(),
      // 'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Crea una copia con campos modificados
  DebtModel copyWith({
    String? id,
    String? userId,
    String? nombre,
    String? tipo,
    double? montoTotal,
    double? montoRestante,
    DateTime? fechaVencimiento,
    String? cuentaAsociadaId,
    String? descripcion,
    String? estado,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DebtModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      nombre: nombre ?? this.nombre,
      tipo: tipo ?? this.tipo,
      montoTotal: montoTotal ?? this.montoTotal,
      montoRestante: montoRestante ?? this.montoRestante,
      fechaVencimiento: fechaVencimiento ?? this.fechaVencimiento,
      cuentaAsociadaId: cuentaAsociadaId ?? this.cuentaAsociadaId,
      descripcion: descripcion ?? this.descripcion,
      estado: estado ?? this.estado,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'DebtModel(nombre: $nombre, restante: $montoRestante)';
  }
}
