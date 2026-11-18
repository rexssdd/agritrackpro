import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../views/customer/guest_catalog_view.dart';
import '../widgets/app_logo.dart';
import '../services/store_repository.dart';
import '../config/theme.dart';

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
  static const googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '',
  );
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
          await (googleInitialization ??= GoogleSignIn.instance.initialize(
            serverClientId:
                googleServerClientId.isEmpty ? null : googleServerClientId,
          ));
        } catch (_) {
          googleInitialization = null;
          rethrow;
        }
        final account = await GoogleSignIn.instance.authenticate();
        final idToken = account.authentication.idToken;
        if (idToken == null) {
          throw StateError('Google did not return an ID token');
        }
        final googleCredential =
            GoogleAuthProvider.credential(idToken: idToken);
        try {
          await auth.signInWithCredential(googleCredential);
        } on FirebaseAuthException catch (e) {
          if (e.code != 'account-exists-with-different-credential') rethrow;
          final address = email.text.trim().toLowerCase();
          if (address.isEmpty || password.text.isEmpty) {
            throw FirebaseAuthException(
              code: 'google-account-link-required',
              message:
                  'This Gmail already has an account. Enter that account password, then tap Continue with Google again to link both sign-in methods.',
            );
          }
          final existing = await auth.signInWithEmailAndPassword(
              email: address, password: password.text);
          await existing.user!.linkWithCredential(googleCredential);
        }
      }
      // Provision the Firestore profile before the shell opens. New Google
      // accounts are created as active customers immediately.
      try {
        await StoreRepository().watchProfile().first;
      } catch (error) {
        debugPrint('Google customer profile provisioning failed: $error');
      }
    } on GoogleSignInException catch (e) {
      if (mounted) {
        setState(() => signInError = switch (e.code) {
              GoogleSignInExceptionCode.canceled =>
                'Google sign-in was canceled. You can try again.',
              GoogleSignInExceptionCode.clientConfigurationError =>
                'Google sign-in is not configured for this Android app. Add the Android SHA-1 and OAuth client in Firebase, then download google-services.json again.',
              _ =>
                'Google sign-in is unavailable. Check the Firebase Google provider and Android OAuth configuration.',
            });
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
              'google-account-link-required' => e.message ??
                  'Enter the existing account password, then try Google sign-in again to link both methods.',
              'credential-already-in-use' =>
                'This Google account is already linked to another Firebase account.',
              'provider-already-linked' =>
                'Google sign-in is already linked to this account.',
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
      backgroundColor: Colors.white,
      body: SafeArea(
          child: Center(
              child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 30),
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 28, horizontal: 20),
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(28),
                                  gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFFF0F9EC),
                                        Color(0xFFD8EFDA)
                                      ])),
                              child: Column(children: [
                                const AppLogo(size: 90),
                                const SizedBox(height: 10),
                                const Text('AgriTrack Pro',
                                    style: TextStyle(
                                        fontSize: 29,
                                        fontWeight: FontWeight.w900,
                                        color: AgriTheme.darkGreen)),
                                const SizedBox(height: 3),
                                const Text('Agri Supply Management System',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 14, color: AgriTheme.ink)),
                                const SizedBox(height: 5),
                                const Text(
                                    'Sales  •  Inventory  •  Payments  •  Profit',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF56735D))),
                              ]),
                            ),
                            const SizedBox(height: 28),
                            Text(
                                registering ? 'Create account' : 'Welcome back',
                                style: const TextStyle(
                                    fontSize: 27,
                                    fontWeight: FontWeight.w800,
                                    color: AgriTheme.darkGreen)),
                            const SizedBox(height: 4),
                            Text(
                                registering
                                    ? 'Join your AgriTrack Pro store'
                                    : 'Sign in to your AgriTrack Pro account',
                                style:
                                    const TextStyle(color: Color(0xFF637269))),
                            const SizedBox(height: 24),
                            TextField(
                                controller: email,
                                enabled: !busy,
                                onChanged: (_) => setState(() {}),
                                autocorrect: false,
                                enableSuggestions: false,
                                autofillHints: const [AutofillHints.username],
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                    labelText: 'Email address',
                                    prefixIcon: const Icon(Icons.mail_outline),
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
                                    prefixIcon: const Icon(Icons.lock_outline),
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
                                            : 'Log in'))),
                            const SizedBox(height: 4),
                            if (!registering)
                              Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                      onPressed: busy ? null : resetPassword,
                                      child: const Text('Forgot password?'))),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Row(children: [
                                Expanded(child: Divider()),
                                Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 14),
                                    child: Text('or',
                                        style:
                                            TextStyle(color: Colors.black54))),
                                Expanded(child: Divider()),
                              ]),
                            ),
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
