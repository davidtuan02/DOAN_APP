enum UserRole {
  MANAGER,
  LEADER,
  MEMBER
}

class User {
  final String id;
  final String firstName;
  final String lastName;
  final int age;
  final String email;
  final String username;
  final UserRole role;

  User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.age,
    required this.email,
    required this.username,
    required this.role,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String? ?? '',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      age: json['age'] as int? ?? 0,
      email: json['email'] as String? ?? '',
      username: json['username'] as String? ?? '',
      role: _parseRole(json['role'] as String?),
    );
  }

  static UserRole _parseRole(String? roleStr) {
    if (roleStr == null) return UserRole.MEMBER;
    
    switch (roleStr.toUpperCase()) {
      case 'MANAGER':
        return UserRole.MANAGER;
      case 'LEADER':
        return UserRole.LEADER;
      case 'MEMBER':
        return UserRole.MEMBER;
      default:
        return UserRole.MEMBER;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'age': age,
      'email': email,
      'username': username,
      'role': role.toString().split('.').last,
    };
  }
} 