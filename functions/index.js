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

// Fonction de test
exports.helloWorld = functions.https.onRequest((request, response) => {
  response.json({ 
    message: 'Hello from Firebase Functions!',
    status: 'working',
    project: 'scoutetrampe',
    timestamp: new Date().toISOString()
  });
});