import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mon_classe_manegment/services/storage_service.dart';
import '../models/announcement_model.dart';
import '../models/student_model.dart';
import '../models/message_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Gestion des annonces
  Stream<List<Announcement>> getAnnouncements(String classId) {
    return _firestore
        .collection('announcements')
        .where('classId', isEqualTo: classId)
        .snapshots()
        .map((snapshot) {
          final announcements = snapshot.docs
              .map((doc) => Announcement.fromMap(doc.data()))
              .toList();
          
          // Tri côté client par timestamp (plus récent en premier)
          announcements.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          
          return announcements;
        });
  }

  Future<void> createAnnouncement(Announcement announcement) async {
    await _firestore
        .collection('announcements')
        .doc(announcement.id)
        .set(announcement.toMap());
  }

  // SYSTÈME DE RÉACTIONS (LIKE)
  Future<void> toggleLike({
    required String announcementId,
    required String userId,
    required String userName,
  }) async {
    final announcementRef = _firestore.collection('announcements').doc(announcementId);
    
    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(announcementRef);
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      final reactions = List<Map<String, dynamic>>.from(data['reactions'] ?? []);
      
      // Vérifier si l'utilisateur a déjà liké
      final existingIndex = reactions.indexWhere(
        (r) => r['userId'] == userId && r['type'] == 'like'
      );

      if (existingIndex >= 0) {
        // Retirer le like
        reactions.removeAt(existingIndex);
      } else {
        // Ajouter le like
        reactions.add(Reaction(
          userId: userId,
          userName: userName,
          type: 'like',
          timestamp: DateTime.now(),
        ).toMap());
      }

      transaction.update(announcementRef, {'reactions': reactions});
    });
  }

  // SYSTÈME DE COMMENTAIRES
  Future<void> addComment({
    required String announcementId,
    required String userId,
    required String userName,
    required String content,
  }) async {
    final announcementRef = _firestore.collection('announcements').doc(announcementId);
    final commentId = _firestore.collection('announcements').doc().id;

    final newComment = Comment(
      id: commentId,
      userId: userId,
      userName: userName,
      content: content,
      timestamp: DateTime.now(),
    ).toMap();

    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(announcementRef);
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      final comments = List<Map<String, dynamic>>.from(data['comments'] ?? []);
      comments.add(newComment);

      transaction.update(announcementRef, {'comments': comments});
    });
  }

  // RÉPONDRE À UN COMMENTAIRE
  Future<void> addReply({
    required String announcementId,
    required String parentCommentId,
    required String userId,
    required String userName,
    required String content,
  }) async {
    final announcementRef = _firestore.collection('announcements').doc(announcementId);
    final replyId = _firestore.collection('announcements').doc().id;

    final newReply = Comment(
      id: replyId,
      userId: userId,
      userName: userName,
      content: content,
      timestamp: DateTime.now(),
    ).toMap();

    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(announcementRef);
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      final comments = List<Map<String, dynamic>>.from(data['comments'] ?? []);
      
      // Trouver le commentaire parent et ajouter la réponse
      for (int i = 0; i < comments.length; i++) {
        if (comments[i]['id'] == parentCommentId) {
          final replies = List<Map<String, dynamic>>.from(comments[i]['replies'] ?? []);
          replies.add(newReply);
          comments[i]['replies'] = replies;
          break;
        }
      }

      transaction.update(announcementRef, {'comments': comments});
    });
  }

  // SUPPRIMER UN COMMENTAIRE
  Future<void> deleteComment({
    required String announcementId,
    required String commentId,
    required String userId, // Pour vérifier les permissions
  }) async {
    final announcementRef = _firestore.collection('announcements').doc(announcementId);

    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(announcementRef);
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      final comments = List<Map<String, dynamic>>.from(data['comments'] ?? []);
      
      // Trouver et supprimer le commentaire (seulement si c'est le propriétaire)
      for (int i = 0; i < comments.length; i++) {
        if (comments[i]['id'] == commentId && comments[i]['userId'] == userId) {
          comments.removeAt(i);
          break;
        }
      }

      transaction.update(announcementRef, {'comments': comments});
    });
  }

  // Gestion des élèves
  Stream<List<Student>> getStudents(String classId) {
    return _firestore
        .collection('students')
        .where('classId', isEqualTo: classId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Student.fromMap(doc.data()))
            .toList());
  }

  Future<void> addStudent(Student student) async {
    await _firestore
        .collection('students')
        .doc(student.id)
        .set(student.toMap());
  }

  // Gestion des messages
  Stream<List<Message>> getMessages(String currentUserId) {
    return _firestore
        .collection('messages')
        .where('participants', arrayContains: currentUserId)
        .snapshots()
        .map((snapshot) {
          final messages = snapshot.docs
              .map((doc) => Message.fromMap(doc.data()))
              .toList();
          
          messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          
          return messages;
        });
  }

  Stream<List<Message>> getConversationMessages(String currentUserId, String otherUserId) {
    return getMessages(currentUserId).map((allMessages) {
      return allMessages
          .where((message) => message.participants.contains(otherUserId))
          .toList();
    });
  }

  Future<void> sendMessage(Message message) async {
    await _firestore
        .collection('messages')
        .doc(message.id)
        .set(message.toMap());
  }

  Future<void> markMessagesAsRead(String currentUserId, String otherUserId) async {
    final snapshot = await _firestore
        .collection('messages')
        .where('participants', arrayContains: currentUserId)
        .get();

    final batch = _firestore.batch();
    
    for (final doc in snapshot.docs) {
      final message = Message.fromMap(doc.data());
      if (message.senderId == otherUserId && !message.isRead) {
        batch.update(doc.reference, {'isRead': true});
      }
    }
    
    if (snapshot.docs.isNotEmpty) {
      await batch.commit();
    }
  }

  Future<int> getUnreadCount(String currentUserId, String otherUserId) async {
    final snapshot = await _firestore
        .collection('messages')
        .where('participants', arrayContains: currentUserId)
        .get();

    int count = 0;
    for (final doc in snapshot.docs) {
      final message = Message.fromMap(doc.data());
      if (message.senderId == otherUserId && 
          message.participants.contains(otherUserId) && 
          !message.isRead) {
        count++;
      }
    }
    return count;
  }
// Dans FirestoreService
Future<void> updateAnnouncementAttachments({
  required String announcementId,
  required List<String> attachments,
}) async {
  await _firestore
      .collection('announcements')
      .doc(announcementId)
      .update({'attachments': attachments});
}


// Dans FirestoreService - Ajoutez ces méthodes

// SUPPRIMER UNE ANNONCE


// VÉRIFIER SI L'UTILISATEUR EST L'AUTEUR
Future<bool> isUserAuthor(String announcementId, String userId) async {
  try {
    final doc = await _firestore
        .collection('announcements')
        .doc(announcementId)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      return data['authorId'] == userId;
    }
    return false;
  } catch (e) {
    print('❌ Erreur vérification auteur: $e');
    return false;
  }
}
// Dans FirestoreService - Ajouter cette méthode
Future<void> deleteAnnouncement(String announcementId) async {
  try {
    // Supprimer d'abord les fichiers de Storage
    final storageService = StorageService();
    await storageService.deleteAllAnnouncementFiles(announcementId);

    // Supprimer l'annonce principale
    await _firestore
        .collection('announcements')
        .doc(announcementId)
        .delete();

    print('✅ Annonce supprimée: $announcementId');
  } catch (e) {
    print('❌ Erreur suppression annonce: $e');
    throw Exception('Erreur lors de la suppression de l\'annonce: $e');
  }
}
  Stream<List<Map<String, dynamic>>> getConversations(String userId) {
    return _firestore
        .collection('messages')
        .where('participants', arrayContains: userId)
        .snapshots()
        .asyncMap((snapshot) async {
      final conversations = <String, Map<String, dynamic>>{};

      for (final doc in snapshot.docs) {
        final message = Message.fromMap(doc.data());
        final otherUserId = message.senderId == userId 
            ? message.receiverId 
            : message.senderId;

        final conversationKey = '${userId}_$otherUserId';
        
        if (!conversations.containsKey(conversationKey) || 
            message.timestamp.isAfter((conversations[conversationKey]!['lastMessage'] as Message).timestamp)) {
          
          conversations[conversationKey] = {
            'otherUserId': otherUserId,
            'lastMessage': message,
            'unreadCount': await getUnreadCount(userId, otherUserId),
          };
        }
      }

      final conversationList = conversations.values.toList();
      conversationList.sort((a, b) {
        final lastMessageA = a['lastMessage'] as Message;
        final lastMessageB = b['lastMessage'] as Message;
        return lastMessageB.timestamp.compareTo(lastMessageA.timestamp);
      });

      return conversationList;
    });
  }
}