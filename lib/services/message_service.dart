import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message_model.dart';

class MessageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Envoyer un message avec notification FCM
  Future<void> sendMessage(Message message) async {
    try {
      await _firestore
          .collection('messages')
          .doc(message.id)
          .set(message.toMap());

      print('✅ Message envoyé: ${message.id}');
      
      // 🔥 Déclencher la notification FCM
      await _sendPushNotification(message);
      
    } catch (e) {
      print('❌ Erreur envoi message: $e');
      rethrow;
    }
  }

  // Envoyer une notification push
  Future<void> _sendPushNotification(Message message) async {
    try {
      // Récupérer les tokens FCM du destinataire
      final receiverTokensSnapshot = await _firestore
          .collection('user_fcm_tokens')
          .where('userId', isEqualTo: message.receiverId)
          .get();

      if (receiverTokensSnapshot.docs.isEmpty) {
        print('ℹ️ Aucun token FCM trouvé pour ${message.receiverId}');
        return;
      }

      // Récupérer les infos de l'expéditeur pour la notification
      final senderDoc = await _firestore
          .collection('users')
          .doc(message.senderId)
          .get();
      
      final senderData = senderDoc.data();
      final senderName = senderData != null 
          ? '${senderData['firstName']} ${senderData['lastName']}'
          : 'Utilisateur';

      // Préparer les données de la notification
      final notificationData = {
        'conversationId': '${message.senderId}_${message.receiverId}',
        'senderId': message.senderId,
        'receiverId': message.receiverId,
        'studentId': message.studentId,
        'messageId': message.id,
        'messageType': message.messageType ?? 'text',
        'senderName': senderName,
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
      };

      // Envoyer la notification via Cloud Functions
      await _sendNotificationViaFunction(
        receiverTokens: receiverTokensSnapshot.docs
            .map((doc) => doc['token'] as String)
            .toList(),
        title: 'Nouveau message de $senderName',
        body: _getNotificationBody(message),
        data: notificationData,
      );

      print('✅ Notification FCM envoyée à ${message.receiverId}');

    } catch (e) {
      print('❌ Erreur envoi notification: $e');
    }
  }

  String _getNotificationBody(Message message) {
    if (message.messageType == 'image') {
      return '📷 Image';
    } else {
      return message.content.length > 50 
          ? '${message.content.substring(0, 50)}...' 
          : message.content;
    }
  }

  // Méthode pour envoyer via Cloud Functions
  Future<void> _sendNotificationViaFunction({
    required List<String> receiverTokens,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      // Appeler votre Cloud Function via Firestore
      await _firestore.collection('notification_requests').add({
        'tokens': receiverTokens,
        'title': title,
        'body': body,
        'data': data,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Erreur appel Cloud Function: $e');
      // Fallback: sauvegarder pour traitement ultérieur
      await _firestore.collection('pending_notifications').add({
        'tokens': receiverTokens,
        'title': title,
        'body': body,
        'data': data,
        'timestamp': FieldValue.serverTimestamp(),
        'error': e.toString(),
      });
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
          final messages = snapshot.docs
              .map((doc) => Message.fromMap(doc.data() as Map<String, dynamic>))
              .where((message) => message.participants.contains(otherUserId))
              .toList();

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

            if (!conversations.containsKey(conversationKey) ||
                message.timestamp.isAfter(
                  (conversations[conversationKey]!['lastMessage'] as Message)
                      .timestamp,
                )) {
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

          final conversationList = conversations.values.toList();
          conversationList.sort((a, b) {
            final msgA = a['lastMessage'] as Message;
            final msgB = b['lastMessage'] as Message;
            return msgB.timestamp.compareTo(msgA.timestamp);
          });

          return conversationList;
        });
  }

  // Récupérer les conversations pour les parents (uniquement avec les enseignants)
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

            if (!conversations.containsKey(conversationKey) ||
                message.timestamp.isAfter(
                  (conversations[conversationKey]!['lastMessage'] as Message)
                      .timestamp,
                )) {
              final otherUserDoc = await _firestore
                  .collection('users')
                  .doc(otherUserId)
                  .get();
              final otherUserData = otherUserDoc.data();

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
      await _firestore
          .collection('messages')
          .doc(messageId)
          .delete();
      
      print('✅ Message supprimé: $messageId');
    } catch (e) {
      print('❌ Erreur suppression message: $e');
      throw Exception('Erreur suppression message: $e');
    }
  }

  // Récupérer le nombre total de messages non lus
  Future<int> getTotalUnreadCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('messages')
          .where('participants', arrayContains: userId)
          .get();

      int total = 0;
      final seenConversations = <String>{};

      for (final doc in snapshot.docs) {
        final message = Message.fromMap(doc.data() as Map<String, dynamic>);
        final otherUserId = message.participants.firstWhere(
          (id) => id != userId,
        );

        final conversationKey = '${userId}_$otherUserId';
        
        if (!seenConversations.contains(conversationKey) && 
            message.senderId != userId && 
            !message.isRead) {
          total++;
          seenConversations.add(conversationKey);
        }
      }

      return total;
    } catch (e) {
      print('❌ Erreur comptage messages non lus: $e');
      return 0;
    }
  }
}