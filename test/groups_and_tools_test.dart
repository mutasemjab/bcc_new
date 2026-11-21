import 'package:bcc_chat/core/services/wallpaper_store.dart';
import 'package:bcc_chat/core/utils/id_utils.dart';
import 'package:bcc_chat/features/chat/domain/entities/chat_entity.dart';
import 'package:bcc_chat/features/chat/domain/entities/group_invite.dart';
import 'package:bcc_chat/features/chat/domain/entities/scheduled_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('anonymous identity cooldown', () {
    final now = DateTime(2026, 11, 20, 12);

    test('never revealed → can hide now', () {
      const chat = ChatEntity(id: 'g', isGroup: true, participants: ['a']);
      expect(chat.canHideAgainAt('a', now: now), isNull);
    });

    test('revealed 3h ago → must wait until 24h after reveal', () {
      final revealed = now.subtract(const Duration(hours: 3));
      final chat = ChatEntity(id: 'g', isGroup: true, participants: const ['a'], revealedAt: {'a': revealed});
      expect(chat.canHideAgainAt('a', now: now), revealed.add(const Duration(hours: 24)));
    });

    test('revealed 25h ago → can hide again', () {
      final chat = ChatEntity(
        id: 'g',
        isGroup: true,
        participants: const ['a'],
        revealedAt: {'a': now.subtract(const Duration(hours: 25))},
      );
      expect(chat.canHideAgainAt('a', now: now), isNull);
    });

    test('alias lookup', () {
      const chat = ChatEntity(id: 'g', isGroup: true, participants: ['a', 'b'], anonymous: {'b': 'Member #1234'});
      expect(chat.isAnonymous('b'), isTrue);
      expect(chat.aliasOf('b'), 'Member #1234');
      expect(chat.aliasOf('a'), isNull);
    });
  });

  group('group links', () {
    test('round-trip', () {
      final link = GroupLinks.build('abc123', 'XyZ789');
      expect(link, 'https://${GroupLinks.host}/join/abc123/XyZ789');
      expect(GroupLinks.parse('Join my group: $link'), ('abc123', 'XyZ789'));
    });
    test('rejects other text', () => expect(GroupLinks.parse('https://example.com/hello'), isNull));
    test('codes are long, random and link-safe', () {
      final a = IdUtils.randomCode(20), b = IdUtils.randomCode(20);
      expect(a.length, 20);
      expect(a, isNot(b));
      expect(RegExp(r'^[A-Za-z0-9]+$').hasMatch(a), isTrue);
    });
    test('anonymous alias format', () => expect(IdUtils.anonymousAlias(), matches(RegExp(r'^Member #\d{4}$'))));
  });

  test('wallpaper encode/decode', () {
    expect(Wallpaper.decode(null).kind, WallpaperKind.pattern);
    const c = Wallpaper.color(Color(0xFF3A9AD9));
    expect(Wallpaper.decode(c.encode()), c);
    // A photo that no longer exists falls back to the default pattern.
    expect(Wallpaper.decode('image:/nope/missing.jpg').kind, WallpaperKind.pattern);
  });

  test('scheduled message is due at or after its time', () {
    final at = DateTime(2026, 11, 20, 9);
    final m = ScheduledMessage(
      id: 's',
      chatId: 'c',
      senderId: 'u',
      text: 'hi',
      sendAt: at,
      isGroup: false,
      participants: const ['u', 'v'],
    );
    expect(m.isDue(at.subtract(const Duration(seconds: 1))), isFalse);
    expect(m.isDue(at), isTrue);
    expect(m.isDue(at.add(const Duration(minutes: 5))), isTrue);
  });
}
