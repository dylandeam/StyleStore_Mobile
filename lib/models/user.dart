class User {
  final int id;
  final String email;
  final String name;
  final bool isActive;
  final DateTime createdAt;

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.isActive,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      email: json['email'] as String,
      name: json['name'] as String,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
