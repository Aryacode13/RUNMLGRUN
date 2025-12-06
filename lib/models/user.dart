class User {
  final String id;
  final String? username;
  final String? firstname;
  final String? lastname;
  final String? profilePicture;
  final String? emailUsers; // Email untuk login email/Google
  final String role;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    this.username,
    this.firstname,
    this.lastname,
    this.profilePicture,
    this.emailUsers,
    this.role = 'user',
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      username: json['username'] as String?,
      firstname: json['firstname'] as String?,
      lastname: json['lastname'] as String?,
      profilePicture: json['profile_picture'] as String?,
      emailUsers: json['email_users'] as String?,
      role: json['role'] as String? ?? 'user',
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'firstname': firstname,
      'lastname': lastname,
      'profile_picture': profilePicture,
      'email_users': emailUsers,
      'role': role,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String get fullName {
    if (firstname != null && lastname != null) {
      return '$firstname $lastname';
    }
    return username ?? 'User';
  }
}

