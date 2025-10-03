class Announcement {
  final String id;
  final String classId;
  final String authorId;
  final String authorName;
  final String title;
  final String content;
  final DateTime timestamp;
  final List<String> attachments;
  final List<Reaction> reactions;
  final List<Comment> comments;

  Announcement({
    required this.id,
    required this.classId,
    required this.authorId,
    required this.authorName,
    required this.title,
    required this.content,
    required this.timestamp,
    this.attachments = const [],
    this.reactions = const [],
    this.comments = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'classId': classId,
      'authorId': authorId,
      'authorName': authorName,
      'title': title,
      'content': content,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'attachments': attachments,
      'reactions': reactions.map((r) => r.toMap()).toList(),
      'comments': comments.map((c) => c.toMap()).toList(),
    };
  }

  factory Announcement.fromMap(Map<String, dynamic> map) {
    return Announcement(
      id: map['id'] ?? '',
      classId: map['classId'] ?? '',
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? '',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      attachments: List<String>.from(map['attachments'] ?? []),
      reactions: List<Reaction>.from(
        (map['reactions'] ?? []).map((r) => Reaction.fromMap(r)),
      ),
      comments: List<Comment>.from(
        (map['comments'] ?? []).map((c) => Comment.fromMap(c)),
      ),
    );
  }

  // Méthodes utilitaires
  int get likesCount => reactions.where((r) => r.type == 'like').length;
  int get commentsCount => comments.length;
  
  bool isLikedBy(String userId) {
    return reactions.any((r) => r.userId == userId && r.type == 'like');
  }
}

class Reaction {
  final String userId;
  final String userName;
  final String type; // 'like', 'love', etc.
  final DateTime timestamp;

  Reaction({
    required this.userId,
    required this.userName,
    required this.type,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'type': type,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory Reaction.fromMap(Map<String, dynamic> map) {
    return Reaction(
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      type: map['type'] ?? 'like',
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
    );
  }
}

class Comment {
  final String id;
  final String userId;
  final String userName;
  final String content;
  final DateTime timestamp;
  final List<Reaction> reactions;
  final List<Comment> replies;

  Comment({
    required this.id,
    required this.userId,
    required this.userName,
    required this.content,
    required this.timestamp,
    this.reactions = const [],
    this.replies = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'content': content,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'reactions': reactions.map((r) => r.toMap()).toList(),
      'replies': replies.map((r) => r.toMap()).toList(),
    };
  }

  factory Comment.fromMap(Map<String, dynamic> map) {
    return Comment(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      content: map['content'] ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      reactions: List<Reaction>.from(
        (map['reactions'] ?? []).map((r) => Reaction.fromMap(r)),
      ),
      replies: List<Comment>.from(
        (map['replies'] ?? []).map((r) => Comment.fromMap(r)),
      ),
    );
  }

  int get likesCount => reactions.where((r) => r.type == 'like').length;
}