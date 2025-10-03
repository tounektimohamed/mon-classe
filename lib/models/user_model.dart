class UserModel {
  final String uid;
  final String email;
  final String firstName;
  final String lastName;
  final String role; // 'teacher' or 'parent'
  final String? profileImageUrl;
  final String? classId; // For teachers
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.profileImageUrl,
    this.classId,
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
      'classId': classId,
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
      classId: map['classId'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
    );
  }
}