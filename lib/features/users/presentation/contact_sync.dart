import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/services/contacts_service.dart';
import '../domain/entities/user_entity.dart';
import '../domain/usecases/user_usecases.dart';

/// A phone contact who has an account, as cached on this device.
class SyncedContact {
  const SyncedContact({
    required this.uid,
    required this.phone,
    required this.contactName,
    required this.profileName,
    this.photoUrl,
    this.about = '',
  });

  final String uid;
  final String phone;

  /// Name as saved in the phone book.
  final String contactName;
  final String profileName;
  final String? photoUrl;
  final String about;

  UserEntity toUser() => UserEntity(id: uid, name: profileName, phone: phone, photoUrl: photoUrl, about: about);

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'phone': phone,
    'contactName': contactName,
    'profileName': profileName,
    if (photoUrl != null) 'photoUrl': photoUrl,
    'about': about,
  };

  static SyncedContact fromJson(Map<String, dynamic> j) => SyncedContact(
    uid: j['uid'] as String,
    phone: j['phone'] as String,
    contactName: j['contactName'] as String? ?? '',
    profileName: j['profileName'] as String? ?? '',
    photoUrl: j['photoUrl'] as String?,
    about: j['about'] as String? ?? '',
  );

  SyncedContact withContactName(String name) => SyncedContact(
    uid: uid,
    phone: phone,
    contactName: name,
    profileName: profileName,
    photoUrl: photoUrl,
    about: about,
  );
}

/// WhatsApp-style contact discovery.
///
/// * Results are **cached on the device**, so "New chat" opens instantly.
/// * Syncing runs **in the background** (app start, phone book changes).
/// * After the first sync only **new numbers** are looked up; a full
///   re-check runs at most once a day to catch people who joined since.
/// * Lookups run a few at a time, 30 numbers per query, so even 10,000
///   contacts cost a few hundred tiny queries once — not on every open.
class ContactSync extends ChangeNotifier with WidgetsBindingObserver {
  ContactSync(this._contacts, this._find);
  final ContactsService _contacts;
  final FindUsersByPhones _find;

  static const _fullRefreshEvery = Duration(hours: 24);
  static const _resumeRefreshEvery = Duration(minutes: 15);

  String? _uid;
  String? _myPhone;
  List<SyncedContact> _matches = const [];
  Set<String> _checked = {};
  DateTime? _lastFull;
  DateTime? _lastSync;
  bool _loaded = false;
  bool _syncing = false;
  bool _hasAccess = false;
  bool _rerun = false;
  String? _error;
  StreamSubscription<void>? _changes;
  Timer? _debounce;

  /// Contacts with an account, sorted by phone-book name.
  List<SyncedContact> get matches => _matches;
  bool get syncing => _syncing;
  bool get hasAccess => _hasAccess;
  bool get loaded => _loaded;
  String? get error => _error;
  DateTime? get lastSync => _lastSync;

  // ── Session lifecycle ──

  Future<void> start(String uid, {String? myPhone}) async {
    if (_uid == uid) return;
    stop();
    _uid = uid;
    _myPhone = myPhone;
    WidgetsBinding.instance.addObserver(this);
    await _loadCache();
    _hasAccess = await _contacts.checkAccess() == ContactsAccess.granted;
    notifyListeners();
    if (_hasAccess) {
      _listenForChanges();
      // Let the app finish starting before touching the phone book.
      Timer(const Duration(seconds: 3), () => sync());
    }
  }

  void stop() {
    WidgetsBinding.instance.removeObserver(this);
    _changes?.cancel();
    _changes = null;
    _debounce?.cancel();
    _uid = null;
    _matches = const [];
    _checked = {};
    _lastFull = null;
    _lastSync = null;
    _loaded = false;
    _error = null;
    _askedThisSession = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !_hasAccess) return;
    final last = _lastSync;
    if (last == null || DateTime.now().difference(last) > _resumeRefreshEvery) sync();
  }

  void _listenForChanges() {
    _changes ??= _contacts.onChanged.listen((_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(seconds: 4), () => sync());
    }, onError: (_) {});
  }

  bool _askedThisSession = false;

  /// Called when "New chat" opens: asks for contacts permission once per
  /// session (like WhatsApp) if it hasn't been granted yet.
  Future<void> askOnceIfNeeded() async {
    if (_hasAccess || _askedThisSession || _uid == null) return;
    _askedThisSession = true;
    await requestAccessAndSync();
  }

  /// Asks for permission (from the UI), then syncs.
  Future<bool> requestAccessAndSync() async {
    _hasAccess = await _contacts.requestAccess() == ContactsAccess.granted;
    notifyListeners();
    if (_hasAccess) {
      _listenForChanges();
      await sync();
    }
    return _hasAccess;
  }

  // ── Sync ──

  /// [full] re-checks every number (otherwise only numbers never checked).
  Future<void> sync({bool full = false}) async {
    final uid = _uid;
    if (uid == null || !_hasAccess) return;
    if (_syncing) {
      _rerun = true;
      return;
    }
    _syncing = true;
    _error = null;
    notifyListeners();
    try {
      final cc = PhoneNumbers.countryCodeOf(_myPhone);
      final book = await _contacts.readContacts(defaultCountryCode: cc);
      final mine = _myPhone == null ? null : PhoneNumbers.normalize(_myPhone!, cc);

      // phone → name in the phone book (first contact wins).
      final nameByPhone = <String, String>{};
      for (final c in book) {
        for (final p in c.phones) {
          if (p != mine) nameByPhone.putIfAbsent(p, () => c.name);
        }
      }

      final doFull = full || _lastFull == null || DateTime.now().difference(_lastFull!) > _fullRefreshEvery;
      final toQuery =
          doFull ? nameByPhone.keys.toList() : nameByPhone.keys.where((p) => !_checked.contains(p)).toList();

      final found = <String, SyncedContact>{};
      if (toQuery.isNotEmpty) {
        final r = await _find((phones: toQuery, currentUid: uid));
        final users = r.fold((f) => throw f, (u) => u);
        for (final u in users) {
          final phone = u.phone;
          if (phone == null) continue;
          found[u.id] = SyncedContact(
            uid: u.id,
            phone: phone,
            contactName: nameByPhone[phone] ?? u.name,
            profileName: u.name,
            photoUrl: u.photoUrl,
            about: u.about,
          );
        }
      }

      // Merge: keep earlier matches that are still in the phone book (and
      // weren't re-checked), refresh their phone-book names, add new ones.
      final queried = toQuery.toSet();
      final merged = <String, SyncedContact>{
        for (final m in _matches)
          if (nameByPhone.containsKey(m.phone) && !queried.contains(m.phone))
            m.uid: m.withContactName(nameByPhone[m.phone]!),
        ...found,
      };
      _matches =
          merged.values.toList()..sort((a, b) => a.contactName.toLowerCase().compareTo(b.contactName.toLowerCase()));
      _checked = doFull ? nameByPhone.keys.toSet() : {..._checked.where(nameByPhone.containsKey), ...queried};
      if (doFull) _lastFull = DateTime.now();
      _lastSync = DateTime.now();
      await _saveCache();
    } catch (e) {
      _error = 'Could not sync your contacts. Check your connection.';
    } finally {
      _syncing = false;
      notifyListeners();
    }
    if (_rerun) {
      _rerun = false;
      unawaited(sync());
    }
  }

  // ── Device cache ──

  Future<File> _cacheFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/contact_sync_${_uid ?? 'anon'}.json');
  }

  Future<void> _loadCache() async {
    try {
      final f = await _cacheFile();
      if (await f.exists()) {
        final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        _matches = [
          for (final m in (j['matches'] as List<dynamic>? ?? const []))
            SyncedContact.fromJson(m as Map<String, dynamic>),
        ];
        _checked = {...(j['checked'] as List<dynamic>? ?? const []).cast<String>()};
        _lastFull = DateTime.tryParse(j['lastFull'] as String? ?? '');
        _lastSync = DateTime.tryParse(j['lastSync'] as String? ?? '');
      }
    } catch (_) {
      // Corrupt cache → start fresh.
    }
    _loaded = true;
  }

  Future<void> _saveCache() async {
    try {
      final f = await _cacheFile();
      await f.writeAsString(
        jsonEncode({
          'matches': [for (final m in _matches) m.toJson()],
          'checked': _checked.toList(),
          'lastFull': _lastFull?.toIso8601String(),
          'lastSync': _lastSync?.toIso8601String(),
        }),
      );
    } catch (_) {}
  }
}
