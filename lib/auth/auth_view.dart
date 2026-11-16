import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../views/customer/guest_catalog_view.dart';

class AuthView extends StatefulWidget {
  const AuthView({super.key, this.auth});
  final FirebaseAuth? auth;
  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView> {
  final email = TextEditingController(), password = TextEditingController();
  bool busy = false;
  bool hidePassword = true;
  bool registering = false;
  final confirmPassword = TextEditingController();
  static Future<void>? googleInitialization;
  String? signInError;
  String? statusMessage;
  Timer? slowRequestTimer;
  FirebaseAuth get auth => widget.auth ?? FirebaseAuth.instance;

  void beginRequest() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      busy = true;
      signInError = null;
      statusMessage = null;
    });
    slowRequestTimer = Timer(const Duration(seconds: 20), () {
      if (mounted) {
        setState(() => statusMessage =
            'Firebase is taking longer than expected. Check your internet connection. Your request is still pending; please wait before trying again.');
      }
    });
  }

  void endRequest() {
    slowRequestTimer?.cancel();
    if (mounted) setState(() => busy = false);
  }

  void showFailure(String message) {
    if (mounted) {
      setState(() {
        statusMessage = null;
        signInError = message;
      });
    }
  }

  Future<void> login() async {
    if (busy) return;
    final normalizedEmail = email.text.trim().toLowerCase();
    if (normalizedEmail.isEmpty || password.text.isEmpty) {
      setState(() => signInError = 'Please enter your email and password.');
      return;
    }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(normalizedEmail)) {
      setState(() => signInError = 'Please enter a valid email address.');
      return;
    }
    if (registering && password.text.length < 6) {
      setState(
          () => signInError = 'Use at least 6 characters for your password.');
      return;
    }
    if (registering && password.text != confirmPassword.text) {
      setState(() => signInError = 'Passwords do not match.');
      return;
    }
    final creatingAccount = registering;
    beginRequest();
    try {
      if (creatingAccount) {
        await auth.createUserWithEmailAndPassword(
            email: normalizedEmail, password: password.text);
      } else {
        await auth.signInWithEmailAndPassword(
            email: normalizedEmail, password: password.text);
      }
      if (mounted) {
        setState(() => statusMessage = creatingAccount
            ? 'Account created successfully. The owner must activate your store access.'
            : 'Signed in successfully. Loading your store access...');
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('Sign-in failed: ${e.code}');
      final message = switch (e.code) {
        'invalid-credential' ||
        'invalid-login-credentials' ||
        'wrong-password' ||
        'user-not-found' =>
          'Incorrect email or password. Please check your details and try again.',
        'invalid-email' => 'Please enter a valid email address.',
        'email-already-in-use' =>
          'This email is already registered. Sign in with your existing account or continue with Google.',
        'weak-password' =>
          'Please choose a stronger password with at least 6 characters.',
        'user-disabled' =>
          'This account has been disabled. Contact the store administrator.',
        'too-many-requests' =>
          'Too many sign-in attempts. Please wait a while and try again.',
        'network-request-failed' =>
          'Unable to connect. Check your internet connection and try again.',
        'operation-not-allowed' =>
          'Email authentication is unavailable. Contact the store administrator.',
        _ => creatingAccount
            ? 'Unable to create your account. Please try again.'
            : 'Unable to sign in. Please try again.',
      };
      showFailure(message);
    } catch (_) {
      if (mounted) {
        showFailure(creatingAccount
            ? 'Unable to create your account. Please try again.'
            : 'Unable to sign in. Please try again.');
      }
    } finally {
      endRequest();
    }
  }

  Future<void> loginWithGoogle() async {
    if (busy) return;
    beginRequest();
    try {
      if (kIsWeb) {
        await auth.signInWithPopup(GoogleAuthProvider());
      } else {
        try {
          await (googleInitialization ??= GoogleSignIn.instance.initialize());
        } catch (_) {
          googleInitialization = null;
          rethrow;
        }
        final account = await GoogleSignIn.instance.authenticate();
        final idToken = account.authentication.idToken;
        if (idToken == null) {
          throw StateError('Google did not return an ID token');
        }
        await auth.signInWithCredential(
            GoogleAuthProvider.credential(idToken: idToken));
      }
    } on GoogleSignInException catch (e) {
      if (mounted) {
        setState(() => signInError = e.code ==
                GoogleSignInExceptionCode.canceled
            ? 'Google sign-in was canceled. You can try again.'
            : 'Google sign-in is unavailable. Contact the administrator to check Google sign-in setup.');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => signInError = switch (e.code) {
              'account-exists-with-different-credential' =>
                'This email uses another sign-in method. Sign in with your existing account.',
              'popup-closed-by-user' ||
              'cancelled-popup-request' =>
                'Google sign-in was canceled. You can try again.',
              'network-request-failed' =>
                'Check your internet connection and try again.',
              'user-disabled' =>
                'This account is disabled. Contact the administrator.',
              _ =>
                'Unable to sign in with Google. Contact the administrator if this continues.',
            });
      }
    } catch (_) {
      if (mounted) {
        setState(() =>
            signInError = 'Unable to sign in with Google. Please try again.');
      }
    } finally {
      if (mounted && signInError != null) statusMessage = null;
      endRequest();
    }
  }

  Future<void> resetPassword() async {
    if (busy) return;
    final address = email.text.trim().toLowerCase();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(address)) {
      showFailure('Enter your email address above to reset your password.');
      return;
    }
    beginRequest();
    try {
      await auth.sendPasswordResetEmail(email: address);
      if (mounted) {
        setState(() => statusMessage =
            'If a password account exists for this email, a reset link has been sent. Check your inbox and spam folder.');
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        if (mounted) {
          setState(() => statusMessage =
              'If a password account exists for this email, a reset link has been sent. Check your inbox and spam folder.');
        }
      } else {
        showFailure(
            'Unable to send a reset email. Check your connection and try again.');
      }
    } catch (_) {
      showFailure('Unable to send a reset email. Please try again.');
    } finally {
      endRequest();
    }
  }

  @override
  void dispose() {
    slowRequestTimer?.cancel();
    email.dispose();
    password.dispose();
    confirmPassword.dispose();
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
                            const Icon(Icons.energy_savings_leaf_rounded,
                                size: 76, color: Color(0xFF166534)),
                            const SizedBox(height: 12),
                            Text('AgriTrack Pro',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(fontWeight: FontWeight.bold)),
                            const Text('Agri Supply • Store Management'),
                            const SizedBox(height: 36),
                            if (registering) ...[
                              Text('Create account',
                                  style:
                                      Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 16),
                            ],
                            TextField(
                                controller: email,
                                enabled: !busy,
                                onChanged: (_) => setState(() {}),
                                autocorrect: false,
                                enableSuggestions: false,
                                autofillHints: const [AutofillHints.username],
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                    labelText: 'Staff email',
                                    helperText: email.text
                                            .trim()
                                            .toLowerCase()
                                            .endsWith('@gmal.com')
                                        ? 'Did you mean @gmail.com? Check your account email.'
                                        : null)),
                            const SizedBox(height: 14),
                            TextField(
                                controller: password,
                                enabled: !busy,
                                autocorrect: false,
                                enableSuggestions: false,
                                autofillHints: [
                                  registering
                                      ? AutofillHints.newPassword
                                      : AutofillHints.password
                                ],
                                obscureText: hidePassword,
                                decoration: InputDecoration(
                                    labelText: 'Password',
                                    suffixIcon: IconButton(
                                      tooltip: hidePassword
                                          ? 'Show password'
                                          : 'Hide password',
                                      icon: Icon(hidePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined),
                                      onPressed: () => setState(
                                          () => hidePassword = !hidePassword),
                                    ))),
                            const SizedBox(height: 22),
                            if (registering) ...[
                              TextField(
                                controller: confirmPassword,
                                enabled: !busy,
                                autocorrect: false,
                                enableSuggestions: false,
                                obscureText: hidePassword,
                                decoration: const InputDecoration(
                                    labelText: 'Confirm password'),
                              ),
                              const SizedBox(height: 22),
                            ],
                            if (signInError != null) ...[
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  signInError!,
                                  style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.error),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (statusMessage != null) ...[
                              Semantics(
                                  liveRegion: true,
                                  child: Text(statusMessage!)),
                              const SizedBox(height: 12),
                            ],
                            if (busy) ...[
                              const LinearProgressIndicator(),
                              const SizedBox(height: 12),
                            ],
                            SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                    onPressed: busy ? null : login,
                                    icon: const Icon(Icons.login),
                                    label: Text(busy
                                        ? 'Please wait…'
                                        : registering
                                            ? 'Create account'
                                            : 'Sign in'))),
                            const SizedBox(height: 12),
                            if (!registering)
                              TextButton(
                                  onPressed: busy ? null : resetPassword,
                                  child: const Text('Forgot password?')),
                            if (kIsWeb ||
                                defaultTargetPlatform ==
                                    TargetPlatform.android ||
                                defaultTargetPlatform == TargetPlatform.iOS ||
                                defaultTargetPlatform == TargetPlatform.macOS)
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: busy ? null : loginWithGoogle,
                                  child: const Text('Continue with Google'),
                                ),
                              ),
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () => setState(() {
                                        registering = !registering;
                                        signInError = null;
                                        statusMessage = null;
                                        password.clear();
                                        confirmPassword.clear();
                                      }),
                              child: Text(registering
                                  ? 'Already have an account? Sign in'
                                  : 'Create an account'),
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: busy
                                    ? null
                                    : () => Navigator.of(context).push(
                                          MaterialPageRoute(
                                              builder: (_) =>
                                                  const GuestCatalogView()),
                                        ),
                                icon: const Icon(Icons.storefront_outlined),
                                label: const Text('Sign in as guest'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                                'New accounts need owner approval before accessing the store.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.black54))
                          ]))))));
}
