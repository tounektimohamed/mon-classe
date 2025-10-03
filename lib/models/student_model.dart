class Student {
  final String id;
  final String firstName;
  final String lastName;
  final String classId;
  final String? parentId;
  final DateTime createdAt;

  Student({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.classId,
    this.parentId,
    required this.createdAt,
  });

  String get fullName => '$firstName $lastName';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'classId': classId,
      'parentId': parentId,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory Student.fromMap(Map<String, dynamic> map) {
    return Student(
      id: map['id'] ?? '',
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      classId: map['classId'] ?? '',
      parentId: map['parentId'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
    );
  }
}