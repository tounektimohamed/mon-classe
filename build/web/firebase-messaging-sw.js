// firebase-messaging-sw.js
importScripts('https://www.gstatic.com/firebasejs/9.22.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.22.0/firebase-messaging-compat.js');

console.log('[firebase-messaging-sw.js] Chargement du Service Worker...');

// Initialisation Firebase dans le Service Worker avec VOS VRAIES VALEURS
firebase.initializeApp({
  apiKey: "AIzaSyA3MCEzAmK163Kqj4b-v5nZQOndWQKedis",
  authDomain: "scoutetrampe.firebaseapp.com",
  projectId: "scoutetrampe",
  storageBucket: "scoutetrampe.firebasestorage.app",
  messagingSenderId: "120598335519",
  appId: "1:120598335519:web:9d433ea9f57d7202c2c52a"
});

const messaging = firebase.messaging();

console.log('[firebase-messaging-sw.js] Firebase Messaging initialisé');

// Gestion des messages en arrière-plan
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] 📨 Message FCM reçu:', payload);
  
  const notificationTitle = payload.notification?.title || 'Joussour - Nouveau message';
  const notificationOptions = {
    body: payload.notification?.body || 'Vous avez reçu un nouveau message dans Joussour',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    tag: 'joussour-notification',
    requireInteraction: true,
    data: payload.data || {},
    vibrate: [200, 100, 200]
  };

  console.log('[firebase-messaging-sw.js] Affichage notification:', notificationTitle);

  // Afficher la notification
  return self.registration.showNotification(notificationTitle, notificationOptions);
});

// Gestion du clic sur les notifications
self.addEventListener('notificationclick', function(event) {
  console.log('[firebase-messaging-sw.js] 🔔 Notification cliquée:', event.notification);
  
  event.notification.close();

  // Ouvrir l'application au clic sur la notification
  event.waitUntil(
    clients.matchAll({type: 'window', includeUncontrolled: true})
    .then(function(clientList) {
      // Essayer de trouver une fenêtre ouverte de l'app
      for (const client of clientList) {
        if (client.url.includes(self.location.origin) && 'focus' in client) {
          console.log('[firebase-messaging-sw.js] Focus sur fenêtre existante');
          return client.focus();
        }
      }
      // Ouvrir une nouvelle fenêtre si aucune n'existe
      if (clients.openWindow) {
        console.log('[firebase-messaging-sw.js] Ouverture nouvelle fenêtre');
        return clients.openWindow('/');
      }
    })
  );
});

// Gestion de la fermeture des notifications
self.addEventListener('notificationclose', function(event) {
  console.log('[firebase-messaging-sw.js] Notification fermée:', event.notification);
});

console.log('[firebase-messaging-sw.js] Service Worker prêt');