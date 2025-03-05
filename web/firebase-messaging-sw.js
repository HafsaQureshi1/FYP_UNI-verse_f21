importScripts("https://www.gstatic.com/firebasejs/9.6.1/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/9.6.1/firebase-messaging-compat.js");

firebase.initializeApp({
    
        apiKey: "AIzaSyAiPzBg3xmVl-mo606En3RunPO2Vmq7UU8",
        authDomain: "universe-123.firebaseapp.com",
        projectId: "universe-123",
        storageBucket: "universe-123.firebasestorage.app",
        messagingSenderId: "267004637492",
        appId: "1:267004637492:web:63c18921826a3791053561",
        measurementId: "G-G39DHQ3RVQ"
      
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log("Received background message ", payload);
  self.registration.showNotification(payload.notification.title, {
    body: payload.notification.body,
    icon: "/logo.png"
  });
});
