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

  /// ID del banco
  final String? bancoId;

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

  /// Indica si esta cuenta es la predeterminada para nuevas transacciones
  final bool isDefault;

  /// Últimos 4 dígitos de la cuenta para identificación rápida (IA)
  final String? lastFour;

  /// Etiquetas de búsqueda o apodos (IA)
  final List<String> tags;

  /// Indica si es una cuenta puramente virtual u organizativa
  final bool isVirtual;

  /// Día del mes para la fecha de corte (ej. 1-31), aplica principalmente para tarjetas de crédito
  final int? fechaCorte;

  /// Día del mes para la fecha límite de pago (ej. 1-31), aplica principalmente para tarjetas de crédito
  final int? fechaLimitePago;

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
    this.isDefault = false,
    this.lastFour,
    this.tags = const [],
    this.isVirtual = false,
    this.fechaCorte,
    this.fechaLimitePago,
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
      bancoId: json['banco_id'] as String?,
      bancoNombre: json['banco_nombre'] as String?,
      bancoLogo: json['banco_logo'] as String?,
      monedaId: json['moneda_id'] as String,
      saldoInicial: (json['saldo_inicial'] as num).toDouble(),
      saldoActual: (json['saldo_actual'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      isDefault: json['is_default'] as bool? ?? false,
      lastFour: json['last_four'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      isVirtual: json['is_virtual'] as bool? ?? false,
      fechaCorte: json['fecha_corte'] as int?,
      fechaLimitePago: json['fecha_limite_pago'] as int?,
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
      'is_default': isDefault,
      'last_four': lastFour,
      'tags': tags,
      'is_virtual': isVirtual,
      'fecha_corte': fechaCorte,
      'fecha_limite_pago': fechaLimitePago,
    };
  }

  /// Crea una copia de la cuenta con algunos campos modificados
  AccountModel copyWith({
    String? id,
    String? userId,
    String? nombre,
    String? tipo,
    String? bancoId,
    String? bancoNombre,
    String? bancoLogo,
    String? monedaId,
    double? saldoInicial,
    double? saldoActual,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDefault,
    String? lastFour,
    List<String>? tags,
    bool? isVirtual,
    int? fechaCorte,
    int? fechaLimitePago,
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
      isDefault: isDefault ?? this.isDefault,
      lastFour: lastFour ?? this.lastFour,
      tags: tags ?? this.tags,
      isVirtual: isVirtual ?? this.isVirtual,
      fechaCorte: fechaCorte ?? this.fechaCorte,
      fechaLimitePago: fechaLimitePago ?? this.fechaLimitePago,
    );
  }

  @override
  String toString() {
    return 'AccountModel(id: $id, nombre: $nombre, tipo: $tipo, saldo: $saldoActual, isDefault: $isDefault)';
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
        other.updatedAt == updatedAt &&
        other.isDefault == isDefault &&
        other.lastFour == lastFour &&
        _listaTagsIguales(other.tags, tags) &&
        other.isVirtual == isVirtual &&
        other.fechaCorte == fechaCorte &&
        other.fechaLimitePago == fechaLimitePago;
  }

  bool _listaTagsIguales(List<String> list1, List<String> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
        if (list1[i] != list2[i]) return false;
    }
    return true;
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
      isDefault,
      lastFour,
      Object.hashAll(tags),
      isVirtual,
      fechaCorte,
      fechaLimitePago,
    );
  }
}

/// Extensión de lógica financiera (finzAi) para Tarjetas de Crédito
extension CreditCardHacks on AccountModel {
  /// 1. Calcula cuántos días exactos faltan para la fecha de pago
  int get diasParaPago {
    if (fechaLimitePago == null || fechaCorte == null) return -1;
    final hoy = DateTime.now();
    
    // Si la fecha actual es igual o menor al límite, el pago es en este mes
    // IMPORTANTE: Esto asume que el pago corresponde al periodo actual si hoy es < fecha límite
    if (hoy.day <= fechaLimitePago!) {
      return fechaLimitePago! - hoy.day;
    } else {
      // Si ya pasó, calculamos para el mes siguiente
      final proximoMes = DateTime(hoy.year, hoy.month + 1, fechaLimitePago!);
      return proximoMes.difference(hoy).inDays;
    }
  }

  /// 2. Determina si es el momento ideal para gastar (Ventana de Oro: 1 a 5 días post-corte)
  bool get esVentanaDeOro {
    if (fechaCorte == null) return false;
    final hoy = DateTime.now().day;
    
    // Es el mejor momento si estamos en los 1 a 5 días posteriores al corte
    int diasDespuesDelCorte = hoy - fechaCorte!;
    if (diasDespuesDelCorte < 0) {
      // Manejo de cambio de mes (ej. si cortó el 28 y hoy es 2)
      // Restamos el día de hoy con el día del corte para saber si estamos en la ventana
      // Asumiremos 30 días en promedio para no complicar el cambio de mes
      diasDespuesDelCorte += 30;
    }
    
    return diasDespuesDelCorte >= 1 && diasDespuesDelCorte <= 5;
  }
}
