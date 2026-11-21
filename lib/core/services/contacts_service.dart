import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:permission_handler/permission_handler.dart' as ph;

/// A phone-book entry reduced to what we need for matching.
class PhoneContact {
  const PhoneContact({required this.name, required this.phones});
  final String name;

  /// Numbers in international format (+9627…).
  final Set<String> phones;
}

enum ContactsAccess { granted, denied }

/// Reads the device address book (read-only) so the app can show which
/// contacts already use it — the same idea as WhatsApp.
class ContactsService {
  /// Current permission without showing any dialog (for background sync).
  Future<ContactsAccess> checkAccess() async {
    try {
      final status = await ph.Permission.contacts.status;
      return status.isGranted || status.isLimited ? ContactsAccess.granted : ContactsAccess.denied;
    } catch (_) {
      return ContactsAccess.denied;
    }
  }

  /// Fires when the phone book changes (contact added, edited, removed).
  Stream<void> get onChanged => fc.FlutterContacts.onDatabaseChange;

  /// Shows the system permission dialog. If Android blocked it permanently
  /// ("Don't ask again"), opens the app's settings page instead.
  Future<ContactsAccess> requestAccess() async {
    var status = await ph.Permission.contacts.status;
    if (status.isGranted || status.isLimited) return ContactsAccess.granted;
    status = await ph.Permission.contacts.request();
    if (status.isGranted || status.isLimited) return ContactsAccess.granted;
    if (status.isPermanentlyDenied || status.isRestricted) await ph.openAppSettings();
    return ContactsAccess.denied;
  }

  /// [defaultCountryCode] (e.g. "+962") is used for local numbers like 079…
  Future<List<PhoneContact>> readContacts({required String defaultCountryCode}) async {
    final contacts = await fc.FlutterContacts.getAll(properties: {fc.ContactProperty.phone});
    final result = <PhoneContact>[];
    for (final c in contacts) {
      final phones = <String>{
        for (final p in c.phones)
          if (PhoneNumbers.normalize(p.normalizedNumber ?? p.number, defaultCountryCode) case final n?) n,
      };
      if (phones.isEmpty) continue;
      final name = (c.displayName ?? '').trim();
      result.add(PhoneContact(name: name.isEmpty ? phones.first : name, phones: phones));
    }
    return result;
  }
}

abstract final class PhoneNumbers {
  static const fallbackCountryCode = '+962';

  /// Converts any written form to international format, or null if it
  /// doesn't look like a phone number.
  ///   "079 123 4567" → "+962791234567"   (with +962 as default)
  ///   "00962791234567" → "+962791234567"
  static String? normalize(String raw, String defaultCountryCode) {
    var s = raw.replaceAll(RegExp(r'[^\d+]'), '');
    if (s.isEmpty) return null;
    if (s.startsWith('00')) s = '+${s.substring(2)}';
    if (!s.startsWith('+')) {
      if (s.startsWith('0')) {
        s = '$defaultCountryCode${s.substring(1)}';
      } else if (s.length >= 11) {
        s = '+$s'; // already includes a country code, just missing "+"
      } else {
        s = '$defaultCountryCode$s';
      }
    }
    final digits = s.length - 1;
    if (digits < 8 || digits > 15) return null;
    return s;
  }

  /// Best guess of the user's country code from their own number.
  static String countryCodeOf(String? myPhone) {
    if (myPhone == null || !myPhone.startsWith('+')) return fallbackCountryCode;
    const known = [
      '+962',
      '+966',
      '+971',
      '+970',
      '+972',
      '+965',
      '+974',
      '+973',
      '+968',
      '+964',
      '+963',
      '+961',
      '+20',
      '+1',
      '+44',
      '+49',
      '+90',
    ];
    for (final cc in known) {
      if (myPhone.startsWith(cc)) return cc;
    }
    return fallbackCountryCode;
  }
}
