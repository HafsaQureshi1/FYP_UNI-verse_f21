const admin = require("firebase-admin");
const serviceAccount = require("./credentials/universe-123-firebase-adminsdk-dxv5x-586f17d46e.json"); // Path to JSON file

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const messaging = admin.messaging();
module.exports = messaging;
