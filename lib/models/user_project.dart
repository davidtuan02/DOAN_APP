// import 'package:flutter/material.dart'; // Remove if not needed

class UserProject {
  final String id;
  final String? userId;
  final String? userName;
  final String? userEmail;
  final int? accessLevel; // Change type to int?
  // Add other fields if necessary based on the JSON, e.g., createdAt, updatedAt

  UserProject({
    required this.id,
    this.userId,
    this.userName,
    this.userEmail,
    this.accessLevel,
  });

  factory UserProject.fromJson(Map<String, dynamic> json) {
    print('UserProject.fromJson input: $json');
    print('UserProject id type: ${json['id']?.runtimeType}');
    print('UserProject userId type: ${json['userId']?.runtimeType}');
    print('UserProject userName type: ${json['userName']?.runtimeType}');
    print('UserProject userEmail type: ${json['userEmail']?.runtimeType}');
    print('UserProject accessLevel type: ${json['accessLevel']?.runtimeType}');

    return UserProject(
      id: json['id'].toString(),
      userId: json['userId']?.toString(),
      userName: json['userName'] as String?,
      userEmail: json['userEmail'] as String?,
      accessLevel: json['accessLevel'] as int?, // Map as int
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'accessLevel': accessLevel,
    };
  }
}

// Remove the nested User class as it's not in this API response
// class User {...} 