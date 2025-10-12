const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// Version SIMPLE qui fonctionne toujours
exports.sendChatNotification = functions.firestore
  .document('notification_requests/{docId}')
  .onCreate(async (snapshot, context) => {
    console.log('🚀 Function triggered for document:', context.params.docId);
    
    try {
      const { tokens, title, body, data } = snapshot.data();
      
      console.log('📧 Title:', title);
      console.log('📝 Body:', body);
      console.log('🔑 Tokens count:', tokens ? tokens.length : 0);
      
      // LOGIQUE DE NOTIFICATION SIMPLE
      if (tokens && tokens.length > 0) {
        const validTokens = tokens.filter(t => t && t.length > 10);
        
        if (validTokens.length > 0) {
          const message = {
            notification: {
              title: title || 'Nouveau message',
              body: body || 'Vous avez un message',
            },
            data: data || {},
            tokens: validTokens,
          };
          
          console.log('📤 Sending FCM to', validTokens.length, 'tokens');
          const response = await admin.messaging().sendEachForMulticast(message);
          console.log('✅ FCM sent - Success:', response.successCount, 'Failures:', response.failureCount);
        }
      }
      
      // Supprimer le document
      await snapshot.ref.delete();
      console.log('🗑️ Document deleted');
      
    } catch (error) {
      console.error('❌ Error:', error);
    }
  });
// Dans functions/index.js
exports.sendSanctionNotification = functions.firestore
  .document('sanctions/{sanctionId}')
  .onCreate(async (snapshot, context) => {
    console.log('🚀 Nouvelle sanction détectée:', context.params.sanctionId);
    
    try {
      const sanction = snapshot.data();
      console.log('📋 Données sanction:', sanction);

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

      // Préparer le message de notification
      const sanctionTypeText = getSanctionTypeText(sanction.type);
      const message = {
        notification: {
          title: `Nouvelle sanction - ${sanction.studentName}`,
          body: `${sanctionTypeText}: ${sanction.reason}`,
        },
        data: {
          type: 'sanction',
          studentId: sanction.studentId,
          studentName: sanction.studentName,
          teacherName: sanction.teacherName,
          sanctionType: sanction.type,
          sanctionTypeText: sanctionTypeText,
          reason: sanction.reason,
          classId: sanction.classId,
          sanctionId: context.params.sanctionId,
          timestamp: new Date().toISOString(),
        },
        tokens: tokens,
      };

      console.log('📤 Envoi FCM à:', parentId);
      const response = await admin.messaging().sendEachForMulticast(message);
      
      console.log('✅ Notification envoyée - Succès:', response.successCount);
      console.log('❌ Échecs:', response.failureCount);

      if (response.failureCount > 0) {
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            console.error(`❌ Erreur envoi token ${tokens[idx]}:`, resp.error);
          }
        });
      }

    } catch (error) {
      console.error('❌ Erreur fonction sanction:', error);
    }
  });

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
// Fonction de test
exports.helloWorld = functions.https.onRequest((request, response) => {
  response.json({ 
    message: 'Hello from Firebase Functions!',
    status: 'working',
    project: 'scoutetrampe',
    timestamp: new Date().toISOString()
  });
});