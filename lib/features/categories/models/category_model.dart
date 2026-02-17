/// Modelo que representa una categoría de ingresos o gastos.
class CategoryModel {
  final String id;
  final String userId;
  final String nombre;
  final String tipo; // 'ingreso' o 'gasto'
  final String? icono; // Nombre del ícono Material (ej: 'restaurant_outlined')
  final String? color; // Color en formato hex (ej: '#FF8B6A')
  final DateTime createdAt;

  CategoryModel({
    required this.id,
    required this.userId,
    required this.nombre,
    required this.tipo,
    this.icono,
    this.color,
    required this.createdAt,
  });

  /// Convierte un JSON (desde Supabase) a CategoryModel
  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      nombre: json['nombre'] as String,
      tipo: json['tipo'] as String,
      icono: json['icono'] as String?,
      color: json['color'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Convierte CategoryModel a JSON para enviar a Supabase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'nombre': nombre,
      'tipo': tipo,
      'icono': icono,
      'color': color,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Crea una copia con campos opcionales modificados
  CategoryModel copyWith({
    String? id,
    String? userId,
    String? nombre,
    String? tipo,
    String? icono,
    String? color,
    DateTime? createdAt,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      nombre: nombre ?? this.nombre,
      tipo: tipo ?? this.tipo,
      icono: icono ?? this.icono,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'CategoryModel(id: $id, nombre: $nombre, tipo: $tipo)';
}
