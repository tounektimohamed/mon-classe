import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class FCMService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  // Initialisation de FCM
  static Future<void> initialize() async {
    await Firebase.initializeApp();

    // 🔥 CRÉER LES CANAUX DE NOTIFICATION
    await _createNotificationChannels();

    // Configuration des notifications locales
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const InitializationSettings initializationSettings = InitializationSettings(
      android: androidSettings, 
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _handleNotificationClick(response.payload);
      },
    );

    // Demander les permissions
    await _requestPermissions();

    // Configurer les handlers de messages
    await _setupMessageHandlers();

    // Sauvegarder le token FCM
    await _saveFCMToken();

    // 🔥 DEBUG
    await debugFCMConfiguration();
  }

  // 🔥 CORRIGÉ : Créer les canaux de notification
  static Future<void> _createNotificationChannels() async {
    try {
      // Canal pour les sanctions
      const AndroidNotificationChannel sanctionsChannel = AndroidNotificationChannel(
        'sanctions_channel', // id
        'Notifications de sanctions', // name
        description: 'Notifications pour les nouvelles sanctions et alertes', // description
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      // Canal pour les messages
      const AndroidNotificationChannel chatChannel = AndroidNotificationChannel(
        'chat_channel', // id
        'Messages de chat', // name
        description: 'Notifications pour les nouveaux messages', // description
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      final androidPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(sanctionsChannel);
        await androidPlugin.createNotificationChannel(chatChannel);
        print('✅ Canaux de notification créés: sanctions_channel, chat_channel');
      }
    } catch (e) {
      print('❌ Erreur création canaux: $e');
    }
  }

  // Demander les permissions
  static Future<void> _requestPermissions() async {
    try {
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      print('🔔 Permissions utilisateur: ${settings.authorizationStatus}');
    } catch (e) {
      print('❌ Erreur permissions: $e');
    }
  }

  static Future<void> saveUserFCMToken(String userId) async {
    try {
      print('🔄 Début sauvegarde token FCM pour: $userId');

      await Future.delayed(const Duration(seconds: 1));
      String? token = await _firebaseMessaging.getToken();
      print('📱 Token FCM brut: $token');

      if (token == null || token.isEmpty) {
        print('❌ Token FCM vide ou null');
        return;
      }

      if (userId.isEmpty) {
        print('❌ UserId vide');
        return;
      }

      if (token.length < 10) {
        print('❌ Token FCM trop court: $token');
        return;
      }

      await FirebaseFirestore.instance
          .collection('user_fcm_tokens')
          .doc(userId)
          .set({
            'token': token,
            'userId': userId,
            'createdAt': FieldValue.serverTimestamp(),
            'platform': 'web',
            'updatedAt': FieldValue.serverTimestamp(),
            'tokenLength': token.length,
          }, SetOptions(merge: true));

      print('✅ Token FCM sauvegardé pour user: $userId');
      print('🔑 Token (${token.length} chars): ${token.substring(0, 20)}...');
    } catch (e) {
      print('❌ Erreur sauvegarde token FCM: $e');
    }
  }

  static Future<void> fixMissingTokens() async {
    try {
      print('🚨 Début correction tokens manquants...');
      final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
      int fixedCount = 0;
      int missingCount = 0;

      for (final userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;
        final userData = userDoc.data();

        final tokenDoc = await FirebaseFirestore.instance
            .collection('user_fcm_tokens')
            .doc(userId)
            .get();

        final hasValidToken = tokenDoc.exists &&
            tokenDoc.data()?['token'] != null &&
            (tokenDoc.data()?['token'] as String).isNotEmpty &&
            (tokenDoc.data()?['token'] as String).length > 10;

        if (!hasValidToken) {
          print('⚠️ Token manquant pour: $userId (${userData['email']})');
          missingCount++;

          await FirebaseFirestore.instance
              .collection('fcm_token_requests')
              .doc(userId)
              .set({
                'userId': userId,
                'email': userData['email'],
                'requestedAt': FieldValue.serverTimestamp(),
                'status': 'pending',
                'attempts': 0,
                'role': userData['role'],
              }, SetOptions(merge: true));

          fixedCount++;
        }
      }

      print('✅ Correction terminée: $missingCount tokens manquants, $fixedCount marqués');

      if (missingCount > 0) {
        await FirebaseFirestore.instance.collection('admin_alerts').doc().set({
          'type': 'missing_fcm_tokens',
          'message': '$missingCount utilisateurs sans token FCM',
          'timestamp': FieldValue.serverTimestamp(),
          'priority': 'medium',
        });
      }
    } catch (e) {
      print('❌ Erreur correction tokens: $e');
    }
  }

  // Configurer les handlers de messages
  static Future<void> _setupMessageHandlers() async {
    // Message en foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📨 Message reçu en foreground:');
      print('   - Titre: ${message.notification?.title}');
      print('   - Body: ${message.notification?.body}');
      print('   - Data: ${message.data}');
      _showLocalNotification(message);
    });

    // Message en background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('📱 Message ouvert depuis background: ${message.data}');
      _handleNotificationClick(json.encode(message.data));
    });

    // Message lorsque l'app est terminée
    RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      print('🔙 Message initial: ${initialMessage.data}');
      _handleNotificationClick(json.encode(initialMessage.data));
    }
  }

  // Sauvegarder le token FCM dans Firestore
  static Future<void> _saveFCMToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        print('💾 Token FCM sauvegardé: $token');
        await FirebaseFirestore.instance
            .collection('user_fcm_tokens')
            .doc(token)
            .set({
              'token': token,
              'createdAt': FieldValue.serverTimestamp(),
              'platform': 'web',
            });
      }
    } catch (e) {
      print('❌ Erreur sauvegarde token FCM: $e');
    }
  }

  // Afficher une notification locale
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      // 🔥 CORRIGÉ : Utiliser le bon canal selon le type
      String channelId = 'chat_channel';
      String channelName = 'Messages de chat';
      
      if (message.data['type'] == 'sanction') {
        channelId = 'sanctions_channel';
        channelName = 'Notifications de sanctions';
      }

      final AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelId == 'sanctions_channel' 
            ? 'Notifications pour les nouvelles sanctions' 
            : 'Notifications pour les nouveaux messages',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        autoCancel: true,
        enableVibration: true,
        playSound: true,
      );

      const DarwinNotificationDetails iosPlatformChannelSpecifics = DarwinNotificationDetails();
      final NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iosPlatformChannelSpecifics,
      );

      await _notificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        message.notification?.title ?? 'Nouvelle notification',
        message.notification?.body ?? 'Vous avez une nouvelle notification',
        platformChannelSpecifics,
        payload: json.encode(message.data),
      );

      print('✅ Notification locale affichée sur le canal: $channelId');
    } catch (e) {
      print('❌ Erreur affichage notification locale: $e');
    }
  }

  // Gérer le clic sur la notification
  static void _handleNotificationClick(String? payload) {
    if (payload != null) {
      try {
        Map<String, dynamic> data = json.decode(payload);
        print('👆 Clic sur notification: $data');

        if (data['conversationId'] != null) {
          String? conversationId = data['conversationId'];
          print('💬 Navigation vers conversation: $conversationId');
        } else if (data['type'] == 'sanction') {
          print('⚖️ Navigation vers sanction: ${data['studentName']}');
          _showSanctionNotificationDialog(data);
        }
      } catch (e) {
        print('❌ Erreur traitement payload: $e');
      }
    }
  }

  // Afficher les détails de la sanction
  static void _showSanctionNotificationDialog(Map<String, dynamic> data) {
    print('📋 Détails sanction reçue:');
    print('   👨‍🎓 Élève: ${data['studentName']}');
    print('   📝 Type: ${data['sanctionType']}');
    print('   🎯 Raison: ${data['reason']}');
    print('   👨‍🏫 Enseignant: ${data['teacherName']}');
  }

  // Se désabonner des notifications
  static Future<void> unsubscribeFromNotifications() async {
    await _firebaseMessaging.deleteToken();
  }

  // 🔥 MÉTHODE CORRIGÉE : Envoyer notification de sanction
  static Future<void> sendSanctionNotification({
    required String studentId,
    required String studentName,
    required String teacherName,
    required String sanctionType,
    required String reason,
    required String classId,
    required String parentId,
  }) async {
    try {
      print('🚀 DÉBUT ENVOI NOTIFICATION SANCTION');
      print('   👨‍🎓 Élève: $studentName');
      print('   👨‍🏫 Enseignant: $teacherName');
      print('   📝 Type: $sanctionType');
      print('   🎯 Raison: $reason');
      print('   👨‍👦 Parent ID: $parentId');
      print('   🏫 Classe ID: $classId');

      // 1. Vérifier que le parent a un token FCM valide
      final tokenDoc = await FirebaseFirestore.instance
          .collection('user_fcm_tokens')
          .doc(parentId)
          .get();

      if (!tokenDoc.exists) {
        print('❌ Aucun token FCM trouvé pour le parent: $parentId');
        return;
      }

      final tokenData = tokenDoc.data();
      final String? token = tokenData?['token'];

      if (token == null || token.isEmpty) {
        print('❌ Token FCM vide pour le parent: $parentId');
        return;
      }

      print('✅ Token FCM trouvé: ${token.substring(0, 20)}...');

      // 2. Préparer les données de la notification
      final notificationData = {
        'type': 'sanction',
        'studentId': studentId,
        'studentName': studentName,
        'teacherName': teacherName,
        'sanctionType': sanctionType,
        'reason': reason,
        'classId': classId,
        'parentId': parentId,
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
      };

      // 3. Envoyer via Firebase Functions
      await FirebaseFirestore.instance
          .collection('notification_requests')
          .doc(DateTime.now().millisecondsSinceEpoch.toString())
          .set({
            'tokens': [token],
            'title': 'Nouvelle sanction - $studentName',
            'body': '$sanctionType: $reason',
            'data': notificationData,
            'createdAt': FieldValue.serverTimestamp(),
            'notificationType': 'sanction',
            'priority': 'high',
          });

      print('✅ Notification sanction envoyée à Firestore');

      // 4. Afficher une notification locale IMMÉDIATEMENT (pour test)
      await _showLocalNotificationForSanction(
        studentName: studentName,
        sanctionType: sanctionType,
        reason: reason,
        data: notificationData,
      );

    } catch (e) {
      print('❌ ERREUR CRITIQUE envoi notification sanction: $e');
      print('🔍 Stack trace: ${e.toString()}');
    }
  }

  // Notification locale pour sanction
  static Future<void> _showLocalNotificationForSanction({
    required String studentName,
    required String sanctionType,
    required String reason,
    required Map<String, dynamic> data,
  }) async {
    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'sanctions_channel',
        'Notifications de sanctions',
        channelDescription: 'Notifications pour les nouvelles sanctions',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        autoCancel: true,
        enableVibration: true,
        playSound: true,
        color: Colors.red,
        ledColor: Colors.red,
        ledOnMs: 1000,
        ledOffMs: 500,
      );

      const DarwinNotificationDetails iosPlatformChannelSpecifics = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iosPlatformChannelSpecifics,
      );

      await _notificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        '⚖️ Sanction - $studentName',
        '$sanctionType: $reason',
        platformChannelSpecifics,
        payload: json.encode(data),
      );

      print('✅ Notification locale SANCTION affichée');
    } catch (e) {
      print('❌ Erreur notification locale sanction: $e');
    }
  }

  // Debug FCM
  static Future<void> debugFCMConfiguration() async {
    try {
      print('🔍 DEBUG CONFIGURATION FCM');

      String? token = await _firebaseMessaging.getToken();
      print('📱 Token FCM: $token');
      print('📱 Token length: ${token?.length}');

      final settings = await _firebaseMessaging.getNotificationSettings();
      print('🔔 Notification settings:');
      print('   - Authorization status: ${settings.authorizationStatus}');
      print('   - Alert: ${settings.alert}');
      print('   - Badge: ${settings.badge}');
      print('   - Sound: ${settings.sound}');

      print('📱 Platform: ${defaultTargetPlatform}');
    } catch (e) {
      print('❌ Erreur debug FCM: $e');
    }
  }

  // 🔥 NOUVELLE MÉTHODE: Test manuel des notifications
  static Future<void> testNotification() async {
    try {
      print('🧪 TEST MANUEL NOTIFICATION');
      
      await _showLocalNotificationForSanction(
        studentName: 'Élève Test',
        sanctionType: 'Avertissement',
        reason: 'Test de notification',
        data: {'type': 'test', 'timestamp': DateTime.now().toString()},
      );
      
      print('✅ Test notification locale terminé');
    } catch (e) {
      print('❌ Erreur test notification: $e');
    }
  }

  // 🔥 NOUVELLES MÉTHODES POUR LE DIAGNOSTIC
  static Future<void> diagnoseAllTokens() async {
    try {
      print('🔍 DIAGNOSTIC COMPLET DES TOKENS FCM');
      
      final tokensSnapshot = await FirebaseFirestore.instance
          .collection('user_fcm_tokens')
          .get();

      print('📊 Total tokens en base: ${tokensSnapshot.docs.length}');
      
      for (final doc in tokensSnapshot.docs) {
        final data = doc.data();
        final userId = doc.id;
        final token = data['token'];
        final createdAt = data['createdAt'];
        
        print('\n👤 User: $userId');
        print('   🔑 Token: ${token != null ? '${token.substring(0, 30)}...' : 'NULL'}');
        print('   📅 Créé: $createdAt');
        print('   📏 Longueur: ${token?.length ?? 0}');
        
        if (token == null || token.isEmpty) {
          print('   ❌ TOKEN VIDE');
        } else if (token.length < 100) {
          print('   ❌ TOKEN TROP COURT');
        } else if (!token.startsWith('f')) {
          print('   ❌ FORMAT INVALIDE');
        } else {
          print('   ✅ TOKEN APPAREMENT VALIDE');
        }
      }
      
    } catch (e) {
      print('❌ Erreur diagnostic tokens: $e');
    }
  }

  static Future<void> checkTokenOwner(String parentId) async {
    try {
      print('👤 VÉRIFICATION PROPRIÉTAIRE DU TOKEN: $parentId');
      
      final parentDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(parentId)
          .get();

      if (parentDoc.exists) {
        final parentData = parentDoc.data()!;
        print('   📧 Email: ${parentData['email']}');
        print('   📛 Nom: ${parentData['firstName']} ${parentData['lastName']}');
        print('   🎯 Rôle: ${parentData['role']}');
      } else {
        print('   ❌ Utilisateur non trouvé');
      }
    } catch (e) {
      print('❌ Erreur vérification propriétaire: $e');
    }
  }

  static Future<void> checkNotificationPermissions() async {
    try {
      final settings = await _firebaseMessaging.getNotificationSettings();
      
      print('🔔 ÉTAT DES PERMISSIONS:');
      print('   📱 Authorization: ${settings.authorizationStatus}');
      print('   🔔 Alert: ${settings.alert}');
      print('   🔴 Badge: ${settings.badge}');
      print('   🔊 Sound: ${settings.sound}');
      
    } catch (e) {
      print('❌ Erreur vérification permissions: $e');
    }
  }
}