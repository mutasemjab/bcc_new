import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';

import '../../../../core/constants/firestore_paths.dart';
import '../../../../core/data/storage_data_source.dart';
import '../../../../core/utils/id_utils.dart';
import '../../domain/entities/group_invite.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/entities/outgoing_message.dart';
import '../../domain/entities/scheduled_message.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';

/// All Firestore access for chats, messages and groups.
///
/// Data model
/// ```
/// chats/{chatId}
///   isGroup, participants[], admins[], name, photoUrl, description,
///   lastMessage{id,senderId,type,preview,createdAt}, updatedAt,
///   unread{uid:int}, typing{uid:bool}, pinnedBy[], mutedBy[]
/// chats/{chatId}/messages/{messageId}
///   senderId, type, text, mediaUrl, fileName, fileSize, durationMs, waveform[],
///   latitude, longitude, replyTo{}, createdAt, clientCreatedAt,
///   deliveredTo[], readBy[], deletedFor[], deletedForEveryone, reactions{uid:emoji}
/// ```
class ChatRemoteDataSource {
  ChatRemoteDataSource(this._db, this._storage);
  final FirebaseFirestore _db;
  final StorageDataSource _storage;

  CollectionReference<Map<String, dynamic>> get _chats => _db.collection(FirestorePaths.chats);
  CollectionReference<Map<String, dynamic>> _messages(String chatId) =>
      _db.collection(FirestorePaths.chatMessages(chatId));

  // ── Chats ──────────────────────────────────────────────────────────────

  Stream<List<ChatModel>> watchChats(String uid) => Rx.combineLatest2(
    _chats.where('participants', arrayContains: uid).snapshots().map((s) => s.docs.map(ChatModel.fromDoc).toList()),
    _chats
        .where('formerMembers', arrayContains: uid)
        .snapshots()
        .map((s) => s.docs.map(ChatModel.fromDoc).toList())
        .onErrorReturn(const <ChatModel>[]),
    (List<ChatModel> mine, List<ChatModel> left) =>
        {for (final c in left) c.id: c, for (final c in mine) c.id: c}.values.toList(),
  );

  Stream<ChatModel?> watchChat(String chatId) =>
      _chats.doc(chatId).snapshots().map((d) => d.exists ? ChatModel.fromDoc(d) : null);

  Future<String> ensureDirectChat(String me, String other) async {
    final id = IdUtils.directChatId(me, other);
    final ref = _chats.doc(id);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'isGroup': false,
        'participants': [me, other],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'unread': {me: 0, other: 0},
      });
    }
    return id;
  }

  Future<void> setTyping(String chatId, String uid, bool typing) => _chats.doc(chatId).update({'typing.$uid': typing});

  Future<void> markChatRead(String chatId, String uid) => _chats.doc(chatId).update({'unread.$uid': 0});

  Future<void> togglePin(String chatId, String uid, bool pinned) => _chats.doc(chatId).update({
    'pinnedBy': pinned ? FieldValue.arrayUnion([uid]) : FieldValue.arrayRemove([uid]),
  });

  Future<void> toggleMute(String chatId, String uid, bool muted) => _chats.doc(chatId).update({
    'mutedBy': muted ? FieldValue.arrayUnion([uid]) : FieldValue.arrayRemove([uid]),
  });

  // ── Messages ───────────────────────────────────────────────────────────

  /// Newest first. Includes metadata changes so "pending" clocks flip to ticks.
  /// [after]: only messages newer than this (the user's "clear chat" time).
  Stream<List<MessageModel>> watchMessages(String chatId, int limit, {DateTime? after}) => (after == null
          ? _messages(chatId)
          : _messages(chatId).where('createdAt', isGreaterThan: Timestamp.fromDate(after)))
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots(includeMetadataChanges: true)
      .map((s) => s.docs.map((d) => MessageModel.fromDoc(chatId, d)).toList());

  Future<void> sendMessage(OutgoingMessage m, {void Function(double)? onProgress}) async {
    final msgRef = _messages(m.chatId).doc();

    String? mediaUrl = m.existingMediaUrl;
    if (m.file != null && mediaUrl == null) {
      final ext = _extension(m.fileName ?? m.file!.path);
      mediaUrl = await _storage.uploadFile(
        file: m.file!,
        path: StoragePaths.chatMedia(m.chatId, '${msgRef.id}$ext'),
        contentType: _contentType(m.type, ext),
        onProgress: onProgress,
      );
    }

    final batch = _db.batch()..set(msgRef, _messageData(m, mediaUrl));
    // Media waiting for admin approval doesn't show up in the chat list yet.
    if (!m.pendingApproval) {
      batch.set(_chats.doc(m.chatId), _chatBump(m, msgRef.id, m.participants), SetOptions(merge: true));
    }
    await batch.commit();
  }

  Map<String, dynamic> _messageData(OutgoingMessage m, String? mediaUrl) => {
    'senderId': m.senderId,
    'type': m.type.name,
    'text': m.text.trim(),
    if (mediaUrl != null) 'mediaUrl': mediaUrl,
    if (m.fileName != null) 'fileName': m.fileName,
    if (m.fileSize != null) 'fileSize': m.fileSize,
    if (m.duration != null) 'durationMs': m.duration!.inMilliseconds,
    if (m.waveform.isNotEmpty) 'waveform': m.waveform,
    if (m.latitude != null) 'latitude': m.latitude,
    if (m.longitude != null) 'longitude': m.longitude,
    if (m.replyTo != null) 'replyTo': MessageModel.replyToMap(m.replyTo!),
    if (m.stickerId != null) 'stickerId': m.stickerId,
    if (m.poll != null) 'poll': m.poll!.toMap(),
    if (m.poll != null) 'pollVotes': <String, dynamic>{},
    if (m.forwardCount > 0) 'forwardCount': m.forwardCount,
    if (m.viewOnce) 'viewOnce': true,
    if (m.viewOnce) 'openedBy': <String>[],
    if (m.pendingApproval) 'pendingApproval': true,
    'createdAt': FieldValue.serverTimestamp(),
    'clientCreatedAt': Timestamp.now(),
    'deliveredTo': <String>[],
    'readBy': <String>[],
  };

  /// Chat-doc changes that go with a new message (preview, unread counters).
  Map<String, dynamic> _chatBump(OutgoingMessage m, String messageId, List<String> participants) {
    final preview =
        MessageModel(
          id: messageId,
          chatId: m.chatId,
          senderId: m.senderId,
          type: m.type,
          text: m.text.trim(),
          fileName: m.fileName,
          poll: m.poll,
          viewOnce: m.viewOnce,
        ).preview;
    return {
      // Direct chats may be created lazily here; group membership is never
      // rewritten by a send to avoid resurrecting removed members.
      if (!m.isGroup) 'participants': participants,
      if (!m.isGroup) 'isGroup': false,
      'lastMessage': _lastMessage(messageId, m.senderId, m.type, preview),
      'updatedAt': FieldValue.serverTimestamp(),
      'unread': {
        for (final p in participants)
          if (p != m.senderId) p: FieldValue.increment(1),
      },
      'typing': {m.senderId: false},
    };
  }

  /// Clears the chat for [uid] only (WhatsApp "Clear chat").
  Future<void> clearChat(String chatId, String uid) =>
  // Server time: the phone clock may be wrong, and comparing it with server
  // message times would hide new messages.
  _chats.doc(chatId).update({'clearedAt.$uid': FieldValue.serverTimestamp(), 'unread.$uid': 0});

  /// Deletes the chat for [uid] only: hidden until someone writes again.
  Future<void> deleteChat(String chatId, String uid) {
    return _chats.doc(chatId).update({
      'clearedAt.$uid': FieldValue.serverTimestamp(),
      'deletedAt.$uid': FieldValue.serverTimestamp(),
      'unread.$uid': 0,
    });
  }

  /// [read] false → only "delivered" (read receipts turned off).
  Future<void> markMessagesRead(String chatId, String uid, List<String> ids, {bool read = true}) async {
    for (var i = 0; i < ids.length; i += 450) {
      final batch = _db.batch();
      for (final id in ids.skip(i).take(450)) {
        batch.update(_messages(chatId).doc(id), {
          if (read) 'readBy': FieldValue.arrayUnion([uid]),
          'deliveredTo': FieldValue.arrayUnion([uid]),
        });
      }
      await batch.commit();
    }
  }

  Future<void> markRecentDelivered(String chatId, String uid, int count) async {
    final snap = await _messages(chatId).orderBy('createdAt', descending: true).limit(count.clamp(1, 100)).get();
    final batch = _db.batch();
    var any = false;
    for (final d in snap.docs) {
      final data = d.data();
      final delivered = (data['deliveredTo'] as List<dynamic>?) ?? const [];
      if (data['senderId'] != uid && !delivered.contains(uid)) {
        batch.update(d.reference, {
          'deliveredTo': FieldValue.arrayUnion([uid]),
        });
        any = true;
      }
    }
    if (any) await batch.commit();
  }

  Future<void> deleteForMe(String chatId, String messageId, String uid) => _messages(chatId).doc(messageId).update({
    'deletedFor': FieldValue.arrayUnion([uid]),
  });

  Future<void> deleteForEveryone(String chatId, String messageId) async {
    final ref = _messages(chatId).doc(messageId);
    final snap = await ref.get();
    final mediaUrl = snap.data()?['mediaUrl'] as String?;
    await ref.update({
      'deletedForEveryone': true,
      'text': '',
      'mediaUrl': FieldValue.delete(),
      'fileName': FieldValue.delete(),
      'waveform': FieldValue.delete(),
      'latitude': FieldValue.delete(),
      'longitude': FieldValue.delete(),
      'stickerId': FieldValue.delete(),
      'poll': FieldValue.delete(),
      'pollVotes': FieldValue.delete(),
      'reactions': <String, dynamic>{},
    });
    await _updateLastPreviewIfLatest(chatId, messageId, 'This message was deleted');
    if (mediaUrl != null) {
      try {
        await _storage.deleteByUrl(mediaUrl);
      } catch (_) {
        /* best effort */
      }
    }
  }

  Future<void> editMessage(String chatId, String messageId, String text) async {
    await _messages(chatId).doc(messageId).update({'text': text, 'isEdited': true});
    await _updateLastPreviewIfLatest(chatId, messageId, text);
  }

  /// Marks a view-once message as opened by [uid]. When everyone has opened
  /// it, the media file itself is deleted from storage.
  Future<void> markOpened(String chatId, String messageId, String uid) async {
    final ref = _messages(chatId).doc(messageId);
    await ref.update({
      'openedBy': FieldValue.arrayUnion([uid]),
    });
    try {
      final msg = (await ref.get()).data() ?? const {};
      final chat = (await _chats.doc(chatId).get()).data() ?? const {};
      final recipients = List<String>.from(chat['participants'] as List<dynamic>? ?? const [])..remove(msg['senderId']);
      final opened = List<String>.from(msg['openedBy'] as List<dynamic>? ?? const []);
      final url = msg['mediaUrl'] as String?;
      if (url != null && recipients.every(opened.contains)) await _storage.deleteByUrl(url);
    } catch (_) {
      /* best effort */
    }
  }

  Future<void> react(String chatId, String messageId, String uid, String? emoji) =>
      _messages(chatId).doc(messageId).update({'reactions.$uid': emoji ?? FieldValue.delete()});

  /// Replaces this user's vote; an empty list removes it.
  Future<void> votePoll(String chatId, String messageId, String uid, List<String> optionIds) =>
      _messages(chatId).doc(messageId).update({'pollVotes.$uid': optionIds.isEmpty ? FieldValue.delete() : optionIds});

  // ── Groups ─────────────────────────────────────────────────────────────

  Future<String> createGroup({
    required String creatorId,
    required String creatorName,
    required String name,
    required List<String> memberIds,
    String? description,
    File? photo,
  }) async {
    final ref = _chats.doc();
    String? photoUrl;
    if (photo != null) {
      photoUrl = await _storage.uploadFile(
        file: photo,
        path: StoragePaths.groupPhoto(ref.id),
        contentType: 'image/jpeg',
      );
    }
    // Only the creator is a member; everyone else gets an invitation to accept.
    final participants = [creatorId];
    final msgRef = _messages(ref.id).doc();
    final notice = '$creatorName created the group "$name"';
    // One write per document so the security rules see a single create.
    final batch =
        _db.batch()
          ..set(ref, {
            'isGroup': true,
            'name': name,
            'description': description ?? '',
            if (photoUrl != null) 'photoUrl': photoUrl,
            'participants': participants,
            'admins': [creatorId],
            'invited': memberIds,
            'invitedBy': {for (final u in memberIds) u: creatorId},
            'createdBy': creatorId,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'unread': {for (final p in participants) p: 0},
            'lastMessage': _lastMessage(msgRef.id, creatorId, MessageType.system, notice),
          })
          ..set(msgRef, _systemData(creatorId, notice));
    await batch.commit();
    return ref.id;
  }

  Future<void> updateGroup(String chatId, {String? name, String? description, File? photo}) async {
    String? photoUrl;
    if (photo != null) {
      photoUrl = await _storage.uploadFile(
        file: photo,
        path: StoragePaths.groupPhoto(chatId),
        contentType: 'image/jpeg',
      );
    }
    await _chats.doc(chatId).update({
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (photoUrl != null) 'photoUrl': photoUrl,
    });
  }

  /// Sends invitations; people join only after they accept.
  Future<void> addMembers(String chatId, List<String> uids, String actorId, String actorName, List<String> names) =>
      _groupChange(chatId, actorId, '$actorName invited ${uids.length == 1 ? '1 person' : '${uids.length} people'}', {
        'invited': FieldValue.arrayUnion(uids),
        for (final u in uids) 'invitedBy.$u': actorId,
      });

  /// Invites people by email. Emails that already have an account become a
  /// normal invitation; the rest wait in `invitedEmails` until that person
  /// signs up with the same (verified) email.
  Future<({int existing, int pending})> inviteByEmail(
    String chatId,
    List<String> emails,
    String actorId,
    String actorName,
  ) async {
    final wanted = {for (final e in emails) e.trim().toLowerCase()}..removeWhere((e) => e.isEmpty);
    if (wanted.isEmpty) return (existing: 0, pending: 0);
    final chat = (await _chats.doc(chatId).get()).data() ?? const {};
    final members = {...List<String>.from(chat['participants'] as List<dynamic>? ?? const [])};
    final list = wanted.toList();
    final found = <String, String>{}; // email → uid
    for (var i = 0; i < list.length; i += 30) {
      final chunk = list.sublist(i, i + 30 > list.length ? list.length : i + 30);
      final snap = await _db.collection(FirestorePaths.users).where('email', whereIn: chunk).get();
      for (final d in snap.docs) {
        final email = (d.data()['email'] as String?)?.toLowerCase();
        if (email != null) found[email] = d.id;
      }
    }
    final uids = found.values.where((u) => !members.contains(u) && u != actorId).toSet().toList();
    final pending = wanted.where((e) => !found.containsKey(e)).toList();
    final total = uids.length + pending.length;
    if (total == 0) return (existing: 0, pending: 0);
    await _groupChange(chatId, actorId, '$actorName invited ${total == 1 ? '1 person' : '$total people'}', {
      if (uids.isNotEmpty) 'invited': FieldValue.arrayUnion(uids),
      for (final u in uids) 'invitedBy.$u': actorId,
      if (pending.isNotEmpty) 'invitedEmails': FieldValue.arrayUnion(pending),
    });
    return (existing: uids.length, pending: pending.length);
  }

  Future<void> cancelEmailInvite(String chatId, String email) => _chats.doc(chatId).update({
    'invitedEmails': FieldValue.arrayRemove([email]),
  });

  /// After sign-up: turn "invited by email" into a normal invitation for me.
  Future<int> claimEmailInvites(String uid, String email) async {
    final snap = await _chats.where('invitedEmails', arrayContains: email).get();
    for (final d in snap.docs) {
      final inviter = (d.data()['createdBy'] as String?) ?? '';
      await d.reference.update({
        'invitedEmails': FieldValue.arrayRemove([email]),
        'invited': FieldValue.arrayUnion([uid]),
        if (inviter.isNotEmpty) 'invitedBy.$uid': inviter,
      });
    }
    return snap.docs.length;
  }

  Future<void> cancelInvite(String chatId, String uid) => _chats.doc(chatId).update({
    'invited': FieldValue.arrayRemove([uid]),
    'invitedBy.$uid': FieldValue.delete(),
  });

  Future<void> removeMember(String chatId, String uid, String actorId, String actorName, String memberName) =>
      _groupChange(chatId, actorId, '$actorName removed $memberName', {
        'participants': FieldValue.arrayRemove([uid]),
        'admins': FieldValue.arrayRemove([uid]),
      });

  /// Applies a membership change and posts the system notice atomically,
  /// writing each document exactly once.
  Future<void> _groupChange(String chatId, String actorId, String notice, Map<String, Object> changes) {
    final msgRef = _messages(chatId).doc();
    final batch =
        _db.batch()
          ..update(_chats.doc(chatId), {
            ...changes,
            'lastMessage': _lastMessage(msgRef.id, actorId, MessageType.system, notice),
            'updatedAt': FieldValue.serverTimestamp(),
          })
          ..set(msgRef, _systemData(actorId, notice));
    return batch.commit();
  }

  /// Leaves a group; if the last admin leaves, the oldest member is promoted.
  Future<void> leaveGroup(String chatId, String uid, String name) async {
    final ref = _chats.doc(chatId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data == null) return;
      final participants = List<String>.from(data['participants'] as List<dynamic>)..remove(uid);
      final admins = List<String>.from((data['admins'] as List<dynamic>?) ?? const [])..remove(uid);
      final anonymous = Map<String, dynamic>.from((data['anonymous'] as Map?) ?? const {});
      // Admins are always public: promote the first member who isn't anonymous.
      if (admins.isEmpty) {
        final next = participants.where((p) => !anonymous.containsKey(p)).firstOrNull;
        if (next != null) admins.add(next);
      }
      final msgRef = _messages(chatId).doc();
      final text = '$name left';
      tx.update(ref, {
        'participants': participants,
        'admins': admins,
        'formerMembers': FieldValue.arrayUnion([uid]),
        'lastMessage': _lastMessage(msgRef.id, uid, MessageType.system, text),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.set(msgRef, _systemData(uid, text));
    });
  }

  /// Admins are announced to every member with a system message.
  Future<void> setAdmin(String chatId, String uid, bool isAdmin) async {
    final user = await _db.collection(FirestorePaths.users).doc(uid).get();
    final name = (user.data()?['name'] as String?) ?? 'A member';
    final msgRef = _messages(chatId).doc();
    final notice = isAdmin ? '$name is now an admin' : '$name is no longer an admin';
    final batch =
        _db.batch()
          ..update(_chats.doc(chatId), {
            'admins': isAdmin ? FieldValue.arrayUnion([uid]) : FieldValue.arrayRemove([uid]),
            'lastMessage': _lastMessage(msgRef.id, uid, MessageType.system, notice),
            'updatedAt': FieldValue.serverTimestamp(),
          })
          ..set(msgRef, _systemData(uid, notice));
    await batch.commit();
  }

  /// The owner leaving ends the group for everyone (read-only from then on).
  Future<void> endGroup(String chatId, String uid, String name) async {
    final chat = (await _chats.doc(chatId).get()).data() ?? const {};
    final code = chat['inviteCode'] as String?;
    final msgRef = _messages(chatId).doc();
    final notice = '$name ended the group';
    final batch =
        _db.batch()
          ..update(_chats.doc(chatId), {
            'closed': true,
            'closedAt': FieldValue.serverTimestamp(),
            // Gone from the owner's chat list right away.
            'clearedAt.$uid': FieldValue.serverTimestamp(),
            'deletedAt.$uid': FieldValue.serverTimestamp(),
            'inviteCode': FieldValue.delete(),
            'lastMessage': _lastMessage(msgRef.id, uid, MessageType.system, notice),
            'updatedAt': FieldValue.serverTimestamp(),
          })
          ..set(msgRef, _systemData(uid, notice));
    if (code != null) batch.delete(_invites.doc(code));
    await batch.commit();
  }

  /// A former member comes back (non-secret, not ended groups only).
  Future<void> rejoinGroup(String chatId, String uid, String name, {String? alias}) {
    final msgRef = _messages(chatId).doc();
    final notice = alias == null ? '$name rejoined' : '$alias joined anonymously';
    final batch =
        _db.batch()
          ..update(_chats.doc(chatId), {
            'participants': FieldValue.arrayUnion([uid]),
            'formerMembers': FieldValue.arrayRemove([uid]),
            'unread.$uid': 0,
            if (alias != null) 'anonymous.$uid': alias,
            if (alias == null) 'anonymous.$uid': FieldValue.delete(),
            'lastMessage': _lastMessage(msgRef.id, uid, MessageType.system, notice),
            'updatedAt': FieldValue.serverTimestamp(),
          })
          ..set(msgRef, _systemData(uid, notice));
    return batch.commit();
  }

  Future<void> setSecret(String chatId, bool secret) => _chats.doc(chatId).update({'secret': secret});

  Future<void> setAutoClear(String chatId, String uid, bool on) =>
      _chats.doc(chatId).update({'autoClear.$uid': on ? true : FieldValue.delete()});

  /// Admin decision on an anonymous member's media.
  Future<void> reviewMedia(String chatId, String messageId, String adminId, {required bool approve}) async {
    final ref = _messages(chatId).doc(messageId);
    await ref.update({'pendingApproval': false, 'approvedBy': adminId, if (!approve) 'rejected': true});
    if (!approve) return;
    // Now it counts as a normal message: preview + unread for everyone.
    final msg = MessageModel.fromDoc(chatId, await ref.get());
    final chat = (await _chats.doc(chatId).get()).data() ?? const {};
    final participants = List<String>.from(chat['participants'] as List<dynamic>? ?? const []);
    await _chats.doc(chatId).update({
      'lastMessage': _lastMessage(messageId, msg.senderId, msg.type, msg.preview),
      'updatedAt': FieldValue.serverTimestamp(),
      for (final p in participants)
        if (p != msg.senderId) 'unread.$p': FieldValue.increment(1),
    });
  }

  // ── Group invitations & anonymity ──────────────────────────────────────

  /// Groups that invited [uid] and are waiting for an answer.
  Stream<List<ChatModel>> watchInvitations(String uid) =>
      _chats.where('invited', arrayContains: uid).snapshots().map((s) => s.docs.map(ChatModel.fromDoc).toList());

  /// Accepts an invitation. [alias] non-null → joins anonymously.
  Future<void> acceptInvite(String chatId, String uid, String name, {String? alias}) {
    final msgRef = _messages(chatId).doc();
    final notice = alias == null ? '$name joined' : '$alias joined anonymously';
    final batch =
        _db.batch()
          ..update(_chats.doc(chatId), {
            'participants': FieldValue.arrayUnion([uid]),
            'invited': FieldValue.arrayRemove([uid]),
            'invitedBy.$uid': FieldValue.delete(),
            'unread.$uid': 0,
            if (alias != null) 'anonymous.$uid': alias,
            'lastMessage': _lastMessage(msgRef.id, uid, MessageType.system, notice),
            'updatedAt': FieldValue.serverTimestamp(),
          })
          ..set(msgRef, _systemData(uid, notice));
    return batch.commit();
  }

  Future<void> declineInvite(String chatId, String uid) => cancelInvite(chatId, uid);

  /// Shows the real name from now on; hiding again is blocked for 24 hours.
  Future<void> revealIdentity(String chatId, String uid, String name, String alias) {
    final msgRef = _messages(chatId).doc();
    final notice = '$alias is $name';
    final batch =
        _db.batch()
          ..update(_chats.doc(chatId), {
            'anonymous.$uid': FieldValue.delete(),
            'revealedAt.$uid': FieldValue.serverTimestamp(),
            'lastMessage': _lastMessage(msgRef.id, uid, MessageType.system, notice),
            'updatedAt': FieldValue.serverTimestamp(),
          })
          ..set(msgRef, _systemData(uid, notice));
    return batch.commit();
  }

  Future<void> hideIdentity(String chatId, String uid, String name, String alias) {
    final msgRef = _messages(chatId).doc();
    final notice = '$name is now anonymous';
    final batch =
        _db.batch()
          ..update(_chats.doc(chatId), {
            'anonymous.$uid': alias,
            'lastMessage': _lastMessage(msgRef.id, uid, MessageType.system, notice),
            'updatedAt': FieldValue.serverTimestamp(),
          })
          ..set(msgRef, _systemData(uid, notice));
    return batch.commit();
  }

  // ── Join links ─────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _invites => _db.collection(FirestorePaths.groupInvites);

  /// Creates (or replaces) the group's join link and returns its code.
  Future<String> createInviteLink(String chatId) async {
    final chat = (await _chats.doc(chatId).get()).data() ?? const {};
    final old = chat['inviteCode'] as String?;
    final code = IdUtils.randomCode(20);
    final batch =
        _db.batch()
          ..set(_invites.doc(code), {
            'chatId': chatId,
            'name': chat['name'] ?? 'Group',
            if (chat['photoUrl'] != null) 'photoUrl': chat['photoUrl'],
            'description': chat['description'] ?? '',
            'createdAt': FieldValue.serverTimestamp(),
          })
          ..update(_chats.doc(chatId), {'inviteCode': code});
    if (old != null) batch.delete(_invites.doc(old));
    await batch.commit();
    return code;
  }

  Future<void> revokeInviteLink(String chatId, String code) {
    final batch =
        _db.batch()
          ..delete(_invites.doc(code))
          ..update(_chats.doc(chatId), {'inviteCode': FieldValue.delete()});
    return batch.commit();
  }

  Future<GroupInvitePreview?> getInvite(String code) async {
    final d = await _invites.doc(code).get();
    final data = d.data();
    if (data == null) return null;
    return GroupInvitePreview(
      code: code,
      chatId: data['chatId'] as String,
      name: (data['name'] as String?) ?? 'Group',
      photoUrl: data['photoUrl'] as String?,
      description: (data['description'] as String?) ?? '',
    );
  }

  Future<void> joinWithLink(String chatId, String code, String uid, String name, {String? alias}) {
    final msgRef = _messages(chatId).doc();
    final notice = alias == null ? '$name joined using the invite link' : '$alias joined anonymously';
    final batch =
        _db.batch()
          ..update(_chats.doc(chatId), {
            'participants': FieldValue.arrayUnion([uid]),
            'invited': FieldValue.arrayRemove([uid]),
            'invitedBy.$uid': FieldValue.delete(),
            'unread.$uid': 0,
            'joinCode': code, // checked by the security rules against inviteCode
            if (alias != null) 'anonymous.$uid': alias,
            'lastMessage': _lastMessage(msgRef.id, uid, MessageType.system, notice),
            'updatedAt': FieldValue.serverTimestamp(),
          })
          ..set(msgRef, _systemData(uid, notice));
    return batch.commit();
  }

  // ── Pinned messages ────────────────────────────────────────────────────

  static const maxPinned = 3;

  Future<void> pinMessage(String chatId, MessageEntity m, String uid) => _db.runTransaction((tx) async {
    final ref = _chats.doc(chatId);
    final snap = await tx.get(ref);
    final current = List<Map<String, dynamic>>.from(
      ((snap.data()?['pinnedMessages'] as List<dynamic>?) ?? const []).whereType<Map<String, dynamic>>(),
    )..removeWhere((p) => p['messageId'] == m.id);
    final next =
        [
          {
            'messageId': m.id,
            'senderId': m.senderId,
            'type': m.type.name,
            'preview': m.preview,
            'pinnedBy': uid,
            'pinnedAt': Timestamp.now(),
          },
          ...current,
        ].take(maxPinned).toList();
    tx.update(ref, {'pinnedMessages': next});
  });

  Future<void> unpinMessage(String chatId, String messageId) => _db.runTransaction((tx) async {
    final ref = _chats.doc(chatId);
    final snap = await tx.get(ref);
    final next =
        ((snap.data()?['pinnedMessages'] as List<dynamic>?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .where((p) => p['messageId'] != messageId)
            .toList();
    tx.update(ref, {'pinnedMessages': next});
  });

  // ── Scheduled messages ─────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _scheduled(String uid) => _db.collection(FirestorePaths.scheduled(uid));

  Stream<List<ScheduledMessage>> watchScheduled(String uid) => _scheduled(uid)
      .orderBy('sendAt')
      .snapshots()
      .map(
        (s) => [
          for (final d in s.docs)
            ScheduledMessage(
              id: d.id,
              chatId: d.data()['chatId'] as String? ?? '',
              senderId: uid,
              text: d.data()['text'] as String? ?? '',
              sendAt: (d.data()['sendAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
              isGroup: d.data()['isGroup'] as bool? ?? false,
              participants: List<String>.from(d.data()['participants'] as List<dynamic>? ?? const []),
            ),
        ],
      );

  Future<void> scheduleMessage(ScheduledMessage m) => _scheduled(m.senderId).add({
    'chatId': m.chatId,
    'text': m.text,
    'sendAt': Timestamp.fromDate(m.sendAt),
    'isGroup': m.isGroup,
    'participants': m.participants,
    'createdAt': FieldValue.serverTimestamp(),
  });

  Future<void> deleteScheduled(String uid, String id) => _scheduled(uid).doc(id).delete();

  /// Sends a scheduled message exactly once: the scheduled doc is deleted in
  /// the same transaction that writes the message, so two devices (or the
  /// server) can never both send it.
  Future<void> dispatchScheduled(ScheduledMessage s) => _db.runTransaction((tx) async {
    final schedRef = _scheduled(s.senderId).doc(s.id);
    final sched = await tx.get(schedRef);
    if (!sched.exists) return;
    final chatRef = _chats.doc(s.chatId);
    final chat = await tx.get(chatRef);
    final participants =
        s.isGroup ? List<String>.from(chat.data()?['participants'] as List<dynamic>? ?? const []) : s.participants;
    tx.delete(schedRef);
    // Removed from the group since scheduling → just drop it.
    if (!participants.contains(s.senderId)) return;
    final out = OutgoingMessage(
      chatId: s.chatId,
      senderId: s.senderId,
      participants: participants,
      isGroup: s.isGroup,
      type: MessageType.text,
      text: s.text,
    );
    final msgRef = _messages(s.chatId).doc();
    tx.set(msgRef, _messageData(out, null));
    tx.set(chatRef, _chatBump(out, msgRef.id, participants), SetOptions(merge: true));
  });

  // ── Media, links & docs ────────────────────────────────────────────────

  /// Recent history used by the "Media, links and docs" screen.
  Future<List<MessageModel>> recentHistory(String chatId, {int limit = 1000}) async {
    final snap = await _messages(chatId).orderBy('createdAt', descending: true).limit(limit).get();
    return snap.docs.map((d) => MessageModel.fromDoc(chatId, d)).toList();
  }

  /// Whole history, oldest first, in pages of 500 (for "Export chat").
  Future<List<MessageModel>> fullHistory(String chatId) async {
    final out = <MessageModel>[];
    DocumentSnapshot<Map<String, dynamic>>? last;
    while (true) {
      var q = _messages(chatId).orderBy('createdAt').limit(500);
      if (last != null) q = q.startAfterDocument(last);
      final snap = await q.get();
      out.addAll(snap.docs.map((d) => MessageModel.fromDoc(chatId, d)));
      if (snap.docs.length < 500) break;
      last = snap.docs.last;
    }
    return out;
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  Map<String, dynamic> _systemData(String actorId, String text) => {
    'senderId': actorId,
    'type': MessageType.system.name,
    'text': text,
    'createdAt': FieldValue.serverTimestamp(),
    'clientCreatedAt': Timestamp.now(),
    'deliveredTo': <String>[],
    'readBy': <String>[],
  };

  Map<String, dynamic> _lastMessage(String id, String senderId, MessageType type, String preview) => {
    'id': id,
    'senderId': senderId,
    'type': type.name,
    'preview': preview,
    'createdAt': FieldValue.serverTimestamp(),
  };

  Future<void> _updateLastPreviewIfLatest(String chatId, String messageId, String preview) async {
    final chat = await _chats.doc(chatId).get();
    final last = chat.data()?['lastMessage'] as Map<String, dynamic>?;
    if (last?['id'] == messageId) {
      await _chats.doc(chatId).update({'lastMessage.preview': preview});
    }
  }

  static String _extension(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot < path.lastIndexOf('/')) return '';
    return path.substring(dot).toLowerCase();
  }

  static String? _contentType(MessageType type, String ext) => switch (type) {
    MessageType.image => 'image/${ext == '.png' ? 'png' : 'jpeg'}',
    MessageType.sticker =>
      'image/${ext == '.webp'
          ? 'webp'
          : ext == '.gif'
          ? 'gif'
          : 'png'}',
    MessageType.video => 'video/mp4',
    MessageType.audio => 'audio/mp4',
    _ => null,
  };
}
