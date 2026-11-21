import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Makes a reinstall start completely clean.
///
/// iOS keeps the sign-in session in the Keychain, which survives deleting the
/// app, so a reinstalled app would come back already logged in. App
/// preferences, on the other hand, are wiped on uninstall — so "no install
/// marker" means this is the first launch of a fresh install: sign out and
/// drop any local cache. (Android backups are disabled in the manifest.)
abstract final class FreshInstallGuard {
  static const _marker = 'install.marker.v1';

  /// Must run after Firebase.initializeApp and before Firestore is used.
  static Future<void> run() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_marker) == true) return;
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    try {
      await FirebaseFirestore.instance.clearPersistence();
    } catch (_) {}
    await prefs.clear();
    await prefs.setBool(_marker, true);
  }
}
