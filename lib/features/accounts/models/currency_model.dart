/// Modelo para representar una moneda en el sistema.
class CurrencyModel {
  final String id;
  final String codigo;
  final String nombre;
  final String simbolo;

  CurrencyModel({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.simbolo,
  });

  factory CurrencyModel.fromJson(Map<String, dynamic> json) {
    return CurrencyModel(
      id: json['id'] as String,
      codigo: json['codigo'] as String,
      nombre: json['nombre'] as String,
      simbolo: json['simbolo'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'codigo': codigo,
      'nombre': nombre,
      'simbolo': simbolo,
    };
  }
}
