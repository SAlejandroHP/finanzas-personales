/// Modelo de datos para una cuenta financiera.
/// Representa una cuenta bancaria, tarjeta de crédito, efectivo, etc.
class AccountModel {
  /// ID único de la cuenta
  final String id;

  /// ID del usuario propietario de la cuenta
  final String userId;

  /// Nombre descriptivo de la cuenta
  final String nombre;

  /// Tipo de cuenta: 'efectivo', 'chequera', 'ahorro', 'tarjeta_credito', 'inversion', 'otro'
  final String tipo;

  /// ID del banco (de Belvo API)
  final int? bancoId;

  /// Nombre del banco
  final String? bancoNombre;

  /// Logo del banco
  final String? bancoLogo;

  /// ID de la moneda asociada a esta cuenta
  final String monedaId;

  /// Saldo inicial cuando se creó la cuenta
  final double saldoInicial;

  /// Saldo actual de la cuenta
  final double saldoActual;

  /// Fecha de creación de la cuenta
  final DateTime createdAt;

  /// Fecha de última actualización
  final DateTime? updatedAt;

  const AccountModel({
    required this.id,
    required this.userId,
    required this.nombre,
    required this.tipo,
    this.bancoId,
    this.bancoNombre,
    this.bancoLogo,
    required this.monedaId,
    required this.saldoInicial,
    required this.saldoActual,
    required this.createdAt,
    this.updatedAt,
  });

  /// Valores permitidos para el campo 'tipo'
  static const List<String> tiposPermitidos = [
    'efectivo',
    'chequera',
    'ahorro',
    'tarjeta_credito',
    'inversion',
    'otro',
  ];

  /// Crea una instancia de AccountModel desde un JSON de Supabase
  factory AccountModel.fromJson(Map<String, dynamic> json) {
    return AccountModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      nombre: json['nombre'] as String,
      tipo: json['tipo'] as String,
      bancoId: json['banco_id'] as int?,
      bancoNombre: json['banco_nombre'] as String?,
      bancoLogo: json['banco_logo'] as String?,
      monedaId: json['moneda_id'] as String,
      saldoInicial: (json['saldo_inicial'] as num).toDouble(),
      saldoActual: (json['saldo_actual'] as num).toDouble(),
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
      'banco_id': bancoId,
      'banco_nombre': bancoNombre,
      'banco_logo': bancoLogo,
      'moneda_id': monedaId,
      'saldo_inicial': saldoInicial,
      'saldo_actual': saldoActual,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Crea una copia de la cuenta con algunos campos modificados
  AccountModel copyWith({
    String? id,
    String? userId,
    String? nombre,
    String? tipo,
    int? bancoId,
    String? bancoNombre,
    String? bancoLogo,
    String? monedaId,
    double? saldoInicial,
    double? saldoActual,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AccountModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      nombre: nombre ?? this.nombre,
      tipo: tipo ?? this.tipo,
      bancoId: bancoId ?? this.bancoId,
      bancoNombre: bancoNombre ?? this.bancoNombre,
      bancoLogo: bancoLogo ?? this.bancoLogo,
      monedaId: monedaId ?? this.monedaId,
      saldoInicial: saldoInicial ?? this.saldoInicial,
      saldoActual: saldoActual ?? this.saldoActual,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'AccountModel(id: $id, nombre: $nombre, tipo: $tipo, saldo: $saldoActual)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AccountModel &&
        other.id == id &&
        other.userId == userId &&
        other.nombre == nombre &&
        other.tipo == tipo &&
        other.bancoId == bancoId &&
        other.bancoNombre == bancoNombre &&
        other.bancoLogo == bancoLogo &&
        other.monedaId == monedaId &&
        other.saldoInicial == saldoInicial &&
        other.saldoActual == saldoActual &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      userId,
      nombre,
      tipo,
      bancoId,
      bancoNombre,
      bancoLogo,
      monedaId,
      saldoInicial,
      saldoActual,
      createdAt,
      updatedAt,
    );
  }
}
