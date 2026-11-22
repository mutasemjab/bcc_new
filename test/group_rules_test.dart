import 'package:bcc_chat/features/chat/domain/entities/chat_entity.dart';
import 'package:bcc_chat/features/chat/domain/entities/message_entity.dart';
import 'package:bcc_chat/features/chat/domain/usecases/chat_extras.dart';
import 'package:bcc_chat/features/chat/presentation/widgets/message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('group lifecycle', () {
    const base = ChatEntity(
      id: 'g',
      isGroup: true,
      participants: ['owner', 'a'],
      admins: ['owner'],
      createdBy: 'owner',
      formerMembers: ['left'],
    );

    test('a member who left can rejoin a normal group', () => expect(base.canRejoin('left'), isTrue));

    test('no rejoin in a secret or ended group', () {
      const secret = ChatEntity(id: 'g', isGroup: true, participants: ['owner'], secret: true, formerMembers: ['left']);
      const ended = ChatEntity(id: 'g', isGroup: true, participants: ['owner'], closed: true, formerMembers: ['left']);
      expect(secret.canRejoin('left'), isFalse);
      expect(ended.canRejoin('left'), isFalse);
    });

    test('only admins share links in a secret group', () {
      const secret = ChatEntity(id: 'g', isGroup: true, participants: ['owner', 'a'], admins: ['owner'], secret: true);
      expect(secret.canShareLink('owner'), isTrue);
      expect(secret.canShareLink('a'), isFalse);
      expect(base.canShareLink('a'), isTrue);
    });

    test('owner is recognised', () {
      expect(base.isOwner('owner'), isTrue);
      expect(base.isOwner('a'), isFalse);
    });
  });

  test('anonymous media types needing approval', () {
    expect(MessageEntity.approvalTypes, containsAll([MessageType.image, MessageType.video, MessageType.file]));
    expect(MessageEntity.approvalTypes.contains(MessageType.text), isFalse);
  });

  group('text formatting', () {
    String plain(List<InlineSpan> spans) => spans.map((s) => (s as TextSpan).text).join();
    TextStyle? styleOf(List<InlineSpan> spans, String text) =>
        spans.cast<TextSpan>().firstWhere((s) => s.text == text).style;

    test('bold / italic / strike / mono', () {
      final spans = formattedSpans('hi *bold* _it_ ~gone~ ```code```');
      expect(plain(spans), 'hi bold it gone code');
      expect(styleOf(spans, 'bold')?.fontWeight, FontWeight.w800);
      expect(styleOf(spans, 'it')?.fontStyle, FontStyle.italic);
      expect(styleOf(spans, 'gone')?.decoration, TextDecoration.lineThrough);
      expect(styleOf(spans, 'code')?.fontFamily, 'monospace');
    });

    test('markers inside words are left alone', () {
      expect(plain(formattedSpans('snake_case_name 2*3*4')), 'snake_case_name 2*3*4');
    });
  });

  group('email invitations', () {
    test('parses any pasted list, de-duplicated and lower-case', () {
      final emails = GroupMembership.parseEmails(
        'Ali@Mail.com, sara@x.io\nbad@ ; ali@mail.com other text ahmad.k+1@site.co',
      );
      expect(emails, ['ali@mail.com', 'sara@x.io', 'ahmad.k+1@site.co']);
    });

    test('pending count includes email-only invitations', () {
      const chat = ChatEntity(
        id: 'g',
        isGroup: true,
        participants: ['a'],
        invited: ['b'],
        invitedEmails: ['c@x.io', 'd@x.io'],
      );
      expect(chat.pendingInviteCount, 3);
    });
  });

  test('a group I left never shows unread', () {
    const chat = ChatEntity(
      id: 'g',
      isGroup: true,
      participants: ['a'],
      unread: {'me': 5, 'a': 2},
      formerMembers: ['me'],
    );
    expect(chat.unreadFor('me'), 0);
    expect(chat.unreadFor('a'), 2);
  });
}
