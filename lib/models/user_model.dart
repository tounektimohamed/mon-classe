// models/user_model.dart
class UserModel {
  final String uid;
  final String email;
  final String firstName;
  final String lastName;
  final String role; // 'teacher' or 'parent'
  final String? profileImageUrl;
  final List<String> classIds; // ← CHANGEMENT : Liste d'IDs de classes
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.profileImageUrl,
    required this.classIds, // ← CHANGEMENT
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'role': role,
      'profileImageUrl': profileImageUrl,
      'classIds': classIds, // ← CHANGEMENT
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      role: map['role'] ?? '',
      profileImageUrl: map['profileImageUrl'],
      classIds: List<String>.from(map['classIds'] ?? []), // ← CHANGEMENT
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
    );
  }

  // Méthode utilitaire pour vérifier si l'utilisateur a des classes
  bool get hasClasses => classIds.isNotEmpty;
  
  // Pour la rétrocompatibilité (si vous avez encore du code qui utilise classId)
  String? get classId => classIds.isNotEmpty ? classIds.first : null;
}