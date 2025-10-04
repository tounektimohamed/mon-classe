// models/class_model.dart
class ClassModel {
  final String id;
  final String name;
  final String description;
  final String teacherId;
  final String teacherName;
  final DateTime createdAt;
  final List<String> studentIds;
  final String subject;
  final String schoolName;

  ClassModel({
    required this.id,
    required this.name,
    required this.description,
    required this.teacherId,
    required this.teacherName,
    required this.createdAt,
    this.studentIds = const [],
    this.subject = '',
    this.schoolName = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'studentIds': studentIds,
      'subject': subject,
      'schoolName': schoolName,
    };
  }

  factory ClassModel.fromMap(Map<String, dynamic> map) {
    return ClassModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      teacherId: map['teacherId'] ?? '',
      teacherName: map['teacherName'] ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      studentIds: List<String>.from(map['studentIds'] ?? []),
      subject: map['subject'] ?? '',
      schoolName: map['schoolName'] ?? '',
    );
  }
}