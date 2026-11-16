import 'package:flutter/material.dart';
import '../models/entities.dart';
import '../services/store_repository.dart';
import '../widgets/common.dart';

class ExpensesView extends StatelessWidget {
  final StoreRepository repo;
  final bool isOwner;
  const ExpensesView({super.key, required this.repo, required this.isOwner});
  Future<void> add(BuildContext context) async {
    final description = TextEditingController(),
        amount = TextEditingController();
    String category = 'Operating';
    DateTime expenseDate = DateTime.now();
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, set) => AlertDialog(
                    title: const Text('Record expense'),
                    content: SingleChildScrollView(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      ListTile(
                        title: const Text('Expense date'),
                        subtitle: Text(
                            '${expenseDate.year}-${expenseDate.month.toString().padLeft(2, '0')}-${expenseDate.day.toString().padLeft(2, '0')}'),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final chosen = await showDatePicker(
                              context: ctx,
                              initialDate: expenseDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now());
                          if (chosen != null && ctx.mounted) {
                            set(() => expenseDate = chosen);
                          }
                        },
                      ),
                      TextField(
                          controller: description,
                          decoration:
                              const InputDecoration(labelText: 'Description')),
                      const SizedBox(height: 10),
                      TextField(
                          controller: amount,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Amount (₱)')),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                          initialValue: category,
                          items: [
                            'Operating',
                            'Rent',
                            'Utilities',
                            'Delivery',
                            'Other'
                          ]
                              .map((v) =>
                                  DropdownMenuItem(value: v, child: Text(v)))
                              .toList(),
                          onChanged: (v) => set(() => category = v!))
                    ])),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Save'))
                    ])));
    if (ok != true) {
      description.dispose();
      amount.dispose();
      return;
    }
    try {
      await repo.addExpense(
          description.text, category, double.parse(amount.text),
          expenseDate: expenseDate);
    } catch (e) {
      if (context.mounted) errorMessage(context, e);
    } finally {
      description.dispose();
      amount.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Expense>>(
      stream: repo.watchExpenses(),
      builder: (context, s) {
        if (s.hasError) return Center(child: Text('${s.error}'));
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        return Scaffold(
            floatingActionButton: isOwner
                ? FloatingActionButton.extended(
                    onPressed: () => add(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Expense'))
                : null,
            body: ListView(padding: const EdgeInsets.all(16), children: [
              Text('Expenses',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Operating expenses are deducted from net profit.'),
              const SizedBox(height: 14),
              ...s.data!.map((e) => Card(
                  child: ListTile(
                      leading: const Icon(Icons.receipt_long),
                      title: Text(e.description),
                      subtitle: Text('${e.category} • ${stamp(e.createdAt)}'),
                      trailing: Text(peso(e.amount))))),
              if (s.data!.isEmpty)
                const Card(child: ListTile(title: Text('No expenses recorded')))
            ]));
      });
}
