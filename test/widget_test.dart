import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:agritrack_pro/auth/auth_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class TestAuth extends Fake implements FirebaseAuth {
  int calls = 0;
  String? submittedEmail;
  String? error;
  Completer<UserCredential>? pending;
  @override
  Future<UserCredential> signInWithEmailAndPassword(
      {required String email, required String password}) async {
    calls++;
    submittedEmail = email;
    if (pending != null) return pending!.future;
    throw FirebaseAuthException(code: error ?? 'invalid-credential');
  }

  @override
  Future<UserCredential> createUserWithEmailAndPassword(
      {required String email, required String password}) async {
    calls++;
    submittedEmail = email;
    if (error != null) throw FirebaseAuthException(code: error!);
    return TestCredential();
  }

  @override
  Future<void> sendPasswordResetEmail(
      {required String email, ActionCodeSettings? actionCodeSettings}) async {
    submittedEmail = email;
  }
}

class TestCredential extends Fake implements UserCredential {}

Future<void> enterCredentials(WidgetTester tester) async {
  await tester.enterText(
      find.widgetWithText(TextField, 'Email address'), '  Staff@Example.com  ');
  await tester.enterText(
      find.widgetWithText(TextField, 'Password'), 'password123');
}

Future<void> submit(WidgetTester tester, String label) async {
  final button = find.widgetWithText(FilledButton, label);
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
}

void main() {
  testWidgets('Incorrect credentials display an error and allow retry',
      (tester) async {
    final auth = TestAuth();
    await tester.pumpWidget(MaterialApp(home: AuthView(auth: auth)));
    await enterCredentials(tester);
    await submit(tester, 'Log in');
    expect(auth.submittedEmail, 'staff@example.com');
    expect(find.textContaining('Incorrect email or password.'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull);
  });

  testWidgets('Duplicate registration is rejected and success is explained',
      (tester) async {
    final auth = TestAuth()..error = 'email-already-in-use';
    await tester.pumpWidget(MaterialApp(home: AuthView(auth: auth)));
    await tester.ensureVisible(find.text('Create an account'));
    await tester.tap(find.text('Create an account'));
    await tester.pump();
    await enterCredentials(tester);
    await tester.enterText(
        find.widgetWithText(TextField, 'Confirm password'), 'password123');
    await submit(tester, 'Create account');
    expect(find.textContaining('This email is already registered.'),
        findsOneWidget);
    auth.error = null;
    await submit(tester, 'Create account');
    expect(
        find.textContaining('Account created successfully.'), findsOneWidget);
    expect(
        find.textContaining('This email is already registered.'), findsNothing);
  });

  testWidgets('Slow requests show feedback and block duplicate submissions',
      (tester) async {
    final auth = TestAuth()..pending = Completer<UserCredential>();
    await tester.pumpWidget(MaterialApp(home: AuthView(auth: auth)));
    await enterCredentials(tester);
    await submit(tester, 'Log in');
    await tester.pump(const Duration(seconds: 21));
    expect(
        find.textContaining('Your request is still pending'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    expect(auth.calls, 1);
    auth.pending!
        .completeError(FirebaseAuthException(code: 'network-request-failed'));
    await tester.pump();
    expect(find.textContaining('Check your internet connection and try again.'),
        findsOneWidget);
    expect(find.textContaining('Your request is still pending'), findsNothing);
  });

  testWidgets('Password reset uses normalized email and confirms submission',
      (tester) async {
    final auth = TestAuth();
    await tester.pumpWidget(MaterialApp(home: AuthView(auth: auth)));
    await enterCredentials(tester);
    final button = find.text('Forgot password?');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    expect(auth.submittedEmail, 'staff@example.com');
    expect(find.textContaining('a reset link has been sent'), findsOneWidget);
  });

  testWidgets('Registration validates confirmation and can return to sign in',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AuthView()));
    await tester.ensureVisible(find.text('Create an account'));
    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Email address'), 'staff@example.com');
    await tester.enterText(
        find.widgetWithText(TextField, 'Password'), 'password123');
    await tester.enterText(
        find.widgetWithText(TextField, 'Confirm password'), 'different');
    final createButton = find.widgetWithText(FilledButton, 'Create account');
    await tester.ensureVisible(createButton);
    await tester.tap(createButton);
    await tester.pumpAndSettle();
    expect(find.text('Passwords do not match.'), findsOneWidget);
    final backButton = find.text('Already have an account? Sign in');
    await tester.ensureVisible(backButton);
    await tester.tap(backButton);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Confirm password'), findsNothing);
    expect(find.text('Passwords do not match.'), findsNothing);
  });

  testWidgets('Sign in screen displays staff credentials fields',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AuthView()));

    expect(find.text('AgriTrack Pro'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Email address'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Password'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Log in'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Email address'),
      'staff@example.com',
    );
    await tester.enterText(
        find.widgetWithText(TextField, 'Password'), 'password');
    expect(find.text('staff@example.com'), findsOneWidget);
    expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Password'))
            .obscureText,
        isTrue);
  });
}
