import 'package:bcc_chat/features/chat/domain/entities/chat_entity.dart';
import 'package:bcc_chat/features/chat/domain/entities/message_entity.dart';
import 'package:bcc_chat/features/chat/presentation/bloc/chat_list/chat_list_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

ChatEntity _chat(String id, {int unread = 0, bool muted = false, DateTime? lastAt, Map<String, DateTime>? deletedAt}) =>
    ChatEntity(
      id: id,
      isGroup: true,
      participants: const ['me', 'x'],
      unread: {'me': unread},
      mutedBy: muted ? const ['me'] : const [],
      lastMessage: LastMessage(id: 'l$id', senderId: 'x', type: MessageType.text, preview: 'hi', createdAt: lastAt),
      deletedAt: deletedAt ?? const {},
    );

void main() {
  final t0 = DateTime(2026, 11, 20, 10);

  group('clear / delete chat (per user)', () {
    test('deleted chat stays hidden until a newer message arrives', () {
      final hidden = _chat('a', lastAt: t0, deletedAt: {'me': t0.add(const Duration(minutes: 1))});
      expect(hidden.isDeletedFor('me'), isTrue);
      expect(hidden.isDeletedFor('x'), isFalse);

      final back = _chat('a', lastAt: t0.add(const Duration(hours: 1)), deletedAt: {'me': t0});
      expect(back.isDeletedFor('me'), isFalse);
    });

    test('cleared chat hides the old preview', () {
      final c = ChatEntity(
        id: 'c',
        isGroup: false,
        participants: const ['me', 'x'],
        lastMessage: LastMessage(id: 'l', senderId: 'x', type: MessageType.text, preview: 'old', createdAt: t0),
        clearedAt: {'me': t0.add(const Duration(seconds: 1))},
      );
      expect(c.isClearedFor('me'), isTrue);
      expect(c.isClearedFor('x'), isFalse);
    });
  });

  test('tab badge counts unread chats (not messages), skipping muted ones', () {
    final state = ChatListState(
      uid: 'me',
      chats: [
        _chat('a', unread: 7, lastAt: t0),
        _chat('b', unread: 2, lastAt: t0),
        _chat('c', unread: 5, muted: true, lastAt: t0),
        _chat('d', lastAt: t0),
      ],
    );
    expect(state.totalUnread, 2);
  });

  group('view once & forwarded', () {
    test('view-once preview never reveals content', () {
      const photo = MessageEntity(
        id: '1',
        chatId: 'c',
        senderId: 'x',
        type: MessageType.image,
        text: 'secret',
        viewOnce: true,
      );
      const voice = MessageEntity(id: '2', chatId: 'c', senderId: 'x', type: MessageType.audio, viewOnce: true);
      expect(photo.preview, '① Photo');
      expect(voice.preview, '① Voice message');
    });

    test('opened state is per user', () {
      const m = MessageEntity(
        id: '1',
        chatId: 'c',
        senderId: 'x',
        type: MessageType.image,
        viewOnce: true,
        openedBy: ['me'],
      );
      expect(m.openedByUser('me'), isTrue);
      expect(m.openedByUser('y'), isFalse);
    });

    test('forward labels', () {
      const once = MessageEntity(id: '1', chatId: 'c', senderId: 'x', type: MessageType.text, forwardCount: 1);
      const many = MessageEntity(id: '2', chatId: 'c', senderId: 'x', type: MessageType.text, forwardCount: 5);
      expect(once.isForwarded && !once.isFrequentlyForwarded, isTrue);
      expect(many.isFrequentlyForwarded, isTrue);
    });
  });
}
