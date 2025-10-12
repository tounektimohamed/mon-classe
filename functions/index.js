const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// 🔥 FONCTION UNIFIÉE POUR TOUTES LES NOTIFICATIONS
exports.sendNotification = functions.firestore
  .document('notification_requests/{docId}')
  .onCreate(async (snapshot, context) => {
    console.log('🚀 Function triggered for document:', context.params.docId);
    
    try {
      const { tokens, title, body, data, notificationType, priority } = snapshot.data();
      
      console.log('📧 Title:', title);
      console.log('📝 Body:', body);
      console('🔑 Tokens count:', tokens ? tokens.length : 0);
      console.log('📱 Notification type:', notificationType);
      console.log('⚡ Priority:', priority);
      console.log('📊 Data:', data);
      
      // LOGIQUE DE NOTIFICATION AMÉLIORÉE
      if (tokens && tokens.length > 0) {
        const validTokens = tokens.filter(t => t && t.length > 10);
        
        console.log('✅ Valid tokens:', validTokens.length);
        
        if (validTokens.length > 0) {
          const message = {
            notification: {
              title: title || 'Nouvelle notification',
              body: body || 'Vous avez une nouvelle notification',
            },
            data: data || {},
            tokens: validTokens,
          };

          // 🔥 CONFIGURATION AVANCÉE POUR LES SANCTIONS
          if (notificationType === 'sanction') {
            message.android = {
              priority: 'high',
              notification: {
                sound: 'default',
                defaultSound: true,
                vibrateTimingsMillis: [0, 500, 200, 500],
                priority: 'max',
                visibility: 'public',
              }
            };
            
            message.apns = {
              payload: {
                aps: {
                  sound: 'default',
                  badge: 1,
                  contentAvailable: true,
                  mutableContent: true,
                }
              }
            };
            
            message.webpush = {
              headers: {
                Urgency: 'high',
              },
              notification: {
                requireInteraction: true,
                vibrate: [200, 100, 200],
              }
            };
          }
          
          console.log('📤 Sending FCM to', validTokens.length, 'tokens');
          const response = await admin.messaging().sendEachForMulticast(message);
          
          console.log('✅ FCM sent - Success:', response.successCount, 'Failures:', response.failureCount);
          
          // 🔥 LOGS DÉTAILLÉS DES ÉCHECS
          if (response.failureCount > 0) {
            response.responses.forEach((resp, idx) => {
              if (!resp.success) {
                console.error('❌ Failed token:', validTokens[idx]);
                console.error('❌ Error code:', resp.error?.code);
                console.error('❌ Error message:', resp.error?.message);
                
                // 🔥 SUPPRIMER LES TOKENS INVALIDES
                if (resp.error?.code === 'messaging/invalid-registration-token' || 
                    resp.error?.code === 'messaging/registration-token-not-registered') {
                  _removeInvalidToken(validTokens[idx]);
                }
              }
            });
          }
        } else {
          console.log('⚠️ No valid tokens found');
        }
      } else {
        console.log('⚠️ No tokens provided');
      }
      
      // Supprimer le document
      await snapshot.ref.delete();
      console.log('🗑️ Document deleted');
      
    } catch (error) {
      console.error('❌ Error in sendNotification:', error);
    }
  });

// 🔥 FONCTION DÉDIÉE POUR LES SANCTIONS (DÉCLENCHEMENT AUTOMATIQUE)
exports.onSanctionCreated = functions.firestore
  .document('sanctions/{sanctionId}')
  .onCreate(async (snapshot, context) => {
    console.log('🚀 Nouvelle sanction détectée:', context.params.sanctionId);
    
    try {
      const sanction = snapshot.data();
      console.log('📋 Données sanction:', sanction);

      // Vérifier que la sanction est active
      if (sanction.isActive === false) {
        console.log('⚠️ Sanction non active, notification ignorée');
        return;
      }

      // Récupérer les informations du parent
      const studentDoc = await admin.firestore()
        .collection('students')
        .doc(sanction.studentId)
        .get();

      if (!studentDoc.exists) {
        console.log('❌ Élève non trouvé:', sanction.studentId);
        return;
      }

      const studentData = studentDoc.data();
      const parentId = studentData.parentId;

      if (!parentId) {
        console.log('⚠️ Aucun parent associé à l\'élève');
        return;
      }

      console.log('👨‍👦 Parent trouvé:', parentId);

      // Récupérer le token FCM du parent
      const tokenDoc = await admin.firestore()
        .collection('user_fcm_tokens')
        .doc(parentId)
        .get();

      if (!tokenDoc.exists || !tokenDoc.data().token) {
        console.log('❌ Token FCM non trouvé pour le parent:', parentId);
        return;
      }

      const token = tokenDoc.data().token;
      const tokens = [token];

      console.log('✅ Token FCM trouvé pour le parent');

      // Préparer le message de notification
      const sanctionTypeText = getSanctionTypeText(sanction.type);
      const notificationData = {
        type: 'sanction',
        studentId: sanction.studentId,
        studentName: sanction.studentName,
        teacherName: sanction.teacherName,
        sanctionType: sanction.type,
        sanctionTypeText: sanctionTypeText,
        reason: sanction.reason,
        classId: sanction.classId,
        sanctionId: context.params.sanctionId,
        parentId: parentId,
        timestamp: new Date().toISOString(),
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      };

      // 🔥 CRÉER UNE DEMANDE DE NOTIFICATION
      await admin.firestore()
        .collection('notification_requests')
        .doc()
        .set({
          tokens: tokens,
          title: `⚖️ Sanction - ${sanction.studentName}`,
          body: `${sanctionTypeText}: ${sanction.reason.substring(0, 100)}${sanction.reason.length > 100 ? '...' : ''}`,
          data: notificationData,
          notificationType: 'sanction',
          priority: 'high',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

      console.log('✅ Demande de notification créée pour la sanction');

    } catch (error) {
      console.error('❌ Erreur fonction onSanctionCreated:', error);
    }
  });

// 🔥 FONCTION POUR LES MESSAGES DE CHAT (CONSERVÉE POUR COMPATIBILITÉ)
exports.onMessageCreated = functions.firestore
  .document('messages/{messageId}')
  .onCreate(async (snapshot, context) => {
    console.log('💬 Nouveau message détecté:', context.params.messageId);
    
    try {
      const message = snapshot.data();
      
      // Récupérer le token du destinataire
      const receiverId = message.receiverId;
      const tokenDoc = await admin.firestore()
        .collection('user_fcm_tokens')
        .doc(receiverId)
        .get();

      if (!tokenDoc.exists || !tokenDoc.data().token) {
        console.log('❌ Token FCM non trouvé pour le destinataire:', receiverId);
        return;
      }

      const token = tokenDoc.data().token;

      const notificationData = {
        type: 'message',
        conversationId: message.conversationId,
        senderId: message.senderId,
        senderName: message.senderName,
        message: message.content,
        timestamp: new Date().toISOString(),
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      };

      await admin.firestore()
        .collection('notification_requests')
        .doc()
        .set({
          tokens: [token],
          title: `💬 ${message.senderName}`,
          body: message.content.substring(0, 100) + (message.content.length > 100 ? '...' : ''),
          data: notificationData,
          notificationType: 'message',
          priority: 'normal',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

      console.log('✅ Notification message créée');

    } catch (error) {
      console.error('❌ Erreur fonction onMessageCreated:', error);
    }
  });

// 🔥 FONCTION POUR NETTOYER LES TOKENS INVALIDES
async function _removeInvalidToken(token) {
  try {
    console.log('🧹 Nettoyage token invalide:', token.substring(0, 20) + '...');
    
    // Trouver le document utilisateur associé à ce token
    const tokensSnapshot = await admin.firestore()
      .collection('user_fcm_tokens')
      .where('token', '==', token)
      .get();

    if (!tokensSnapshot.empty) {
      const batch = admin.firestore().batch();
      
      tokensSnapshot.docs.forEach(doc => {
        batch.delete(doc.ref);
        console.log('🗑️ Token supprimé pour user:', doc.id);
      });
      
      await batch.commit();
      console.log('✅ Tokens invalides nettoyés');
    }
  } catch (error) {
    console.error('❌ Erreur nettoyage token:', error);
  }
}

// Helper pour les types de sanctions
function getSanctionTypeText(type) {
  const types = {
    'remarqueOrale': 'Remarque orale',
    'observationEcrite': 'Observation écrite',
    'travailEducatif': 'Travail éducatif',
    'avertissement': 'Avertissement',
    'tacheAide': 'Tâche d\'aide',
    'detention': 'Retenue',
    'exclusion': 'Exclusion',
    'autre': 'Autre sanction'
  };
  return types[type] || 'Sanction';
}

// 🔥 FONCTION DE SANTÉ
exports.healthCheck = functions.https.onRequest(async (request, response) => {
  try {
    const db = admin.firestore();
    
    // Vérifier la connexion Firestore
    await db.collection('users').limit(1).get();
    
    response.json({ 
      status: 'healthy',
      message: 'Firebase Functions operational',
      project: 'scoutetrampe',
      timestamp: new Date().toISOString(),
      services: {
        firestore: 'connected',
        messaging: 'available',
        functions: 'running'
      }
    });
  } catch (error) {
    console.error('❌ Health check failed:', error);
    response.status(500).json({
      status: 'unhealthy',
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// 🔥 FONCTION DE TEST MANUEL
exports.sendTestNotification = functions.https.onRequest(async (request, response) => {
  try {
    const { token, title, body } = request.query;
    
    if (!token) {
      return response.status(400).json({ error: 'Token required' });
    }

    const message = {
      notification: {
        title: title || 'Test Notification',
        body: body || 'This is a test notification',
      },
      data: {
        type: 'test',
        timestamp: new Date().toISOString(),
      },
      token: token,
    };

    const result = await admin.messaging().send(message);
    
    response.json({
      success: true,
      messageId: result,
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    console.error('❌ Test notification failed:', error);
    response.status(500).json({
      success: false,
      error: error.message
    });
  }
});