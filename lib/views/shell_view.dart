import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../widgets/confirm_dialog.dart';
import '../services/store_repository.dart';
import '../models/store_role.dart';
import 'role_workspace.dart';
import 'owner/owner_console.dart';

class ShellView extends StatefulWidget {
  const ShellView({super.key});
  @override
  State<ShellView> createState() => _ShellViewState();
}

class _ShellViewState extends State<ShellView> {
  final repo = StoreRepository();
  late var profileStream = repo.watchProfile();
  @override
  Widget build(BuildContext context) => StreamBuilder(
      stream: profileStream,
      builder: (context, s) {
        if (s.hasError) {
          final error = s.error;
          final message = error is FirebaseException &&
                  error.code == 'permission-denied'
              ? 'You are signed in, but store access could not be loaded. Ask the owner to deploy the latest Firestore rules and check your account ID.'
              : error is TimeoutException
                  ? 'You are signed in, but Firebase took too long to load your profile. Check your internet connection and tap Retry.'
                  : 'You are signed in, but your staff profile could not be loaded. Check your connection and tap Retry.';
          return Scaffold(
              appBar: AppBar(title: const Text('Unable to load access')),
              body: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(message, textAlign: TextAlign.center),
                SelectableText(
                    'Account ID: ${FirebaseAuth.instance.currentUser?.uid ?? ''}'),
                TextButton(
                    onPressed: () =>
                        setState(() => profileStream = repo.watchProfile()),
                    child: const Text('Retry')),
                TextButton(
                    onPressed: () async {
                      if (await confirmLogout(context)) {
                        await FirebaseAuth.instance.signOut();
                      }
                    },
                    child: const Text('Sign out')),
              ])));
        }
        if (!s.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final data = s.data!.data();
        if (data == null ||
            data['active'] != true ||
            StoreRole.parse(data['role']) == null) {
          return Scaffold(
              appBar: AppBar(title: const Text('Access pending')),
              body: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Ask the owner to activate your staff profile.'),
                SelectableText(FirebaseAuth.instance.currentUser?.email ?? ''),
                const SizedBox(height: 8),
                SelectableText(
                    'Account ID: ${FirebaseAuth.instance.currentUser!.uid}'),
                TextButton(
                    onPressed: () async {
                      if (await confirmLogout(context)) {
                        await FirebaseAuth.instance.signOut();
                      }
                    },
                    child: const Text('Sign out'))
              ])));
        }
        final role = StoreRole.parse(data['role'])!;
        repo.role = role.name;
        if (role == StoreRole.owner) {
          return OwnerConsole(key: ValueKey('owner-${repo.uid}'), repo: repo);
        }
        return RoleWorkspace(
            key:
                ValueKey('${role.name}-${repo.uid}-${data['inventoryAccess']}'),
            repo: repo,
            role: role,
            inventoryAccess: data['inventoryAccess'] == true);
      });
}
