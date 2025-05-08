const functions = require("firebase-functions"); // v1 API
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

/**
 * Triggered when a Firebase‑Auth account is deleted.
 * Deletes every piece of Firestore data that belongs to that UID.
 */
exports.nukeUserData = functions.auth.user().onDelete(async (user) => {
  const uid = user.uid;

  // 1️⃣ delete the user document itself
  await db.collection("users").doc(uid).delete();

  // 2️⃣ loop through the other top‑level collections
  const ownedCollections = [
    "habits",
    "daySchedules",
    "weekSchedules",
    "monthSchedules",
    "UserNotes",
  ];

  for (const col of ownedCollections) {
    const qSnap = await db.collection(col)
        .where("ownerId", "==", uid)
        .get();

    const batch = db.batch();
    qSnap.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
  }

  console.log(`🔴  All Firestore data for user ${uid} has been removed.`);
});
