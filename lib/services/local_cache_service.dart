// // services/message_cache_service.dart
// import 'dart:convert';
// import 'package:shared_preferences/shared_preferences.dart';
// import '../models/message_model.dart';

// class MessageCacheService {
//   static const String _messagesKey = 'cached_messages';
//   static const String _lastSyncKey = 'last_sync_timestamp';
//   static const Duration _cacheDuration = Duration(hours: 1); // Cache valide 1 heure

//   /// Sauvegarder les messages en cache
//   static Future<void> cacheMessages(List<Message> messages, String conversationId) async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
      
//       // Récupérer le cache existant
//       final existingCache = prefs.getString(_messagesKey) ?? '{}';
//       final Map<String, dynamic> cacheMap = json.decode(existingCache);
      
//       // Mettre à jour le cache pour cette conversation
//       cacheMap[conversationId] = {
//         'messages': messages.map((msg) => msg.toMap()).toList(),
//         'timestamp': DateTime.now().millisecondsSinceEpoch,
//       };
      
//       // Sauvegarder
//       await prefs.setString(_messagesKey, json.encode(cacheMap));
//       await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
      
//       print('💾 Messages mis en cache pour la conversation: $conversationId');
//     } catch (e) {
//       print('❌ Erreur sauvegarde cache: $e');
//     }
//   }

//   /// Récupérer les messages depuis le cache
//   static Future<List<Message>?> getCachedMessages(String conversationId) async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
      
//       // Vérifier si le cache est expiré
//       final lastSync = prefs.getInt(_lastSyncKey) ?? 0;
//       final lastSyncTime = DateTime.fromMillisecondsSinceEpoch(lastSync);
//       if (DateTime.now().difference(lastSyncTime) > _cacheDuration) {
//         print('🕐 Cache expiré, nettoyage...');
//         await clearCache();
//         return null;
//       }
      
//       // Récupérer les messages du cache
//       final cachedData = prefs.getString(_messagesKey);
//       if (cachedData == null) return null;
      
//       final Map<String, dynamic> cacheMap = json.decode(cachedData);
//       final conversationData = cacheMap[conversationId];
      
//       if (conversationData != null) {
//         final messagesData = List<Map<String, dynamic>>.from(conversationData['messages']);
//         final messages = messagesData.map((data) => Message.fromMap(data)).toList();
        
//         print('📂 ${messages.length} messages récupérés du cache');
//         return messages;
//       }
      
//       return null;
//     } catch (e) {
//       print('❌ Erreur lecture cache: $e');
//       return null;
//     }
//   }

//   /// Ajouter un message au cache
//   static Future<void> addMessageToCache(Message message, String conversationId) async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
      
//       // Récupérer le cache existant
//       final existingCache = prefs.getString(_messagesKey) ?? '{}';
//       final Map<String, dynamic> cacheMap = json.decode(existingCache);
      
//       final conversationData = cacheMap[conversationId];
//       if (conversationData != null) {
//         final messages = List<Map<String, dynamic>>.from(conversationData['messages']);
        
//         // Vérifier si le message existe déjà
//         final existingIndex = messages.indexWhere((m) => m['id'] == message.id);
//         if (existingIndex >= 0) {
//           messages[existingIndex] = message.toMap();
//         } else {
//           messages.insert(0, message.toMap()); // Ajouter au début
//         }
        
//         cacheMap[conversationId] = {
//           'messages': messages,
//           'timestamp': DateTime.now().millisecondsSinceEpoch,
//         };
        
//         await prefs.setString(_messagesKey, json.encode(cacheMap));
//         print('💾 Message ajouté au cache: ${message.id}');
//       }
//     } catch (e) {
//       print('❌ Erreur ajout message cache: $e');
//     }
//   }

//   /// Marquer un message comme lu dans le cache
//   static Future<void> markMessageAsReadInCache(String messageId, String conversationId) async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final cachedData = prefs.getString(_messagesKey);
//       if (cachedData == null) return;
      
//       final Map<String, dynamic> cacheMap = json.decode(cachedData);
//       final conversationData = cacheMap[conversationId];
      
//       if (conversationData != null) {
//         final messages = List<Map<String, dynamic>>.from(conversationData['messages']);
        
//         for (int i = 0; i < messages.length; i++) {
//           if (messages[i]['id'] == messageId) {
//             messages[i]['isRead'] = true;
//             break;
//           }
//         }
        
//         cacheMap[conversationId] = {
//           'messages': messages,
//           'timestamp': conversationData['timestamp'],
//         };
        
//         await prefs.setString(_messagesKey, json.encode(cacheMap));
//         print('📖 Message marqué comme lu dans le cache: $messageId');
//       }
//     } catch (e) {
//       print('❌ Erreur marquage message lu cache: $e');
//     }
//   }

//   /// Nettoyer le cache
//   static Future<void> clearCache() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.remove(_messagesKey);
//       await prefs.remove(_lastSyncKey);
//       print('🗑️ Cache nettoyé');
//     } catch (e) {
//       print('❌ Erreur nettoyage cache: $e');
//     }
//   }

//   /// Forcer la synchronisation (vider le cache)
//   static Future<void> forceRefresh() async {
//     await clearCache();
//     print('🔄 Synchronisation forcée');
//   }
// }