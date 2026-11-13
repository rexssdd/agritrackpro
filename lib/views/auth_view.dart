import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../widgets/common.dart';

class AuthView extends StatefulWidget {
  const AuthView({super.key});
  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView> {
  final email = TextEditingController(), password = TextEditingController();
  bool busy = false;
  Future<void> login() async {
    setState(() => busy = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email.text.trim(), password: password.text);
    } catch (e) {
      if (mounted) errorMessage(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      body: SafeArea(
          child: Center(
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.agriculture_rounded,
                                size: 76, color: Color(0xFF166534)),
                            const SizedBox(height: 12),
                            Text('AgriTrack Pro',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(fontWeight: FontWeight.bold)),
                            const Text('Agri Supply • Store Management'),
                            const SizedBox(height: 36),
                            TextField(
                                controller: email,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                    labelText: 'Staff email')),
                            const SizedBox(height: 14),
                            TextField(
                                controller: password,
                                obscureText: true,
                                decoration: const InputDecoration(
                                    labelText: 'Password')),
                            const SizedBox(height: 22),
                            SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                    onPressed: busy ? null : login,
                                    icon: const Icon(Icons.login),
                                    label: Text(
                                        busy ? 'Signing in…' : 'Sign in'))),
                            const SizedBox(height: 12),
                            const Text(
                                'Accounts are created by the store administrator.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.black54))
                          ]))))));
}
