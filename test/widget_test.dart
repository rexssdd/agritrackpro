import 'package:agritrack_pro/views/auth_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Sign in screen displays staff credentials fields',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AuthView()));

    expect(find.text('AgriTrack Pro'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Staff email'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Password'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Staff email'),
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
