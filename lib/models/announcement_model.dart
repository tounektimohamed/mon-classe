class Announcement {
  final String id;
  final String classId;
  final String authorId;
  final String title;
  final String content;
  final DateTime timestamp;
  final List<String> attachments;

  Announcement({
    required this.id,
    required this.classId,
    required this.authorId,
    required this.title,
    required this.content,
    required this.timestamp,
    this.attachments = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'classId': classId,
      'authorId': authorId,
      'title': title,
      'content': content,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'attachments': attachments,
    };
  }

  factory Announcement.fromMap(Map<String, dynamic> map) {
    return Announcement(
      id: map['id'] ?? '',
      classId: map['classId'] ?? '',
      authorId: map['authorId'] ?? '',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      attachments: List<String>.from(map['attachments'] ?? []),
    );
  }
}