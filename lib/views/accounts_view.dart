import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/store_repository.dart';

class AccountsView extends StatefulWidget {
  const AccountsView({super.key, required this.repo});
  final StoreRepository repo;
  @override
  State<AccountsView> createState() => _AccountsViewState();
}

class _AccountsViewState extends State<AccountsView> {
  late final accounts = widget.repo.watchAccounts();
  final pending = <String>{};
  String search = '';

  Future<void> act(
      String id, Future<void> Function() action, String message) async {
    if (pending.contains(id)) return;
    setState(() => pending.add(id));
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Unable to complete this action. Check your connection and owner permissions.')));
      }
    } finally {
      if (mounted) setState(() => pending.remove(id));
    }
  }

  Future<void> changeAccess(String id, String email, bool active) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: Text(
                  active ? 'Allow store access?' : 'Disable store access?'),
              content: Text(active
                  ? 'Allow $email to access the store?'
                  : '$email will lose access to store data. Their login account remains available.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(active ? 'Allow' : 'Disable'))
              ],
            ));
    if (confirmed == true && mounted) {
      await act(id, () => widget.repo.setAccountAccess(id, active),
          active ? 'Store access enabled.' : 'Store access disabled.');
    }
  }

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: accounts,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
                child: Text(
                    'Unable to load accounts. Check your connection and deploy the latest Firestore rules.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs
              .where((d) => '${d.data()['email'] ?? ''} ${d.id}'
                  .toLowerCase()
                  .contains(search.toLowerCase()))
              .toList()
            ..sort((a, b) {
              final byAccess = (a.data()['active'] == true ? 1 : 0)
                  .compareTo(b.data()['active'] == true ? 1 : 0);
              return byAccess != 0
                  ? byAccess
                  : '${a.data()['email'] ?? a.id}'
                      .compareTo('${b.data()['email'] ?? b.id}');
            });
          return ListView(padding: const EdgeInsets.all(16), children: [
            Text('Accounts', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text(
                'Approve new accounts or disable store access. Password resets send an email; passwords are never visible here.'),
            const SizedBox(height: 12),
            TextField(
                onChanged: (value) => setState(() => search = value),
                decoration: const InputDecoration(
                    labelText: 'Search email or account ID',
                    prefixIcon: Icon(Icons.search))),
            const SizedBox(height: 12),
            if (docs.isEmpty)
              const Text(
                  'No accounts found. New users appear after signing in to the app.'),
            for (final doc in docs)
              Builder(builder: (context) {
                final data = doc.data();
                final email = data['email'] as String? ?? '';
                final active = data['active'] == true;
                final self = doc.id == widget.repo.uid;
                final working = pending.contains(doc.id);
                return Card(
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(email.isEmpty ? 'Email unavailable' : email,
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              Text(
                                  '${data['role'] ?? 'staff'} • ${active ? 'Access enabled' : 'Pending / disabled'}${self ? ' • You' : ''}'),
                              SelectableText('Account ID: ${doc.id}'),
                              if (email.isEmpty)
                                const Text(
                                    'This user must sign in again to sync their email.'),
                              const SizedBox(height: 8),
                              if (!self)
                                DropdownButtonFormField<String>(
                                  key: ValueKey('${doc.id}-${data['role']}'),
                                  initialValue: [
                                    'cashier',
                                    'inventory',
                                    'customer',
                                    'staff'
                                  ].contains(data['role'])
                                      ? data['role'] as String
                                      : null,
                                  decoration: const InputDecoration(
                                      labelText: 'Assigned workspace'),
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'cashier',
                                        child: Text('Cashier')),
                                    DropdownMenuItem(
                                        value: 'inventory',
                                        child: Text('Inventory personnel')),
                                    DropdownMenuItem(
                                        value: 'customer',
                                        child: Text('Customer catalog')),
                                    DropdownMenuItem(
                                        value: 'staff',
                                        child:
                                            Text('Staff (checkout and stock)')),
                                  ],
                                  onChanged: working
                                      ? null
                                      : (role) {
                                          if (role != null) {
                                            act(
                                                doc.id,
                                                () => widget.repo
                                                    .setAccountRole(
                                                        doc.id, role),
                                                'Workspace updated.');
                                          }
                                        },
                                ),
                              Wrap(spacing: 8, children: [
                                if (!self)
                                  OutlinedButton(
                                      onPressed: working
                                          ? null
                                          : () => changeAccess(
                                              doc.id,
                                              email.isEmpty ? doc.id : email,
                                              !active),
                                      child: Text(active
                                          ? 'Disable access'
                                          : 'Allow access')),
                                TextButton(
                                    onPressed: working || email.isEmpty
                                        ? null
                                        : () => act(
                                            doc.id,
                                            () => widget.repo
                                                .sendAccountReset(email),
                                            'If this email has a password account, a reset link has been sent. Google users can continue with Google.'),
                                    child: const Text('Send password reset')),
                              ]),
                              if (working) const LinearProgressIndicator(),
                            ])));
              }),
          ]);
        },
      );
}
