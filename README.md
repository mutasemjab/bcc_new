# BCC Chat

تطبيق مراسلة فوري (Real-time) مبني بـ **Flutter + Firebase** بمعمارية **Clean Architecture** وإدارة حالة **BLoC**، مع مكالمات صوت وفيديو عبر **Agora**.

A real-time messaging app built with Flutter, Firebase, BLoC and Clean Architecture, with Agora-powered voice & video calls.

---

## ✨ الميزات | Features

| | |
|---|---|
| 🔐 **Auth** | Email/password (sign up, sign in, reset) and phone number + SMS OTP (auto-retrieval on Android) |
| 💬 **Messaging** | Text, photos (multi-select), video, **voice notes with a real recorded waveform**, documents, **location** (OpenStreetMap preview, no API key) |
| ✅ **Receipts** | Pending ⏱ → Sent ✓ → Delivered ✓✓ → Read ✓✓ (blue), per participant, with a "Message info" sheet |
| ✍️ **Live** | Typing indicators, online / last seen, unread counters, offline-first (Firestore cache) |
| 💡 **Interactions** | Swipe-to-reply, quoted replies, emoji reactions, edit (15 min), delete for me / for everyone, copy, emoji keyboard |
| 👥 **Groups** | Create with photo & description, admins, add/remove members, promote/dismiss admins, leave (auto-promotes next admin), system notices |
| 📞 **Calls** | 1:1 and **group** voice & video calls via Agora: ringing screen, draggable PiP self-view, grid for groups, mute / camera / speaker / switch camera, call log with missed calls |
| 🟢 **Stories** | Text stories (colour backgrounds) and photo stories with captions, 24h expiry, segmented rings, tap/hold/swipe viewer, "viewed by" list |
| 🔔 **Push** | FCM notifications for messages and incoming calls (Cloud Functions), tap to open the chat |
| 🎨 **Design** | Custom design system: royal-blue → aqua gradient, glassmorphism bottom bar, painted chat wallpaper, dark & light themes, micro-animations everywhere, Plus Jakarta Sans + IBM Plex Sans Arabic |
| 🛡 **Security** | Firestore & Storage security rules for every collection; Agora tokens minted server-side for call members only |

---

## 🏛 المعمارية | Architecture

```
lib/
├── app/                      # Composition root: DI (get_it), router (go_router), shell
├── core/                     # Theme, shared widgets, errors, utils, platform services
└── features/
    ├── auth/                 # Email + phone auth, session/presence
    ├── users/                # Profiles, search, contact info
    ├── chat/                 # Chats, messages, groups
    ├── calls/                # Agora RTC + Firestore signalling
    ├── status/               # Stories
    └── settings/
        └── <feature>/
            ├── domain/       # Entities, repository interfaces, use cases  (pure Dart)
            ├── data/         # Models, Firebase data sources, repository impls
            └── presentation/ # BLoCs/Cubits, pages, widgets
```

- **Dependency rule:** `presentation → domain ← data`. Domain has no Flutter/Firebase imports.
- Repositories return `Either<Failure, T>` (fpdart); Firebase exceptions never reach the UI.
- One BLoC per screen + session-wide BLoCs (`SessionBloc`, `ChatListBloc`, `StatusBloc`, `IncomingCallCubit`, `CallLogCubit`) started/stopped by auth state.

### Firestore data model

```
users/{uid}                     name, nameLower, about, photoUrl, email, phone, isOnline, lastSeen, fcmTokens[]
chats/{chatId}                  isGroup, participants[], admins[], name, photoUrl, description,
                                lastMessage{}, updatedAt, unread{uid:n}, typing{uid:bool}, pinnedBy[], mutedBy[]
chats/{chatId}/messages/{id}    senderId, type, text, mediaUrl, fileName, fileSize, durationMs, waveform[],
                                latitude, longitude, replyTo{}, createdAt, deliveredTo[], readBy[],
                                reactions{uid:emoji}, deletedFor[], deletedForEveryone, isEdited
statuses/{id}                   userId, type, text, backgroundColor, mediaUrl, createdAt, expiresAt, viewers[]
calls/{callId}                  chatId, callerId, type, isGroup, participants[], joined[], declined[], status, …
```
1:1 chat ids are deterministic: `sorted(uidA, uidB).join('_')`.

---

## 🚀 التشغيل | Setup

**Requirements:** Flutter **3.29+**, Node 20, Firebase CLI, a Firebase project on the **Blaze** plan (needed for Cloud Functions), an Agora account.

### 1) Generate the platform folders
```bash
cd bcc_chat
flutter create --org com.bcc --project-name bcc_chat --platforms android,ios .
flutter pub get
```
(`flutter create` keeps existing files, including the provided `android/app/src/main/AndroidManifest.xml`.)

### 2) Firebase
1. Create a project in the Firebase console.
2. **Authentication** → enable **Email/Password** and **Phone**.
3. Create **Firestore** and **Storage**.
4. Connect the app:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure      # overwrites lib/firebase_options.dart
   ```
5. Deploy rules, indexes and functions:
   ```bash
   cd functions && npm install && cd ..
   firebase deploy --only firestore:rules,firestore:indexes,storage,functions
   ```

### 3) Android
- In `android/app/build.gradle(.kts)` set `minSdk = 24`.
- Add your debug/release **SHA-1 and SHA-256** in Firebase project settings (required for phone auth).

### 4) iOS
- In `ios/Podfile`: `platform :ios, '13.0'`.
- Copy the keys from `docs/ios_info_plist_keys.xml` into `ios/Runner/Info.plist`.
- Xcode → Signing & Capabilities → add **Push Notifications** and **Background Modes** (Audio, VoIP, Remote notifications).
- Upload an **APNs key** in Firebase → Cloud Messaging (needed for push and phone auth).

### 5) Agora (calls)
1. Create a project at console.agora.io → copy the **App ID** and enable the **App Certificate** (secure mode).
2. Store them as function secrets, then redeploy functions:
   ```bash
   firebase functions:secrets:set AGORA_APP_ID
   firebase functions:secrets:set AGORA_APP_CERTIFICATE
   firebase deploy --only functions
   ```
3. Run the app with the App ID:
   ```bash
   flutter run --dart-define=AGORA_APP_ID=your_app_id
   ```

### 6) Tests
```bash
flutter test
```

---

## 📌 ملاحظات | Notes & next steps

- **Code was not compiled in the authoring environment** (no Flutter SDK available there). Run `flutter analyze` after `flutter pub get`; if a package released a breaking API change, the fix is usually a one-liner at the call site.
- **Background ringing:** when the app is killed, an incoming call arrives as a high-priority push notification. For a native full-screen call UI (CallKit / ConnectionService), add `flutter_callkit_incoming` and handle `data.type == "call"` in `firebaseMessagingBackgroundHandler`.
- **Android notification channels:** the functions target channels `messages` and `calls`. Create them at startup (e.g. with `flutter_local_notifications`) to customise sound/importance; otherwise Android uses the default channel.
- **Encryption:** data is encrypted in transit and at rest by Firebase, and access is enforced by security rules. Messages are **not** end-to-end encrypted.
- **Stories visibility:** any signed-in user can read active stories (filtering to contacts happens in the client). Tighten in `firestore.rules` if you need stricter privacy.
- **Localisation:** UI strings are English; Arabic text renders with IBM Plex Sans Arabic. For a full Arabic UI add `flutter_localizations` + ARB files and switch the remaining left/right paddings to `EdgeInsetsDirectional`.
