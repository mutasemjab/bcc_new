import 'package:bcc_chat/core/services/contacts_service.dart';
import 'package:bcc_chat/core/usecase/usecase.dart';
import 'package:bcc_chat/features/users/domain/entities/user_entity.dart';
import 'package:bcc_chat/features/users/domain/repositories/user_repository.dart';
import 'package:bcc_chat/features/users/domain/usecases/user_usecases.dart';
import 'package:bcc_chat/features/users/presentation/contact_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class _Repo extends Mock implements UserRepository {}

class _FakeContacts extends ContactsService {
  List<PhoneContact> book = [];
  @override
  Future<ContactsAccess> checkAccess() async => ContactsAccess.granted;
  @override
  Future<List<PhoneContact>> readContacts({required String defaultCountryCode}) async => book;
  @override
  Stream<void> get onChanged => const Stream.empty();
}

/// Registered users by phone; records every lookup so we can count them.
class _FakeFind extends FindUsersByPhones {
  _FakeFind(this.registered) : super(_Repo());
  final Map<String, UserEntity> registered;
  final lookups = <List<String>>[];

  @override
  ResultFuture<List<UserEntity>> call(({List<String> phones, String currentUid}) p) async {
    lookups.add(p.phones);
    return Right([
      for (final ph in p.phones)
        if (registered[ph] != null) registered[ph]!,
    ]);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('first sync checks everything, later syncs only new numbers', () async {
    final contacts =
        _FakeContacts()
          ..book = [
            for (var i = 0; i < 5000; i++) PhoneContact(name: 'Person $i', phones: {'+96279${(1000000 + i)}'}),
          ];
    final find = _FakeFind({
      '+962791000007': const UserEntity(id: 'u7', name: 'Seven', phone: '+962791000007'),
      '+962791000042': const UserEntity(id: 'u42', name: 'Forty-two', phone: '+962791000042'),
    });
    final sync = ContactSync(contacts, find);
    await sync.start('me', myPhone: '+962790000000');
    await sync.sync();

    expect(find.lookups.single.length, 5000);
    expect(sync.matches.map((m) => m.contactName), ['Person 42', 'Person 7']);

    // Nothing changed → no network at all.
    await sync.sync();
    expect(find.lookups.length, 1);

    // One new contact → only that number is looked up.
    contacts.book = [
      ...contacts.book,
      const PhoneContact(name: 'New friend', phones: {'+962799999999'}),
    ];
    find.registered['+962799999999'] = const UserEntity(id: 'nf', name: 'NF', phone: '+962799999999');
    await sync.sync();
    expect(find.lookups.last, ['+962799999999']);
    expect(sync.matches.any((m) => m.uid == 'nf'), isTrue);

    // Renamed + removed contacts are reflected without re-querying.
    contacts.book = [
      for (final c in contacts.book)
        if (c.name != 'Person 7') c.name == 'Person 42' ? PhoneContact(name: 'Ahmad', phones: c.phones) : c,
    ];
    await sync.sync();
    expect(find.lookups.length, 2);
    expect(sync.matches.map((m) => m.contactName).toSet(), {'Ahmad', 'New friend'});

    // A forced full refresh re-checks everything (catches people who joined).
    await sync.sync(full: true);
    expect(find.lookups.length, 3);
    expect(find.lookups.last.length, 5000);
    sync.stop();
  });
}
