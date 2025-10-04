// models/message_model.dart
class Message {
  final String id;
  final String senderId;
  final String receiverId;
  final String studentId;
  final String content;
  final DateTime timestamp;
  final bool isRead;
  final List<String> participants;
  final String? messageType; // 'text', 'image', 'file'
  final String? fileUrl; // lien Firebase Storage
  final String? fileBase64; // 🔥 image encodée en base64 (sauvegardée dans Firestore)

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.studentId,
    required this.content,
    required this.timestamp,
    this.isRead = false,
    required this.participants,
    this.messageType = 'text',
    this.fileUrl,
    this.fileBase64,
  });

  /// 🔄 Convertir en Map pour Firestore
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
      'messageType': messageType,
      'fileUrl': fileUrl,
      'fileBase64': fileBase64,
    };
  }

  /// 🔁 Recréer un Message à partir d'une Map Firestore
  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'] ?? '',
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      studentId: map['studentId'] ?? '',
      content: map['content'] ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? 0),
      isRead: map['isRead'] ?? false,
      participants: List<String>.from(map['participants'] ?? []),
      messageType: map['messageType'] ?? 'text',
      fileUrl: map['fileUrl'],
      fileBase64: map['fileBase64'], // ✅ ajout
    );
  }

  /// 🧩 Créer une copie modifiée du message
  Message copyWith({
    bool? isRead,
    String? fileUrl,
    String? fileBase64,
  }) {
    return Message(
      id: id,
      senderId: senderId,
      receiverId: receiverId,
      studentId: studentId,
      content: content,
      timestamp: timestamp,
      isRead: isRead ?? this.isRead,
      participants: participants,
      messageType: messageType,
      fileUrl: fileUrl ?? this.fileUrl,
      fileBase64: fileBase64 ?? this.fileBase64,
    );
  }
}
