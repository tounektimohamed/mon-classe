import 'package:cloud_firestore/cloud_firestore.dart';
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

  // Gestion des messages - Version simplifiée
  Stream<List<Message>> getMessages(String currentUserId) {
    return _firestore
        .collection('messages')
        .where('participants', arrayContains: currentUserId)
        .snapshots()
        .map((snapshot) {
          final messages = snapshot.docs
              .map((doc) => Message.fromMap(doc.data()))
              .toList();
          
          // Tri côté client par timestamp (plus récent en premier)
          messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          
          return messages;
        });
  }

  // Nouvelle méthode pour récupérer les messages d'une conversation spécifique
  Stream<List<Message>> getConversationMessages(String currentUserId, String otherUserId) {
    return getMessages(currentUserId).map((allMessages) {
      // Filtrage côté client pour la conversation spécifique
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

  // Méthode utilitaire pour marquer les messages comme lus
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

  // Méthode pour compter les messages non lus
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

  // Méthode pour récupérer les dernières conversations
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
        
        // Garder seulement le message le plus récent pour chaque conversation
        if (!conversations.containsKey(conversationKey) || 
            message.timestamp.isAfter((conversations[conversationKey]!['lastMessage'] as Message).timestamp)) {
          
          conversations[conversationKey] = {
            'otherUserId': otherUserId,
            'lastMessage': message,
            'unreadCount': await getUnreadCount(userId, otherUserId),
          };
        }
      }

      // Convertir en liste et trier par date du dernier message
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