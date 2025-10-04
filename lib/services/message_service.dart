// services/message_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message_model.dart';

class MessageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Envoyer un message
  Future<void> sendMessage(Message message) async {
    try {
      await _firestore
          .collection('messages')
          .doc(message.id)
          .set(message.toMap());

      print('✅ Message envoyé: ${message.id}');
    } catch (e) {
      print('❌ Erreur envoi message: $e');
      rethrow;
    }
  }

  // Récupérer les messages entre deux utilisateurs
  Stream<List<Message>> getConversationMessages(
    String currentUserId,
    String otherUserId,
  ) {
    return _firestore
        .collection('messages')
        .where('participants', arrayContains: currentUserId)
        .snapshots()
        .map((snapshot) {
          // Convertir les documents Firestore en objets Message
          final messages = snapshot.docs
              .map((doc) => Message.fromMap(doc.data() as Map<String, dynamic>))
              // 🔽 Ne garder que les messages échangés avec l'autre utilisateur
              .where((message) => message.participants.contains(otherUserId))
              .toList();

          // 🔽 Trier les messages localement par date décroissante (plus récent en haut)
          messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));

          return messages;
        });
  }

  // Récupérer toutes les conversations d'un utilisateur
  Stream<List<Map<String, dynamic>>> getUserConversations(String userId) {
    return _firestore
        .collection('messages')
        .where('participants', arrayContains: userId)
        .snapshots()
        .asyncMap((snapshot) async {
          final conversations = <String, Map<String, dynamic>>{};

          for (final doc in snapshot.docs) {
            final message = Message.fromMap(doc.data() as Map<String, dynamic>);
            final otherUserId = message.participants.firstWhere(
              (id) => id != userId,
              orElse: () => message.senderId == userId
                  ? message.receiverId
                  : message.senderId,
            );

            final conversationKey = '${userId}_$otherUserId';

            // Mettre à jour la conversation si c’est un message plus récent
            if (!conversations.containsKey(conversationKey) ||
                message.timestamp.isAfter(
                  (conversations[conversationKey]!['lastMessage'] as Message)
                      .timestamp,
                )) {
              // Charger les infos de l'autre utilisateur
              final otherUserDoc = await _firestore
                  .collection('users')
                  .doc(otherUserId)
                  .get();
              final otherUserData = otherUserDoc.data();

              final otherUserName = otherUserData != null
                  ? '${otherUserData['firstName']} ${otherUserData['lastName']}'
                  : 'Utilisateur inconnu';

              final unreadCount = await _getUnreadCount(userId, otherUserId);

              conversations[conversationKey] = {
                'otherUserId': otherUserId,
                'otherUserName': otherUserName,
                'otherUserRole': otherUserData?['role'] ?? 'unknown',
                'lastMessage': message,
                'unreadCount': unreadCount,
                'studentId': message.studentId,
              };
            }
          }

          // 🔽 Trier les conversations localement (plus récentes d’abord)
          final conversationList = conversations.values.toList();
          conversationList.sort((a, b) {
            final msgA = a['lastMessage'] as Message;
            final msgB = b['lastMessage'] as Message;
            return msgB.timestamp.compareTo(msgA.timestamp);
          });

          return conversationList;
        });
  }

  // Marquer les messages comme lus
  Future<void> markMessagesAsRead(
    String currentUserId,
    String otherUserId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('messages')
          .where('participants', arrayContains: currentUserId)
          .get();

      final batch = _firestore.batch();
      int updatedCount = 0;

      for (final doc in snapshot.docs) {
        final message = Message.fromMap(doc.data() as Map<String, dynamic>);
        if (message.senderId == otherUserId &&
            message.participants.contains(otherUserId) &&
            !message.isRead) {
          batch.update(doc.reference, {'isRead': true});
          updatedCount++;
        }
      }

      if (updatedCount > 0) {
        await batch.commit();
        print('✅ $updatedCount messages marqués comme lus');
      }
    } catch (e) {
      print('❌ Erreur marquage messages lus: $e');
      rethrow;
    }
  }

  // Dans services/message_service.dart
  Stream<List<Map<String, dynamic>>> getParentConversations(String parentId) {
    return _firestore
        .collection('messages')
        .where('participants', arrayContains: parentId)
        .snapshots()
        .asyncMap((snapshot) async {
          final conversations = <String, Map<String, dynamic>>{};

          for (final doc in snapshot.docs) {
            final message = Message.fromMap(doc.data() as Map<String, dynamic>);
            final otherUserId = message.participants.firstWhere(
              (id) => id != parentId,
              orElse: () => message.senderId == parentId
                  ? message.receiverId
                  : message.senderId,
            );

            final conversationKey = '${parentId}_$otherUserId';

            // Vérifier si cette conversation n’a pas déjà été ajoutée
            if (!conversations.containsKey(conversationKey) ||
                message.timestamp.isAfter(
                  (conversations[conversationKey]!['lastMessage'] as Message)
                      .timestamp,
                )) {
              // Récupérer les infos de l'autre utilisateur (enseignant)
              final otherUserDoc = await _firestore
                  .collection('users')
                  .doc(otherUserId)
                  .get();
              final otherUserData = otherUserDoc.data();

              // Ne garder que les conversations avec les enseignants
              if (otherUserData != null && otherUserData['role'] == 'teacher') {
                final otherUserName =
                    '${otherUserData['firstName']} ${otherUserData['lastName']}';
                final unreadCount = await _getUnreadCount(
                  parentId,
                  otherUserId,
                );

                conversations[conversationKey] = {
                  'otherUserId': otherUserId,
                  'otherUserName': otherUserName,
                  'otherUserRole': 'teacher',
                  'lastMessage': message,
                  'unreadCount': unreadCount,
                  'studentId': message.studentId,
                };
              }
            }
          }

          // 🔽 Trier les conversations localement (plus récentes d’abord)
          final conversationList = conversations.values.toList();
          conversationList.sort((a, b) {
            final msgA = a['lastMessage'] as Message;
            final msgB = b['lastMessage'] as Message;
            return msgB.timestamp.compareTo(msgA.timestamp);
          });

          return conversationList;
        });
  }

  // Compter les messages non lus
  Future<int> _getUnreadCount(String currentUserId, String otherUserId) async {
    final snapshot = await _firestore
        .collection('messages')
        .where('participants', arrayContains: currentUserId)
        .get();

    int count = 0;
    for (final doc in snapshot.docs) {
      final message = Message.fromMap(doc.data() as Map<String, dynamic>);
      if (message.senderId == otherUserId &&
          message.participants.contains(otherUserId) &&
          !message.isRead) {
        count++;
      }
    }
    return count;
  }

  // Supprimer un message
  Future<void> deleteMessage(String messageId) async {
    try {
      await FirebaseFirestore.instance
          .collection('messages')
          .doc(messageId)
          .delete();
    } catch (e) {
      throw Exception('Erreur suppression message: $e');
    }
  }
}
