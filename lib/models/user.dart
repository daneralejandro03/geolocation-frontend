class User {

  final int id;
  final String name;
  final String email;
  final String role;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });


  factory User.fromJson(Map<String, dynamic> json) {
    if (json['idUser'] == null || json['name'] == null || json['email'] == null || json['rol'] == null) {
      throw const FormatException("El JSON del usuario no contiene los campos requeridos.");
    }

    return User(
      id: json['idUser'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['rol'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'idUser': id,
      'name': name,
      'email': email,
      'rol': role,
    };
  }
}
