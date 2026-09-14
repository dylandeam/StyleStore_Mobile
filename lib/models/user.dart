class User {
  final int id;
  final String email;
  final String name;
  final String? apellido;
  final String? ci;
  final String? telefono;
  final String? direccion;
  final String? foto;
  final String role;
  final bool isActive;
  final DateTime createdAt;

  User({
    required this.id,
    required this.email,
    required this.name,
    this.apellido,
    this.ci,
    this.telefono,
    this.direccion,
    this.foto,
    this.role = 'cliente',
    required this.isActive,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      email: json['email'] as String,
      name: (json['name'] ?? json['nombre'] ?? '') as String,
      apellido: json['apellido'] as String?,
      ci: json['ci'] as String?,
      telefono: json['telefono'] as String?,
      direccion: json['direccion'] as String?,
      foto: json['foto'] as String?,
      role: json['role'] as String? ?? 'cliente',
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'apellido': apellido,
      'ci': ci,
      'telefono': telefono,
      'direccion': direccion,
      'foto': foto,
      'role': role,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
