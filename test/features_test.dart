import 'package:bcc_chat/core/services/contacts_service.dart';
import 'package:bcc_chat/features/chat/domain/entities/message_entity.dart';
import 'package:bcc_chat/features/chat/presentation/widgets/stickers/sticker_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PhoneNumbers.normalize', () {
    const jo = '+962';
    test('local number gets the default country code', () {
      expect(PhoneNumbers.normalize('079 123 4567', jo), '+962791234567');
      expect(PhoneNumbers.normalize('(079) 123-4567', jo), '+962791234567');
    });
    test('00 prefix becomes +', () => expect(PhoneNumbers.normalize('00962791234567', jo), '+962791234567'));
    test(
      'already international stays the same',
      () => expect(PhoneNumbers.normalize('+962 79 123 4567', jo), '+962791234567'),
    );
    test('country code without + is kept', () => expect(PhoneNumbers.normalize('962791234567', jo), '+962791234567'));
    test('short codes are rejected', () => expect(PhoneNumbers.normalize('911', jo), isNull));
    test('country code is taken from my number', () {
      expect(PhoneNumbers.countryCodeOf('+966501234567'), '+966');
      expect(PhoneNumbers.countryCodeOf(null), '+962');
    });
  });

  test('poll counts tally every voter and option', () {
    const m = MessageEntity(
      id: 'm',
      chatId: 'c',
      senderId: 'a',
      type: MessageType.poll,
      poll: PollData(
        question: 'Lunch?',
        allowMultiple: true,
        options: [PollOption(id: 'o0', text: 'Pizza'), PollOption(id: 'o1', text: 'Burger')],
      ),
      pollVotes: {
        'a': ['o0'],
        'b': ['o0', 'o1'],
      },
    );
    expect(m.pollCounts, {'o0': 2, 'o1': 1});
    expect(m.preview, '📊 Lunch?');
  });

  test('every built-in sticker id is unique and resolvable', () {
    final ids = [for (final p in StickerCatalog.packs) ...p.stickers.map((s) => s.id)];
    expect(ids.toSet().length, ids.length);
    for (final id in ids) {
      expect(StickerCatalog.byId(id), isNotNull);
    }
  });
}
