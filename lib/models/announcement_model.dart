import 'dart:convert';

class Announcement {
  final String id;
  final String classId;
  final String authorId;
  final String authorName;
  final String title;
  final String content;
  final DateTime timestamp;
  final List<String> attachments;
  final List<String> base64Images;
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
    this.base64Images = const [],
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
      'base64Images': base64Images,
      'reactions': reactions.map((r) => r.toMap()).toList(),
      'comments': comments.map((c) => c.toMap()).toList(),
    };
  }

  factory Announcement.fromMap(Map<String, dynamic> map) {
    // Gérer le cas où base64Images pourrait être null
    final base64ImagesData = map['base64Images'];
    final List<String> base64ImagesList;
    
    if (base64ImagesData is List) {
      base64ImagesList = List<String>.from(base64ImagesData);
    } else {
      base64ImagesList = [];
    }

    return Announcement(
      id: map['id'] ?? '',
      classId: map['classId'] ?? '',
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? '',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? 0),
      attachments: List<String>.from(map['attachments'] ?? []),
      base64Images: base64ImagesList,
      reactions: List<Reaction>.from(
        (map['reactions'] ?? []).map((r) => Reaction.fromMap(r)),
      ),
      comments: List<Comment>.from(
        (map['comments'] ?? []).map((c) => Comment.fromMap(c)),
      ),
    );
  }

  Announcement copyWith({
    String? id,
    String? classId,
    String? authorId,
    String? authorName,
    String? title,
    String? content,
    DateTime? timestamp,
    List<String>? attachments,
    List<String>? base64Images,
    List<Reaction>? reactions,
    List<Comment>? comments,
  }) {
    return Announcement(
      id: id ?? this.id,
      classId: classId ?? this.classId,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      title: title ?? this.title,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      attachments: attachments ?? this.attachments,
      base64Images: base64Images ?? this.base64Images,
      reactions: reactions ?? this.reactions,
      comments: comments ?? this.comments,
    );
  }

  // Méthodes utilitaires
  int get likesCount => reactions.where((r) => r.type == 'like').length;
  int get commentsCount => comments.length;
  
  bool get hasAttachments => attachments.isNotEmpty || base64Images.isNotEmpty;
  
  bool get hasImages => base64Images.isNotEmpty || 
      attachments.any((url) => _isImageFile(_getFileNameFromUrl(url)));

  bool isLikedBy(String userId) {
    return reactions.any((r) => r.userId == userId && r.type == 'like');
  }

  // Méthodes privées pour la détection des fichiers
  bool _isImageFile(String fileName) {
    final imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'];
    final lowerFileName = fileName.toLowerCase();
    return imageExtensions.any((ext) => lowerFileName.endsWith(ext));
  }

  String _getFileNameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path;
      final segments = path.split('/');
      String fileName = segments.last;
      fileName = Uri.decodeComponent(fileName);
      
      final parts = fileName.split('_');
      if (parts.length > 1) {
        return parts.sublist(1).join('_');
      }
      
      return fileName;
    } catch (e) {
      return 'fichier';
    }
  }
}

class Reaction {
  final String userId;
  final String userName;
  final String type;
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
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? 0),
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
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? 0),
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