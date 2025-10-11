import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

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
    print('🔍 [FCM] DÉBUT - Envoi notification à: ${message.receiverId}');
    print('🔍 [FCM] Message ID: ${message.id}');
    print('🔍 [FCM] Type: ${message.messageType}');
    print('🔍 [FCM] Contenu: ${message.content}');

    // Récupérer les tokens FCM du destinataire
    print('🔍 [FCM] Recherche tokens pour: ${message.receiverId}');
    final receiverTokensSnapshot = await _firestore
        .collection('user_fcm_tokens')
        .where('userId', isEqualTo: message.receiverId)
        .get();

    print('📊 [FCM] Documents trouvés: ${receiverTokensSnapshot.docs.length}');
    
    // Log détaillé des documents trouvés
    for (var doc in receiverTokensSnapshot.docs) {
      final data = doc.data();
      print('📄 [FCM] Document ID: ${doc.id}');
      print('👤 [FCM] UserID: ${data['userId']}');
      print('🔑 [FCM] Token (début): ${data['token'] != null ? (data['token'] as String).substring(0, 20) + '...' : 'NULL'}');
      print('📏 [FCM] Longueur token: ${data['token'] != null ? (data['token'] as String).length : 0}');
      print('🖥️ [FCM] Plateforme: ${data['platform']}');
      print('---');
    }

    if (receiverTokensSnapshot.docs.isEmpty) {
      print('❌ [FCM] Aucun token FCM trouvé pour ${message.receiverId}');
      print('💡 [FCM] Conseil: Vérifiez que l\'utilisateur a autorisé les notifications');
      
      // Optionnel: forcer la régénération du token
      await _requestFCMTokenRegeneration(message.receiverId);
      return;
    }

    final tokens = receiverTokensSnapshot.docs
        .map((doc) => doc['token'] as String)
        .where((token) => token != null && token.isNotEmpty && token.length > 10)
        .toList();

    print('🎯 [FCM] Tokens valides après filtrage: ${tokens.length}');

    if (tokens.isEmpty) {
      print('❌ [FCM] Aucun token FCM valide pour ${message.receiverId}');
      print('💡 [FCM] Tokens peuvent être vides ou invalides');
      return;
    }

    // Log du premier token pour vérification
    print('🔎 [FCM] Premier token (20 chars): ${tokens[0].substring(0, 20)}...');
    print('📏 [FCM] Longueur token: ${tokens[0].length}');

    // Récupérer les infos de l'expéditeur
    print('🔍 [FCM] Récupération infos expéditeur: ${message.senderId}');
    final senderDoc = await _firestore
        .collection('users')
        .doc(message.senderId)
        .get();
    
    final senderData = senderDoc.data();
    final senderName = senderData != null 
        ? '${senderData['firstName']} ${senderData['lastName']}'
        : 'Utilisateur';

    print('👤 [FCM] Expéditeur: $senderName');
    print('📧 [FCM] Email: ${senderData?['email']}');

    // Préparer les données de notification
    final notificationData = {
      'conversationId': '${message.senderId}_${message.receiverId}',
      'senderId': message.senderId,
      'receiverId': message.receiverId,
      'studentId': message.studentId,
      'messageId': message.id,
      'messageType': message.messageType ?? 'text',
      'senderName': senderName,
      'content': message.content.length > 50 ? '${message.content.substring(0, 50)}...' : message.content,
      'click_action': 'FLUTTER_NOTIFICATION_CLICK',
      'timestamp': DateTime.now().toIso8601String(),
    };

    print('📦 [FCM] Données notification préparées:');
    print('   🏷️  Titre: Nouveau message de $senderName');
    print('   📝 Body: ${_getNotificationBody(message)}');
    print('   🔗 Conversation: ${notificationData['conversationId']}');
    print('   📱 Type: ${notificationData['messageType']}');

    // Envoyer la notification via Cloud Functions
    print('🚀 [FCM] ENVOI via Cloud Function...');
    await _sendNotificationViaFunction(
      receiverTokens: tokens,
      title: 'Nouveau message de $senderName',
      body: _getNotificationBody(message),
      data: notificationData,
    );

    print('✅ [FCM] SUCCÈS - Notification envoyée à ${message.receiverId}');
    print('✅ [FCM] Nombre de tokens utilisés: ${tokens.length}');
    print('✅ [FCM] Message ID: ${message.id}');

  } catch (e) {
    print('❌ [FCM] ERREUR CRITIQUE lors de l\'envoi:');
    print('❌ [FCM] Type d\'erreur: ${e.runtimeType}');
    print('❌ [FCM] Message: $e');
    print('🔍 [FCM] Stack trace: ${e.toString()}');
    
    // Sauvegarder l'erreur pour analyse
    await _saveNotificationError(message, e.toString());
  }
}
Future<void> _sendNotificationViaFunction({
  required List<String> receiverTokens,
  required String title,
  required String body,
  required Map<String, dynamic> data,
}) async {
  try {
    print('🚀 [FCM DIRECT] Début envoi direct FCM');
    
    const String serverKey = 'BCMXy0zwJ_vZayTu41kf4wjKt2m8si7i4pbhSJSI3xQFCc3j6lYrFYRrrE7Tk1hx8cTqQuqYRSwYEJSQ0Y_Dcns';
    
    if (receiverTokens.isEmpty) return;

    final token = receiverTokens.firstWhere(
      (token) => token.length > 10,
      orElse: () => '',
    );

    if (token.isEmpty) return;

    print('🔑 Token: ${token.substring(0, 20)}...');

    // Créer un client HTTP avec timeout
    final client = http.Client();
    
    try {
      final response = await client.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$serverKey',
          'Access-Control-Allow-Origin': '*',
        },
        body: jsonEncode({
          'to': token,
          'notification': {
            'title': title,
            'body': body,
            'icon': '/icons/Icon-192.png',
          },
          'data': data,
        }),
      ).timeout(const Duration(seconds: 10));

      print('📨 Status: ${response.statusCode}');
      print('📨 Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == 1) {
          print('✅ FCM DIRECT: Succès!');
        } else {
          print('❌ FCM DIRECT: Échec - ${responseData['results']}');
        }
      } else {
        print('❌ HTTP Error: ${response.statusCode}');
      }
    } finally {
      client.close();
    }
    
  } catch (e) {
    print('❌ FCM DIRECT Erreur: $e');
    
    // Diagnostic détaillé
    if (e is http.ClientException) {
      print('🔍 ClientException - Problème réseau');
    } else if (e is TimeoutException) {
      print('🔍 Timeout - Serveur trop lent');
    }
    
    print('🔍 Stack trace: ${e.toString()}');
  }
}
Future<void> _saveNotificationError(Message message, String error) async {
  try {
    await _firestore.collection('notification_errors').add({
      'messageId': message.id,
      'senderId': message.senderId,
      'receiverId': message.receiverId,
      'error': error,
      'timestamp': FieldValue.serverTimestamp(),
      'messageType': message.messageType,
      'content': message.content,
    });
    print('📝 [Error] Erreur sauvegardée pour analyse');
  } catch (e) {
    print('❌ [Error] Impossible de sauvegarder l\'erreur: $e');
  }
}

String _getNotificationBody(Message message) {
  switch (message.messageType) {
    case 'image':
      return '📷 Image';
    case 'file':
      return '📎 Fichier';
    case 'text':
    default:
      final content = message.content.trim();
      if (content.isEmpty) return 'Nouveau message';
      return content.length > 60 ? '${content.substring(0, 60)}...' : content;
  }
}

Future<void> _requestFCMTokenRegeneration(String userId) async {
  try {
    print('🔄 [Token Regeneration] Demande pour: $userId');
    
    await _firestore.collection('fcm_token_requests').add({
      'userId': userId,
      'requestedAt': FieldValue.serverTimestamp(),
      'status': 'pending',
      'requestedBy': 'system_missing_token'
    });
    
    print('✅ [Token Regeneration] Demande enregistrée');
  } catch (e) {
    print('❌ [Token Regeneration] Erreur: $e');
  }
}
/// Version simple et fiable

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