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
      print('💡 Conseil: Vérifiez que l\'utilisateur a autorisé les notifications');
      
      // Optionnel: forcer la régénération du token
      await _requestFCMTokenRegeneration(message.receiverId);
      return;
    }

    final tokens = receiverTokensSnapshot.docs
        .map((doc) => doc['token'] as String)
        .where((token) => token.isNotEmpty)
        .toList();

    if (tokens.isEmpty) {
      print('❌ Tokens FCM vides pour ${message.receiverId}');
      return;
    }

    // Récupérer les infos de l'expéditeur
    final senderDoc = await _firestore
        .collection('users')
        .doc(message.senderId)
        .get();
    
    final senderData = senderDoc.data();
    final senderName = senderData != null 
        ? '${senderData['firstName']} ${senderData['lastName']}'
        : 'Utilisateur';

    // Préparer les données
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

    // Envoyer la notification
    await _sendNotificationViaFunction(
      receiverTokens: tokens,
      title: 'Nouveau message de $senderName',
      body: _getNotificationBody(message),
      data: notificationData,
    );

    print('✅ Notification FCM envoyée à ${message.receiverId}');

  } catch (e) {
    print('❌ Erreur envoi notification: $e');
  }
}
/// Version simple et fiable
String _getNotificationBody(Message message) {
  // Gestion par type de message
  switch (message.messageType) {
    case 'image':
      return '📷 Image';
    
    case 'file':
      return '📎 Document';
    
    case 'audio':
      return '🎤 Audio';
    
    case 'video':
      return '🎬 Vidéo';
    
    case 'text':
    default:
      final content = message.content.trim();
      
      // Message vide
      if (content.isEmpty) {
        return 'Nouveau message';
      }
      
      // Message avec emojis seulement
      final emojiRegex = RegExp(r'[\u{1F600}-\u{1F64F}|\u{1F300}-\u{1F5FF}|\u{1F680}-\u{1F6FF}|\u{1F700}-\u{1F77F}|\u{1F780}-\u{1F7FF}|\u{1F800}-\u{1F8FF}|\u{1F900}-\u{1F9FF}|\u{1FA00}-\u{1FA6F}|\u{1FA70}-\u{1FAFF}|\u{2600}-\u{26FF}|\u{2700}-\u{27BF}]', 
        unicode: true);
      
      final hasOnlyEmojis = content.replaceAll(emojiRegex, '').trim().isEmpty;
      if (hasOnlyEmojis) {
        return content;
      }
      
      // Tronquer les messages longs
      return content.length > 70 
          ? '${content.substring(0, 70)}...'
          : content;
  }
}
// Dans services/message_service.dart
Future<void> ensureUserHasFCMToken(String userId) async {
  try {
    print('🔄 Vérification token FCM pour: $userId');
    
    // Vérifier si l'utilisateur a un token
    final tokenDoc = await _firestore
        .collection('user_fcm_tokens')
        .doc(userId)
        .get();

    if (!tokenDoc.exists || tokenDoc.data()?['token'] == null) {
      print('⚠️ Token manquant pour $userId - envoi demande de régénération');
      
      // Créer une demande de régénération
      await _firestore
          .collection('fcm_token_requests')
          .doc()
          .set({
            'userId': userId,
            'requestedAt': FieldValue.serverTimestamp(),
            'status': 'pending',
            'requestedBy': 'system'
          });
      
      // Essayer de régénérer immédiatement
      await _regenerateFCMToken(userId);
    } else {
      final token = tokenDoc.data()?['token'] as String;
      print('✅ Token existant pour $userId: ${token.substring(0, 20)}...');
    }
    
  } catch (e) {
    print('❌ Erreur vérification token: $e');
  }
}

Future<void> _regenerateFCMToken(String userId) async {
  try {
    print('🔄 Régénération manuelle du token pour: $userId');
    
    // Cette méthode devrait être appelée côté client
    // Pour l'instant, on crée une notification pour l'admin
    await _firestore
        .collection('admin_notifications')
        .doc()
        .set({
          'type': 'missing_fcm_token',
          'userId': userId,
          'message': 'L\'utilisateur n\'a pas de token FCM configuré',
          'timestamp': FieldValue.serverTimestamp(),
          'priority': 'high'
        });
        
  } catch (e) {
    print('❌ Erreur régénération token: $e');
  }
}
// Méthode pour régénérer le token FCM
Future<void> _requestFCMTokenRegeneration(String userId) async {
  try {
    print('🔄 Tentative de régénération du token FCM pour: $userId');
    
    // Vous pouvez appeler cette méthode depuis le frontend
    // ou déclencher une nouvelle initialisation FCM
    await FirebaseFirestore.instance
        .collection('fcm_token_requests')
        .doc()
        .set({
          'userId': userId,
          'requestedAt': FieldValue.serverTimestamp(),
          'status': 'pending'
        });
  } catch (e) {
    print('❌ Erreur régénération token: $e');
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