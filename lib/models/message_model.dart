class Message {
  final String id;
  final String senderId;
  final String receiverId;
  final String studentId;
  final String content;
  final DateTime timestamp;
  final bool isRead;
  final List<String> participants;

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.studentId,
    required this.content,
    required this.timestamp,
    required this.isRead,
    required this.participants,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'studentId': studentId,
      'content': content,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'isRead': isRead,
      'participants': participants,
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'] ?? '',
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      studentId: map['studentId'] ?? '',
      content: map['content'] ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      isRead: map['isRead'] ?? false,
      participants: List<String>.from(map['participants'] ?? []),
    );
  }
}