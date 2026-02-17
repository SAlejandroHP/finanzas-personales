/// Modelo que representa un usuario de la aplicación.
/// Contiene los datos básicos del perfil del usuario.

class UserModel {
  /// ID único del usuario
  final String id;

  /// Correo electrónico del usuario
  final String? email;

  /// Nombre completo del usuario
  final String? fullName;

  /// URL del avatar/foto de perfil del usuario
  final String? avatarUrl;

  /// Constructor de UserModel
  UserModel({
    required this.id,
    this.email,
    this.fullName,
    this.avatarUrl,
  });

  /// Crea una copia de UserModel con campos opcionales modificados
  UserModel copyWith({
    String? id,
    String? email,
    String? fullName,
    String? avatarUrl,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  /// Convierte UserModel a un Map (útil para JSON)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'fullName': fullName,
      'avatarUrl': avatarUrl,
    };
  }

  /// Crea un UserModel desde un Map (útil para JSON)
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as String,
      email: map['email'] as String?,
      fullName: map['fullName'] as String?,
      avatarUrl: map['avatarUrl'] as String?,
    );
  }

  @override
  String toString() {
    return 'UserModel(id: $id, email: $email, fullName: $fullName, avatarUrl: $avatarUrl)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is UserModel &&
        other.id == id &&
        other.email == email &&
        other.fullName == fullName &&
        other.avatarUrl == avatarUrl;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        email.hashCode ^
        fullName.hashCode ^
        avatarUrl.hashCode;
  }
}
