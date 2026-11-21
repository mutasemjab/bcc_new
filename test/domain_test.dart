import 'package:bcc_chat/core/error/failures.dart';
import 'package:bcc_chat/core/utils/id_utils.dart';
import 'package:bcc_chat/features/chat/domain/entities/message_entity.dart';
import 'package:bcc_chat/features/chat/domain/entities/outgoing_message.dart';
import 'package:bcc_chat/features/chat/domain/repositories/chat_repository.dart';
import 'package:bcc_chat/features/chat/domain/usecases/message_usecases.dart';
import 'package:bcc_chat/features/status/domain/entities/status_entity.dart';
import 'package:bcc_chat/features/status/domain/repositories/status_repository.dart';
import 'package:bcc_chat/features/status/domain/usecases/status_usecases.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class _MockChatRepo extends Mock implements ChatRepository {}

class _MockStatusRepo extends Mock implements StatusRepository {}

MessageEntity _msg({List<String> delivered = const [], List<String> read = const [], bool pending = false}) =>
    MessageEntity(
      id: 'm1',
      chatId: 'c1',
      senderId: 'me',
      type: MessageType.text,
      text: 'hi',
      deliveredTo: delivered,
      readBy: read,
      isPending: pending,
    );

void main() {
  group('IdUtils', () {
    test('direct chat id is order independent', () {
      expect(IdUtils.directChatId('b', 'a'), IdUtils.directChatId('a', 'b'));
      expect(IdUtils.peerFromChatId('a_b', 'a'), 'b');
      expect(IdUtils.peerFromChatId('groupId123', 'a'), isNull);
    });

    test('agora uid is stable, positive and 31-bit', () {
      final uid = IdUtils.agoraUid('XyZ123firebaseUid');
      expect(uid, IdUtils.agoraUid('XyZ123firebaseUid'));
      expect(uid, greaterThan(0));
      expect(uid, lessThanOrEqualTo(0x7FFFFFFF));
    });
  });

  group('MessageEntity.statusFor', () {
    const participants = ['me', 'a', 'b'];

    test('pending → clock', () => expect(_msg(pending: true).statusFor(participants), DeliveryStatus.pending));
    test('nobody received → sent', () => expect(_msg().statusFor(participants), DeliveryStatus.sent));
    test(
      'partially delivered → still sent',
      () => expect(_msg(delivered: ['a']).statusFor(participants), DeliveryStatus.sent),
    );
    test(
      'all delivered → delivered',
      () => expect(_msg(delivered: ['a', 'b']).statusFor(participants), DeliveryStatus.delivered),
    );
    test(
      'read implies delivered',
      () => expect(_msg(delivered: ['a'], read: ['b']).statusFor(participants), DeliveryStatus.delivered),
    );
    test('all read → read', () => expect(_msg(read: ['a', 'b']).statusFor(participants), DeliveryStatus.read));
  });

  group('SendMessage', () {
    late _MockChatRepo repo;
    setUpAll(
      () => registerFallbackValue(
        const OutgoingMessage(chatId: '', senderId: '', participants: [], isGroup: false, type: MessageType.text),
      ),
    );
    setUp(() => repo = _MockChatRepo());

    test('rejects blank text without touching the repository', () async {
      final result = await SendMessage(repo)(
        const SendMessageParams(
          OutgoingMessage(
            chatId: 'c',
            senderId: 'me',
            participants: ['me', 'a'],
            isGroup: false,
            type: MessageType.text,
            text: '   ',
          ),
        ),
      );
      expect(result.isLeft(), isTrue);
      expect(result.getLeft().toNullable(), isA<ValidationFailure>());
      verifyNever(() => repo.sendMessage(any(), onProgress: any(named: 'onProgress')));
    });

    test('forwards valid text', () async {
      when(
        () => repo.sendMessage(any(), onProgress: any(named: 'onProgress')),
      ).thenAnswer((_) async => const Right(null));
      final result = await SendMessage(repo)(
        const SendMessageParams(
          OutgoingMessage(
            chatId: 'c',
            senderId: 'me',
            participants: ['me', 'a'],
            isGroup: false,
            type: MessageType.text,
            text: 'hello',
          ),
        ),
      );
      expect(result.isRight(), isTrue);
    });
  });

  group('WatchStatusFeed', () {
    test('me first, then unseen newest-first, then seen; expired dropped', () async {
      registerFallbackValue(<String>{});
      final repo = _MockStatusRepo();
      final now = DateTime.now();
      StatusEntity s(String id, String user, int minutesAgo, {List<String> viewers = const [], bool expired = false}) =>
          StatusEntity(
            id: id,
            userId: user,
            type: StatusType.text,
            createdAt: now.subtract(Duration(minutes: minutesAgo)),
            expiresAt: expired ? now.subtract(const Duration(minutes: 1)) : now.add(const Duration(hours: 1)),
            viewers: viewers,
          );
      when(() => repo.watchStatuses(any())).thenAnswer(
        (_) => Stream.value([
          s('1', 'seenUser', 1, viewers: ['me']),
          s('2', 'oldUnseen', 50),
          s('3', 'me', 30),
          s('4', 'newUnseen', 5),
          s('5', 'ghost', 2, expired: true),
        ]),
      );

      final feed =
          await WatchStatusFeed(repo)((me: 'me', contacts: {'seenUser', 'oldUnseen', 'newUnseen', 'ghost'})).first;
      expect(feed.map((g) => g.userId), ['me', 'newUnseen', 'oldUnseen', 'seenUser']);
    });
  });
}
