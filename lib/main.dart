import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'config/theme.dart';
import 'auth/auth_view.dart';
import 'views/shell_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const AgriApp());
}

class AgriApp extends StatelessWidget {
  const AgriApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
      title: 'AgriTrack Pro',
      debugShowCheckedModeBanner: false,
      theme: AgriTheme.light,
      home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, s) {
            if (s.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                  body: Center(child: CircularProgressIndicator()));
            }
            return s.data == null ? const AuthView() : const ShellView();
          }));
}
