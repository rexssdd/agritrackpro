import 'package:agritrack_pro/services/store_repository.dart';
import 'package:agritrack_pro/views/owner/accounts_view.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// SDK snapshot test double; production code uses Firestore's implementation.
// ignore: subtype_of_sealed_class
class AccountDoc extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  AccountDoc(this.id, this.fields);
  @override
  final String id;
  final Map<String, dynamic> fields;
  @override
  Map<String, dynamic> data() => fields;
}

class AccountSnapshot extends Fake
    implements QuerySnapshot<Map<String, dynamic>> {
  @override
  final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[
    AccountDoc('owner',
        {'email': 'owner@example.com', 'role': 'owner', 'active': true}),
    AccountDoc('staff',
        {'email': 'staff@example.com', 'role': 'staff', 'active': false}),
  ];
}

class AccountRepo extends Fake implements StoreRepository {
  String? changed;
  String? reset;
  @override
  String get uid => 'owner';
  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> watchAccounts() =>
      Stream.value(AccountSnapshot());
  @override
  Future<void> setAccountAccess(String id, bool active) async {
    changed = '$id:$active';
  }

  @override
  Future<void> sendAccountReset(String email) async {
    reset = email;
  }
}

void main() {
  testWidgets('Owner can approve staff and send reset without disabling self',
      (tester) async {
    final repo = AccountRepo();
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: AccountsView(repo: repo))));
    await tester.pumpAndSettle();
    expect(find.text('Disable access'), findsNothing);
    await tester.tap(find.text('Allow access'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.changed, isNull);
    await tester.tap(find.text('Allow access'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Allow'));
    await tester.pumpAndSettle();
    expect(repo.changed, 'staff:true');
    await tester.tap(find.text('Send password reset').first);
    await tester.pumpAndSettle();
    expect(repo.reset, 'staff@example.com');
  });
}
