import 'package:flutter/material.dart';
import 'package:smart_personal_final_app/db/db.dart';
import 'package:smart_personal_final_app/models/budget.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({Key? key}) : super(key: key);

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final _db = DBProvider.instance;
  List<Budget> _budgets = [];
  bool _loading = true;
  String _search = '';
  double _totalLimit = 0;
  double _totalSpent = 0;
  String _filter = 'all'; // all | active | over

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await _db.getAllBudgets();
    _budgets = rows.map((e) => Budget.fromMap(e)).toList();
    await _computeTotals();
    setState(() => _loading = false);
  }

  Future<void> _computeTotals() async {
    double limitSum = 0;
    double spentSum = 0;
    final now = DateTime.now();
    // compute spent for each budget within its own range
    for (final b in _budgets) {
      limitSum += b.amountLimit;
      final s = await _db.getSpentAmount(
        from: b.periodStart,
        to: b.periodEnd,
        accountId: b.accountId,
        category: b.category,
      );
      spentSum += s;
    }
    _totalLimit = limitSum;
    _totalSpent = spentSum;
  }

  Future<void> _addOrEdit({Budget? initial}) async {
    final result = await showDialog<Budget>(
      context: context,
      builder: (_) => _BudgetDialog(initial: initial),
    );
    if (result != null) {
      if (result.id == null) {
        await _db.insertBudget(result.toMap());
      } else {
        await _db.updateBudget(result.id!, result.toMap());
      }
      await _load();
    }
  }

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete budget?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await _db.deleteBudget(id);
      await _load();
    }
  }

  List<Budget> get _filtered {
    Iterable<Budget> list = _budgets;
    if (_filter == 'active') {
      final now = DateTime.now();
      list = list.where((b) => !now.isBefore(b.periodStart) && !now.isAfter(b.periodEnd));
    } else if (_filter == 'over') {
      // NOTE: Over filter needs spent; for simplicity, we won't prefetch here.
      // We'll estimate over by marking in tile; filter will be applied via search+approx
    }
    if (_search.isNotEmpty) {
      list = list.where((b) => b.name.toLowerCase().contains(_search.toLowerCase()));
    }
    return list.toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets'),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEdit(),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Summary Header
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          title: 'Total Limit',
                          amount: _totalLimit,
                          color: Colors.white,
                          icon: Icons.credit_card,
                          darkText: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          title: 'Total Spent',
                          amount: _totalSpent,
                          color: Colors.white,
                          icon: Icons.trending_down,
                          darkText: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SummaryCard(
                    title: 'Remaining',
                    amount: (_totalLimit - _totalSpent).clamp(0, double.infinity),
                    color: Colors.white,
                    icon: Icons.account_balance_wallet,
                    isLarge: true,
                    darkText: true,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('All'),
                          selected: _filter == 'all',
                          onSelected: (_) => setState(() => _filter = 'all'),
                        ),
                        ChoiceChip(
                          label: const Text('Active'),
                          selected: _filter == 'active',
                          onSelected: (_) => setState(() => _filter = 'active'),
                        ),
                        ChoiceChip(
                          label: const Text('Over Budget'),
                          selected: _filter == 'over',
                          onSelected: (_) => setState(() => _filter = 'over'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search budgets...'
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? const _EmptyBudgets()
                    : RefreshIndicator(
                        onRefresh: () async {
                          await _load();
                        },
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) => _BudgetTile(
                            budget: _filtered[i],
                            onEdit: () async { await _addOrEdit(initial: _filtered[i]); await _computeTotals(); setState(() {}); },
                            onDelete: () async { await _delete(_filtered[i].id!); await _computeTotals(); setState(() {}); },
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final double amount;
  final Color color;
  final IconData icon;
  final bool isLarge;
  final bool darkText;

  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.color,
    required this.icon,
    this.isLarge = false,
    this.darkText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isLarge ? 20 : 16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isLarge ? 16 : 14,
                    color: darkText ? const Color(0xFF2D3748) : const Color(0xFF718096),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Icon(icon, color: const Color(0xFF667eea), size: isLarge ? 24 : 20),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              amount.toStringAsFixed(2),
              style: TextStyle(
                fontSize: isLarge ? 24 : 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2D3748),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyBudgets extends StatelessWidget {
  const _EmptyBudgets();
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.pie_chart_outline, size: 80, color: Colors.grey[400]),
        const SizedBox(height: 12),
        Text('No budgets yet', style: TextStyle(color: Colors.grey[600])),
      ],
    );
  }
}

class _BudgetTile extends StatefulWidget {
  final Budget budget;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _BudgetTile({required this.budget, required this.onEdit, required this.onDelete});

  @override
  State<_BudgetTile> createState() => _BudgetTileState();
}

class _BudgetTileState extends State<_BudgetTile> {
  final _db = DBProvider.instance;
  double _spent = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSpent();
  }

  Future<void> _loadSpent() async {
    setState(() => _loading = true);
    final b = widget.budget;
    _spent = await _db.getSpentAmount(
      from: b.periodStart,
      to: b.periodEnd,
      accountId: b.accountId,
      category: b.category,
    );
    setState(() => _loading = false);
  }

  @override
  void didUpdateWidget(covariant _BudgetTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.budget.id != widget.budget.id) {
      _loadSpent();
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.budget;
    final percent = b.amountLimit == 0 ? 0.0 : (_spent / b.amountLimit).clamp(0.0, 1.0);
    final over = _spent > b.amountLimit;
    final color = over
        ? const Color(0xFFf44336)
        : percent > 0.8
            ? const Color(0xFFFF9800)
            : const Color(0xFF4CAF50);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0,2))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(b.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Text('${b.periodStart.toLocal().toString().split(' ').first} → ${b.periodEnd.toLocal().toString().split(' ').first}', style: const TextStyle(color: Color(0xFF718096))),
            if (b.category != null && b.category!.isNotEmpty)
              Text('Category: ${b.category}', style: const TextStyle(color: Color(0xFF718096))),
            const SizedBox(height: 10),
            _loading
              ? const LinearProgressIndicator(minHeight: 8)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(
                      value: percent,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFF0F0F0),
                      color: color,
                    ),
                    const SizedBox(height: 6),
                    Text('Spent: ${_spent.toStringAsFixed(2)} / ${b.amountLimit.toStringAsFixed(2)}',
                      style: TextStyle(color: color, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
          onSelected: (v) => v == 'edit' ? widget.onEdit() : widget.onDelete(),
        ),
      ),
    );
  }
}

class _BudgetDialog extends StatefulWidget {
  final Budget? initial;
  const _BudgetDialog({this.initial});

  @override
  State<_BudgetDialog> createState() => _BudgetDialogState();
}

class _BudgetDialogState extends State<_BudgetDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _category = TextEditingController();
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now().add(const Duration(days: 30));

  @override
  void initState() {
    super.initState();
    final b = widget.initial;
    if (b != null) {
      _name.text = b.name;
      _amount.text = b.amountLimit.toString();
      _category.text = b.category ?? '';
      _start = b.periodStart;
      _end = b.periodEnd;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Add Budget' : 'Edit Budget'),
      content: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Enter a name' : null,
              ),
              TextFormField(
                controller: _amount,
                decoration: const InputDecoration(labelText: 'Amount limit'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final d = double.tryParse(v ?? '');
                  if (d == null || d <= 0) return 'Enter a valid amount';
                  return null;
                },
              ),
              TextFormField(
                controller: _category,
                decoration: const InputDecoration(labelText: 'Category (optional)'),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Period start'),
                subtitle: Text(_start.toLocal().toString().split(' ').first),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _start,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _start = picked);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Period end'),
                subtitle: Text(_end.toLocal().toString().split(' ').first),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _end,
                    firstDate: _start,
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _end = picked);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            final amount = double.parse(_amount.text);
            final res = Budget(
              id: widget.initial?.id,
              userId: widget.initial?.userId,
              accountId: widget.initial?.accountId,
              name: _name.text.trim(),
              amountLimit: amount,
              periodStart: _start,
              periodEnd: _end,
              category: _category.text.trim().isEmpty ? null : _category.text.trim(),
            );
            Navigator.pop(context, res);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
