/// Modelo simple para representar un banco disponible en Belvo
class BankModel {
  final int id;
  final String name;
  final String displayName;
  final String? logo;
  final String? iconLogo;
  final String? website;
  final String primaryColor;
  final List<String> countryCodes;
  final String status;

  BankModel({
    required this.id,
    required this.name,
    required this.displayName,
    this.logo,
    this.iconLogo,
    this.website,
    required this.primaryColor,
    required this.countryCodes,
    required this.status,
  });

  factory BankModel.fromJson(Map<String, dynamic> json) {
    return BankModel(
      id: json['id'] as int,
      name: json['name'] as String,
      displayName: json['display_name'] as String,
      logo: json['logo'] as String?,
      iconLogo: json['icon_logo'] as String?,
      website: json['website'] as String?,
      primaryColor: (json['primary_color'] as String?) ?? '#000000',
      countryCodes: List<String>.from(json['country_codes'] as List? ?? []),
      status: json['status'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'display_name': displayName,
      'logo': logo,
      'icon_logo': iconLogo,
      'website': website,
      'primary_color': primaryColor,
      'country_codes': countryCodes,
      'status': status,
    };
  }

  @override
  String toString() => displayName;
}
