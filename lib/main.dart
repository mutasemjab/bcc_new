import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'app/di.dart';
import 'core/l10n/l10n.dart';
import 'core/services/fresh_install_guard.dart';
import 'core/services/push_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Show the real error instead of a blank grey box (release builds too),
  // so problems can be reported and fixed.
  ErrorWidget.builder = (details) => _ErrorBox(details);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await FreshInstallGuard.run();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent, systemNavigationBarColor: Colors.transparent),
  );

  await initializeDateFormatting(); // Arabic + English date names
  await configureDependencies();
  sl<L10n>(); // apply the saved language before the first screen
  runApp(const BccChatApp());
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox(this.details);
  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    final stack = details.stack.toString().split('\n').take(8).join('\n');
    return Material(
      color: const Color(0xFFFFF3F3),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            'Something went wrong on this screen. Please send a screenshot of this:\n\n'
            '${details.exceptionAsString()}\n\n$stack',
            style: const TextStyle(color: Color(0xFFB00020), fontSize: 12.5),
          ),
        ),
      ),
    );
  }
}
