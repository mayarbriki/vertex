import 'package:flutter/material.dart';
import 'package:smart_personal_final_app/db/db.dart';
import 'package:smart_personal_final_app/models/transaction.dart' as model;

class TransactionScreen extends StatefulWidget {
  const TransactionScreen({Key? key}) : super(key: key);

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  final _db = DBProvider.instance;
  List<model.Transaction> transactions = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _loading = true;
  int? _defaultAccountId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final accounts = await _db.getAllAccounts();
    if (accounts.isEmpty) {
      final userRows = await _db.getAllUsers();
      int userId;
      if (userRows.isEmpty) {
        userId = await _db.insertUser({'name': 'User', 'email': 'user@example.com'});
      } else {
        userId = userRows.first['id'] as int;
      }
      _defaultAccountId = await _db.insertAccount({
        'user_id': userId,
        'name': 'Default Account',
        'type': 'cash',
        'balance': 0.0,
        'currency': 'TND',
      });
    } else {
      _defaultAccountId = accounts.first['id'] as int;
    }

    final rows = await _db.getAllTransactions();
    transactions = rows.map((e) => model.Transaction.fromMap(e)).toList();
    setState(() => _loading = false);
  }

  List<model.Transaction> get filteredTransactions {
    if (_searchQuery.isEmpty) {
      return transactions;
    }
    return transactions
        .where((transaction) =>
            (transaction.description ?? '').toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (transaction.category ?? '').toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  double get totalIncome {
    return transactions.where((t) => t.isIncome).fold(0.0, (sum, t) => sum + t.amount);
  }

  double get totalExpense {
    return transactions.where((t) => t.isExpense).fold(0.0, (sum, t) => sum + t.amount);
  }

  double get balance => totalIncome - totalExpense;

  Future<void> _addTransaction() async {
    if (_defaultAccountId == null) return;
    final saved = await showDialog<model.Transaction>(
      context: context,
      builder: (context) => TransactionDialog(accountId: _defaultAccountId!),
    );
    if (saved != null) {
      await _db.insertTransaction(saved.toMap());
      await _loadData();
    }
  }

  Future<void> _editTransaction(model.Transaction transaction) async {
    final updated = await showDialog<model.Transaction>(
      context: context,
      builder: (context) => TransactionDialog(accountId: transaction.accountId, transaction: transaction),
    );
    if (updated != null && updated.id != null) {
      await _db.updateTransaction(updated.id!, updated.toMap());
      await _loadData();
    }
  }

  Future<void> _deleteTransaction(int id) async {
    await _db.deleteTransaction(id);
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Transactions',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Summary Cards with gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          title: 'Income',
                          amount: totalIncome,
                          color: const Color(0xFF4CAF50),
                          icon: Icons.trending_up,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          title: 'Expense',
                          amount: totalExpense,
                          color: const Color(0xFFf44336),
                          icon: Icons.trending_down,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SummaryCard(
                    title: 'Balance',
                    amount: balance,
                    color: balance >= 0 ? const Color(0xFF4CAF50) : const Color(0xFFf44336),
                    icon: Icons.account_balance_wallet,
                    isLarge: true,
                  ),
                ],
              ),
            ),
          ),
          // Search Bar with improved styling
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(20),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: const Color(0xFFE0E0E0)),
              ),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search transactions...',
                  prefixIcon: Icon(Icons.search, color: Color(0xFF9E9E9E)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),
          ),
          // Transaction List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filteredTransactions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No transactions found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredTransactions.length,
                    itemBuilder: (context, index) {
                      final transaction = filteredTransactions[index];
                      return _TransactionTile(
                        transaction: transaction,
                        onEdit: () => _editTransaction(transaction),
                        onDelete: () => _deleteTransaction(transaction.id!),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          ),
        ),
        child: FloatingActionButton(
          onPressed: _addTransaction,
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add, size: 28),
        ),
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

  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.color,
    required this.icon,
    this.isLarge = false,
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
                    color: const Color(0xFF718096),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Icon(icon, color: color, size: isLarge ? 24 : 20),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '\$${amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: isLarge ? 24 : 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final model.Transaction transaction;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TransactionTile({
    required this.transaction,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (transaction.isIncome
                ? const Color(0xFF4CAF50)
                : const Color(0xFFf44336)).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            transaction.isIncome
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            color: transaction.isIncome
                ? const Color(0xFF4CAF50)
                : const Color(0xFFf44336),
            size: 24,
          ),
        ),
        title: Text(
          (transaction.description?.isNotEmpty == true
              ? transaction.description!
              : (transaction.category ?? 'Transaction')),
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Color(0xFF2D3748),
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${transaction.category ?? 'Uncategorized'} • ${_formatDate(transaction.date)}',
            style: const TextStyle(
              color: Color(0xFF718096),
              fontSize: 14,
            ),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '\$${transaction.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: transaction.isIncome
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFFf44336),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: PopupMenuButton(
                icon: const Icon(Icons.more_vert, color: Color(0xFF9E9E9E)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 20),
                        SizedBox(width: 12),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 20, color: Colors.red),
                        SizedBox(width: 12),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class TransactionDialog extends StatefulWidget {
  final model.Transaction? transaction;
  final int accountId;

  const TransactionDialog({
    Key? key,
    required this.accountId,
    this.transaction,
  }) : super(key: key);

  @override
  State<TransactionDialog> createState() => _TransactionDialogState();
}

class _TransactionDialogState extends State<TransactionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _categoryController = TextEditingController();
  String _selectedType = 'expense';
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      _descriptionController.text = widget.transaction!.description ?? '';
      _amountController.text = widget.transaction!.amount.toString();
      _categoryController.text = widget.transaction!.category ?? '';
      _selectedType = widget.transaction!.type;
      _selectedDate = widget.transaction!.date;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.transaction == null ? 'Add Transaction' : 'Edit Transaction'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              validator: (value) => value?.isEmpty == true ? 'Please enter a description' : null,
            ),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'Amount'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value?.isEmpty == true) return 'Please enter an amount';
                if (double.tryParse(value!) == null) return 'Invalid amount';
                return null;
              },
            ),
            TextFormField(
              controller: _categoryController,
              decoration: const InputDecoration(labelText: 'Category'),
              validator: (value) =>
                  value?.isEmpty == true ? 'Please enter a category' : null,
            ),
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: const InputDecoration(labelText: 'Type'),
              items: const [
                DropdownMenuItem(value: 'income', child: Text('INCOME')),
                DropdownMenuItem(value: 'expense', child: Text('EXPENSE')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedType = value ?? 'expense';
                });
              },
            ),
            ListTile(
              title: const Text('Date'),
              subtitle: Text(_formatDate(_selectedDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  setState(() {
                    _selectedDate = date;
                  });
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final txn = model.Transaction(
                id: widget.transaction?.id,
                accountId: widget.accountId,
                type: _selectedType,
                amount: double.parse(_amountController.text),
                category: _categoryController.text,
                description: _descriptionController.text,
                date: _selectedDate,
              );
              Navigator.pop(context, txn);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
