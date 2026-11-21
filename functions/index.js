/**
 * BCC Chat — Cloud Functions (2nd gen).
 *
 *  - generateAgoraToken : callable, mints short-lived Agora RTC tokens for call members only
 *  - onMessageCreated   : push notification for every new chat message
 *  - onCallCreated      : high-priority push to ring the callees
 *  - cleanupStatuses    : hourly purge of expired stories (+ their images)
 *  - sendScheduledMessages : every minute, sends due "send later" messages
 *  - onGroupInvite      : push when someone is invited to a group
 *
 * Agora credentials are read from functions/.env (server-side only, never shipped in the app):
 *   AGORA_APP_ID=...
 *   AGORA_APP_CERTIFICATE=...
 */
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { getStorage } = require("firebase-admin/storage");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated, onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const logger = require("firebase-functions/logger");
const { RtcTokenBuilder, RtcRole } = require("agora-token");

initializeApp();
const db = getFirestore();

const TOKEN_TTL_SECONDS = 60 * 60 * 2; // 2 hours

// ───────────────────────────── Agora token ─────────────────────────────

exports.generateAgoraToken = onCall(
  { region: "us-central1" },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Sign in first.");

    const { channelName, uid } = request.data || {};
    if (typeof channelName !== "string" || !channelName || !Number.isInteger(uid) || uid <= 0) {
      throw new HttpsError("invalid-argument", "channelName (string) and uid (positive int) are required.");
    }

    // Only participants of the call may join its channel.
    const call = await db.collection("calls").doc(channelName).get();
    if (!call.exists || !(call.get("participants") || []).includes(request.auth.uid)) {
      throw new HttpsError("permission-denied", "You are not part of this call.");
    }

    const appId = process.env.AGORA_APP_ID || "";
    const certificate = process.env.AGORA_APP_CERTIFICATE || "";
    if (!certificate) {
      // Agora project in "testing mode" (App ID only) accepts an empty token.
      return { token: "" };
    }

    const token = RtcTokenBuilder.buildTokenWithUid(
      appId,
      certificate,
      channelName,
      uid,
      RtcRole.PUBLISHER,
      TOKEN_TTL_SECONDS,
      TOKEN_TTL_SECONDS,
    );
    return { token };
  },
);

// ─────────────────────────────── Helpers ───────────────────────────────

function previewOf(m) {
  if (m.deletedForEveryone) return "This message was deleted";
  if (m.viewOnce) return m.type === "audio" ? "① Voice message" : "① Photo";
  switch (m.type) {
    case "image": return m.text ? `📷 ${m.text}` : "📷 Photo";
    case "video": return m.text ? `🎬 ${m.text}` : "🎬 Video";
    case "audio": return "🎤 Voice message";
    case "file": return `📄 ${m.fileName || "Document"}`;
    case "location": return "📍 Location";
    case "sticker": return "💟 Sticker";
    case "poll": return `📊 ${(m.poll && m.poll.question) || "Poll"}`;
    default: return m.text || "";
  }
}

async function tokensFor(uids) {
  if (!uids.length) return [];
  const refs = uids.map((u) => db.collection("users").doc(u));
  const snaps = await db.getAll(...refs);
  return snaps.flatMap((s) => (s.exists ? s.get("fcmTokens") || [] : []).map((t) => ({ uid: s.id, token: t })));
}

/** Sends to many devices and prunes tokens that are no longer valid. */
async function sendToUsers(uids, buildMessage) {
  const entries = await tokensFor(uids);
  if (!entries.length) return;

  for (let i = 0; i < entries.length; i += 500) {
    const chunk = entries.slice(i, i + 500);
    const res = await getMessaging().sendEach(chunk.map((e) => ({ ...buildMessage(e.uid), token: e.token })));

    const stale = [];
    res.responses.forEach((r, idx) => {
      const code = r.error && r.error.code;
      if (code === "messaging/registration-token-not-registered" || code === "messaging/invalid-registration-token") {
        stale.push(chunk[idx]);
      }
    });
    await Promise.all(
      stale.map((e) => db.collection("users").doc(e.uid).update({ fcmTokens: FieldValue.arrayRemove(e.token) })),
    );
  }
}

// ───────────────────────────── New message ─────────────────────────────

exports.onMessageCreated = onDocumentCreated("chats/{chatId}/messages/{messageId}", async (event) => {
  const message = event.data && event.data.data();
  if (!message || message.type === "system") return;

  const { chatId } = event.params;
  const chatSnap = await db.collection("chats").doc(chatId).get();
  if (!chatSnap.exists) return;
  const chat = chatSnap.data();

  const muted = new Set(chat.mutedBy || []);
  // Media from an anonymous member waits for approval: tell the admins only.
  const audience = message.pendingApproval ? chat.admins || [] : chat.participants || [];
  const recipients = audience.filter((u) => u !== message.senderId && !muted.has(u));
  if (!recipients.length) return;

  const sender = await db.collection("users").doc(message.senderId).get();
  const alias = (chat.anonymous || {})[message.senderId];
  const senderName = alias || (sender.exists && sender.get("name")) || "New message";
  const title = chat.isGroup ? chat.name || "Group" : senderName;
  const body = message.pendingApproval
    ? `${senderName} sent ${previewOf(message)} — needs your approval`
    : chat.isGroup
      ? `${senderName}: ${previewOf(message)}`
      : previewOf(message);

  // Android: data-only, so the app builds one grouped (WhatsApp-style)
  // notification per chat — even when the app is closed.
  // iOS: a normal alert, stacked per chat by thread-id.
  await sendToUsers(recipients, (uid) => ({
    data: {
      type: "message",
      chatId,
      chatTitle: String(title),
      sender: String(senderName),
      body: previewOf(message).slice(0, 300),
      isGroup: chat.isGroup ? "true" : "false",
      sentAt: new Date().toISOString(),
    },
    android: { priority: "high" },
    apns: {
      headers: { "apns-priority": "10" },
      payload: {
        aps: {
          alert: { title, body: body.slice(0, 180) },
          sound: "default",
          "thread-id": chatId,
          badge: (chat.unread && chat.unread[uid]) || 1,
        },
      },
    },
  }));
});

// ─────────────────────────────── Ringing ───────────────────────────────

exports.onCallCreated = onDocumentCreated("calls/{callId}", async (event) => {
  const call = event.data && event.data.data();
  if (!call || call.status !== "ringing") return;

  const callees = (call.participants || []).filter((u) => u !== call.callerId);
  const kind = call.type === "video" ? "video" : "voice";
  const title = call.isGroup ? `${call.title}` : call.callerName;
  const body = call.isGroup ? `${call.callerName} started a group ${kind} call` : `Incoming ${kind} call`;

  await sendToUsers(callees, () => ({
    data: { type: "call", callId: event.params.callId, callType: kind, title: String(title), body },
    android: { priority: "high", ttl: 45 * 1000 },
    apns: {
      headers: { "apns-priority": "10", "apns-expiration": `${Math.floor(Date.now() / 1000) + 45}` },
      payload: { aps: { alert: { title, body }, sound: "default", "interruption-level": "time-sensitive" } },
    },
  }));
});

// ──────────────────────────── Story cleanup ────────────────────────────

exports.cleanupStatuses = onSchedule("every 60 minutes", async () => {
  const expired = await db.collection("statuses").where("expiresAt", "<", Timestamp.now()).limit(500).get();
  if (expired.empty) return;

  const bucket = getStorage().bucket();
  await Promise.all(
    expired.docs.map(async (doc) => {
      const url = doc.get("mediaUrl");
      if (url) {
        try {
          const path = decodeURIComponent(new URL(url).pathname.split("/o/")[1] || "");
          if (path) await bucket.file(path).delete({ ignoreNotFound: true });
        } catch (e) {
          logger.warn("Could not delete story media", { id: doc.id, error: String(e) });
        }
      }
      await doc.ref.delete();
    }),
  );
  logger.info(`Deleted ${expired.size} expired stories`);
});

// ───────────────────────── Scheduled messages ─────────────────────────

/** Mirrors the app's preview text for the chat list. */
function lastMessageFor(id, senderId, text) {
  return { id, senderId, type: "text", preview: text, createdAt: FieldValue.serverTimestamp() };
}

/**
 * Sends "send later" messages that are due. Each one is deleted in the same
 * transaction that writes the message, so the app and the server can never
 * both send it.
 */
exports.sendScheduledMessages = onSchedule("every 1 minutes", async () => {
  const due = await db.collectionGroup("scheduled").where("sendAt", "<=", Timestamp.now()).limit(200).get();
  for (const doc of due.docs) {
    const senderId = doc.ref.parent.parent.id;
    try {
      await db.runTransaction(async (tx) => {
        const fresh = await tx.get(doc.ref);
        if (!fresh.exists) return;
        const s = fresh.data();
        const chatRef = db.collection("chats").doc(s.chatId);
        const chat = await tx.get(chatRef);
        const participants = s.isGroup ? (chat.exists ? chat.get("participants") || [] : []) : s.participants || [];
        // All reads first (transaction rule), then writes.
        let blocked = false;
        if (!s.isGroup) {
          // Respect blocks made after the message was scheduled.
          const other = participants.find((u) => u !== senderId);
          if (other) {
            const [b1, b2] = await Promise.all([
              tx.get(db.doc(`users/${other}/blocked/${senderId}`)),
              tx.get(db.doc(`users/${senderId}/blocked/${other}`)),
            ]);
            blocked = b1.exists || b2.exists;
          }
        }
        tx.delete(doc.ref);
        if (!participants.includes(senderId) || blocked) return; // left the group / blocked since scheduling

        const msgRef = chatRef.collection("messages").doc();
        tx.set(msgRef, {
          senderId,
          type: "text",
          text: String(s.text || "").trim(),
          createdAt: FieldValue.serverTimestamp(),
          clientCreatedAt: Timestamp.now(),
          deliveredTo: [],
          readBy: [],
        });
        const unread = {};
        for (const p of participants) if (p !== senderId) unread[p] = FieldValue.increment(1);
        tx.set(
          chatRef,
          {
            ...(s.isGroup ? {} : { participants, isGroup: false }),
            lastMessage: lastMessageFor(msgRef.id, senderId, String(s.text || "").trim()),
            updatedAt: FieldValue.serverTimestamp(),
            unread,
          },
          { merge: true },
        );
      });
    } catch (e) {
      logger.warn("Scheduled message failed", { id: doc.id, error: String(e) });
    }
  }
});

// ─────────────────────────── Group invitations ───────────────────────────

exports.onGroupInvite = onDocumentWritten("chats/{chatId}", async (event) => {
  const before = (event.data.before.exists && event.data.before.data()) || {};
  const after = (event.data.after.exists && event.data.after.data()) || null;
  if (!after || !after.isGroup) return;

  const was = new Set(before.invited || []);
  const fresh = (after.invited || []).filter((u) => !was.has(u));
  if (!fresh.length) return;

  // Group by inviter so each message names the right person.
  const byInviter = {};
  for (const uid of fresh) {
    const inviter = (after.invitedBy || {})[uid] || after.createdBy;
    (byInviter[inviter] = byInviter[inviter] || []).push(uid);
  }
  for (const [inviterId, uids] of Object.entries(byInviter)) {
    const alias = (after.anonymous || {})[inviterId];
    let inviterName = alias;
    if (!inviterName) {
      const u = await db.collection("users").doc(inviterId).get();
      inviterName = (u.exists && u.get("name")) || "Someone";
    }
    const title = after.name || "Group invitation";
    const body = `${inviterName} invited you to join the group`;
    await sendToUsers(uids, () => ({
      data: { type: "group_invite", chatId: event.params.chatId, title, body },
      android: { priority: "high" },
      apns: { payload: { aps: { alert: { title, body }, sound: "default" } } },
    }));
  }
});
