import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class FCMService {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Initialisation de FCM
  static Future<void> initialize() async {
    await Firebase.initializeApp();

    // Configuration des notifications locales
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Gérer le clic sur la notification
        _handleNotificationClick(response.payload);
      },
    );

    // Demander les permissions
    await _requestPermissions();

    // Configurer les handlers de messages
    await _setupMessageHandlers();

    // Sauvegarder le token FCM
    await _saveFCMToken();
  }

  // Demander les permissions
  static Future<void> _requestPermissions() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    print('Permissions utilisateur: ${settings.authorizationStatus}');
  }

  // Dans services/fcm_service.dart
  static Future<void> saveUserFCMToken(String userId) async {
    try {
      print('🔄 Début sauvegarde token FCM pour: $userId');

      // Attendre que Firebase Messaging soit prêt
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

      // Vérifier la longueur du token
      if (token.length < 10) {
        print('❌ Token FCM trop court: $token');
        return;
      }

      // Sauvegarder dans Firestore
      await FirebaseFirestore.instance
          .collection('user_fcm_tokens')
          .doc(userId)
          .set({
            'token': token,
            'userId': userId,
            'createdAt': FieldValue.serverTimestamp(),
            'platform': 'web',
            'updatedAt': FieldValue.serverTimestamp(),
            'tokenLength': token.length, // Pour debug
          }, SetOptions(merge: true));

      print('✅ Token FCM sauvegardé pour user: $userId');
      print('🔑 Token (${token.length} chars): ${token.substring(0, 20)}...');
    } catch (e) {
      print('❌ Erreur sauvegarde token FCM: $e');
      print('🔍 Stack trace: ${e.toString()}');
    }
  }

  // Dans services/fcm_service.dart - Ajoutez cette méthode
  static Future<void> fixMissingTokens() async {
    try {
      print('🚨 Début correction tokens manquants...');

      // Récupérer tous les utilisateurs
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      int fixedCount = 0;
      int missingCount = 0;

      for (final userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;
        final userData = userDoc.data();

        // Vérifier si l'utilisateur a un token
        final tokenDoc = await FirebaseFirestore.instance
            .collection('user_fcm_tokens')
            .doc(userId)
            .get();

        final hasValidToken =
            tokenDoc.exists &&
            tokenDoc.data()?['token'] != null &&
            (tokenDoc.data()?['token'] as String).isNotEmpty &&
            (tokenDoc.data()?['token'] as String).length > 10;

        if (!hasValidToken) {
          print('⚠️ Token manquant pour: $userId (${userData['email']})');
          missingCount++;

          // Marquer pour régénération
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

      print(
        '✅ Correction terminée: $missingCount tokens manquants, $fixedCount marqués pour régénération',
      );

      if (missingCount > 0) {
        // Créer une notification pour l'admin
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
      print('Message reçu en foreground: ${message.notification?.title}');
      _showLocalNotification(message);
    });

    // Message en background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Message ouvert depuis le background: ${message.data}');
      _handleNotificationClick(json.encode(message.data));
    });

    // Message lorsque l'app est terminée
    RemoteMessage? initialMessage = await _firebaseMessaging
        .getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationClick(json.encode(initialMessage.data));
    }
  }

  // Sauvegarder le token FCM dans Firestore
  static Future<void> _saveFCMToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        print('Token FCM: $token');

        // Sauvegarder dans Firestore (vous devrez adapter selon votre structure)
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
      print('Erreur sauvegarde token FCM: $e');
    }
  }

  // Afficher une notification locale
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'chat_channel',
          'Messages de chat',
          channelDescription: 'Notifications pour les nouveaux messages',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
        );

    const DarwinNotificationDetails iosPlatformChannelSpecifics =
        DarwinNotificationDetails();

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iosPlatformChannelSpecifics,
    );

    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      message.notification?.title ?? 'Nouveau message',
      message.notification?.body ?? 'Vous avez reçu un nouveau message',
      platformChannelSpecifics,
      payload: json.encode(message.data),
    );
  }

  // Gérer le clic sur la notification
static void _handleNotificationClick(String? payload) {
  if (payload != null) {
    try {
      Map<String, dynamic> data = json.decode(payload);
      
      // Gérer les notifications de chat
      if (data['conversationId'] != null) {
        String? conversationId = data['conversationId'];
        String? senderId = data['senderId'];
        print('Navigation vers conversation: $conversationId');
      }
      
      // 🔥 Gérer les notifications de sanctions
      else if (data['type'] == 'sanction') {
        String? studentId = data['studentId'];
        String? studentName = data['studentName'];
        String? sanctionId = data['sanctionId'];
        
        print('Navigation vers détails sanction: $sanctionId');
        // Vous pouvez naviguer vers l'écran des sanctions de l'élève
        // ou afficher un dialog avec les détails
        _showSanctionNotificationDialog(data);
      }
      
    } catch (e) {
      print('Erreur traitement payload notification: $e');
    }
  }
}

// 🔥 NOUVELLE MÉTHODE : Afficher les détails de la sanction
static void _showSanctionNotificationDialog(Map<String, dynamic> data) {
  // Utiliser un GlobalKey pour naviguer depuis n'importe où
  // ou implémenter un système de navigation globale
  print('📋 Détails sanction reçue:');
  print('👨‍🎓 Élève: ${data['studentName']}');
  print('📝 Type: ${data['sanctionTypeText']}');
  print('🎯 Raison: ${data['reason']}');
  print('👨‍🏫 Enseignant: ${data['teacherName']}');
}
  // Se désabonner des notifications
  static Future<void> unsubscribeFromNotifications() async {
    await _firebaseMessaging.deleteToken();
  }

  // Dans services/fcm_service.dart
  static Future<void> sendSanctionNotification({
    required String studentId,
    required String studentName,
    required String teacherName,
    required String sanctionType,
    required String reason,
    required String classId,
  }) async {
    try {
      print('🚀 Envoi notification sanction pour: $studentName');

      // Récupérer le token du parent de l'élève
      final studentDoc = await FirebaseFirestore.instance
          .collection('students')
          .doc(studentId)
          .get();

      if (!studentDoc.exists) {
        print('❌ Élève non trouvé: $studentId');
        return;
      }

      final studentData = studentDoc.data()!;
      final parentId = studentData['parentId'];

      if (parentId == null || parentId.isEmpty) {
        print('⚠️ Aucun parent associé à l\'élève: $studentId');
        return;
      }

      // Récupérer le token FCM du parent
      final tokenDoc = await FirebaseFirestore.instance
          .collection('user_fcm_tokens')
          .doc(parentId)
          .get();

      if (!tokenDoc.exists || tokenDoc.data()?['token'] == null) {
        print('❌ Token FCM non trouvé pour le parent: $parentId');
        return;
      }

      final String token = tokenDoc.data()!['token'];
      final List<String> tokens = [token];

      // Préparer les données de la notification
      final notificationData = {
        'type': 'sanction',
        'studentId': studentId,
        'studentName': studentName,
        'teacherName': teacherName,
        'sanctionType': sanctionType,
        'reason': reason,
        'classId': classId,
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      };

      // Envoyer via Firebase Functions
      await FirebaseFirestore.instance
          .collection('notification_requests')
          .doc()
          .set({
            'tokens': tokens,
            'title': 'Nouvelle sanction - $studentName',
            'body': '$sanctionType: $reason',
            'data': notificationData,
            'createdAt': FieldValue.serverTimestamp(),
          });

      print('✅ Notification sanction envoyée avec succès');
    } catch (e) {
      print('❌ Erreur envoi notification sanction: $e');
    }
  }
}
