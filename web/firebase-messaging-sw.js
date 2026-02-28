importScripts('https://www.gstatic.com/firebasejs/9.22.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.22.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyD_IqEGaRR3pbbDjAI70hsk1Lfn9Dslr4o",
  authDomain: "mochat-backend.firebaseapp.com",
  projectId: "mochat-backend",
  storageBucket: "mochat-backend.appspot.com",
  messagingSenderId: "714779797129",
  appId: "1:714779797129:web:922b3882ffbf2b3b4cc858",
  measurementId: "G-516MGWVCXJ"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
    console.log('Received background message: ', payload);
    
    const notificationTitle = payload.notification?.title || 'Mini Cafe';
    const notificationOptions = {
        body: payload.notification?.body || 'You have a new message',
        icon: '/icons/icon-192.png'
    };

    self.registration.showNotification(notificationTitle, notificationOptions);
});