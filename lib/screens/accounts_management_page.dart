import 'package:flutter/material.dart';
import '../models/account_model.dart';

import '../repositories/account_repository.dart';
import '../widgets/responsive_card_row.dart';

class AccountsManagementPage extends StatefulWidget {
  const AccountsManagementPage({super.key});

  @override
  State<AccountsManagementPage> createState() => _AccountsManagementPageState();
}

class _AccountsManagementPageState extends State<AccountsManagementPage> {
  // =====================================================
  // DATA
  // =====================================================

  final List<Map<String, dynamic>> transactions = [];
  final List<AccountModel> accounts = [];
  AccountModel? selectedAccount;

  // =====================================================
  // CONTROLLERS
  // =====================================================

  final TextEditingController amountController = TextEditingController();
  final TextEditingController noteController = TextEditingController();
  final TextEditingController searchController = TextEditingController();

  // =====================================================
  // SELECTIONS
  // =====================================================

  String transactionType = 'Income';

  String category = 'Other';

  bool isLoading = true;

  // =====================================================
  // CATEGORY LIST
  // =====================================================

  final List<String> incomeCategories = [
    'Rice Sale',
    'Wheat Sale',
    'Farm Income',
    'Other',
  ];

  final List<String> expenseCategories = [
    'Farm Expense',
    'Rice Purchase',
    'Wheat Purchase',
    'Transport',
    'Labour',
    'Fertilizer',
    'Seeds',
    'Other',
  ];

  // =====================================================
  // TOTAL INCOME
  // =====================================================

  double get totalIncome {
    double total = 0;

    for (final transaction in transactions) {
      if (transaction['type'] == 'Income') {
        total += _toDouble(transaction['amount']);
      }
    }

    return total;
  }

  // =====================================================
  // TOTAL EXPENSE
  // =====================================================

  double get totalExpense {
    double total = 0;

    for (final transaction in transactions) {
      if (transaction['type'] == 'Expense') {
        total += _toDouble(transaction['amount']);
      }
    }

    return total;
  }

  // =====================================================
  // NET BALANCE
  // =====================================================

  double get netBalance {
    return totalIncome - totalExpense;
  }

  // =====================================================
  // DOUBLE CONVERTER
  // =====================================================

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    if (value != null) {
      return double.tryParse(value.toString()) ?? 0;
    }

    return 0;
  }

  // =====================================================
  // INIT
  // =====================================================

  @override
  void initState() {
    super.initState();

    loadData();

    searchController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  // =====================================================
  // LOAD DATA
  // =====================================================

  Future<void> loadData() async {
    final loadedTransactions = AccountRepository().getRawTransactions();
    final loadedAccounts = await AccountRepository().getAccountsFromApi();

    if (!mounted) {
      return;
    }

    setState(() {
      accounts.clear();
      accounts.addAll(loadedAccounts);

      if (accounts.isNotEmpty) {
        selectedAccount = accounts.first;
      }
      transactions.clear();
      transactions.addAll(loadedTransactions);
      isLoading = false;
    });
  }

  // =====================================================
  // SAVE DATA
  // =====================================================

  Future<void> saveData() async {
    await AccountRepository().saveRawTransactions(transactions);
  }

  // =====================================================
  // ADD TRANSACTION
  // =====================================================

  Future<void> addTransaction() async {
    final amountText = amountController.text.trim();

    final amount = double.tryParse(amountText);

    final note = noteController.text.trim();

    // ===================================================
    // VALIDATION
    // ===================================================

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount'),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    // ===================================================
    // CREATE TRANSACTION
    // ===================================================

    final transaction = <String, dynamic>{
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'type': transactionType,
      'category': category,
      'amount': amount,
      'note': note,
      'date': DateTime.now().toIso8601String(),
    };

    setState(() {
      transactions.insert(0, transaction);
    });

    await saveData();

    amountController.clear();
    noteController.clear();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$transactionType added successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // =====================================================
  // DELETE TRANSACTION
  // =====================================================

  Future<void> deleteTransaction(int index) async {
    final transaction = filteredTransactions[index];

    final type = transaction['type']?.toString() ?? '';

    final amount = _toDouble(transaction['amount']);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Transaction?'),
          content: Text(
            'Are you sure you want to delete this $type transaction?\n\n'
            'Amount: Rs. ${amount.toStringAsFixed(0)}',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    final originalIndex = transactions.indexOf(transaction);

    if (originalIndex == -1) {
      return;
    }

    setState(() {
      transactions.removeAt(originalIndex);
    });

    await saveData();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transaction deleted successfully')),
    );
  }

  // =====================================================
  // FILTER TRANSACTIONS
  // =====================================================

  List<Map<String, dynamic>> get filteredTransactions {
    final query = searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      return transactions;
    }

    return transactions.where((transaction) {
      final type = transaction['type']?.toString().toLowerCase() ?? '';

      final category = transaction['category']?.toString().toLowerCase() ?? '';

      final note = transaction['note']?.toString().toLowerCase() ?? '';

      final amount = transaction['amount']?.toString().toLowerCase() ?? '';

      return type.contains(query) ||
          category.contains(query) ||
          note.contains(query) ||
          amount.contains(query);
    }).toList();
  }

  // =====================================================
  // FORMAT DATE
  // =====================================================

  String formatDate(dynamic value) {
    if (value == null) {
      return '';
    }

    try {
      final date = DateTime.parse(value.toString());

      final day = date.day.toString().padLeft(2, '0');

      final month = date.month.toString().padLeft(2, '0');

      final year = date.year.toString();

      return '$day-$month-$year';
    } catch (e) {
      return value.toString();
    }
  }

  // =====================================================
  // UPDATE CATEGORIES
  // =====================================================

  void updateTransactionType(String value) {
    setState(() {
      transactionType = value;

      if (transactionType == 'Income') {
        category = incomeCategories.first;
      } else {
        category = expenseCategories.first;
      }
    });
  }

  // =====================================================
  // SUMMARY CARD
  // =====================================================

  Widget summaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, color: color),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.grey),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // TRANSACTION CARD
  // =====================================================

  Widget transactionCard(Map<String, dynamic> transaction, int index) {
    final type = transaction['type']?.toString() ?? '';

    final category = transaction['category']?.toString() ?? 'Other';

    final note = transaction['note']?.toString() ?? '';

    final amount = _toDouble(transaction['amount']);

    final date = formatDate(transaction['date']);

    final isIncome = type == 'Income';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),

        // =================================================
        // ICON
        // =================================================
        leading: CircleAvatar(
          backgroundColor: isIncome
              ? Colors.green.withValues(alpha: 0.12)
              : Colors.red.withValues(alpha: 0.12),
          child: Icon(
            isIncome ? Icons.arrow_downward : Icons.arrow_upward,
            color: isIncome ? Colors.green : Colors.red,
          ),
        ),

        // =================================================
        // TITLE
        // =================================================
        title: Text(
          category,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),

        // =================================================
        // SUBTITLE
        // =================================================
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(note.isEmpty ? 'No note' : note),

              const SizedBox(height: 3),

              Text(
                date,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),

        // =================================================
        // AMOUNT
        // =================================================
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${isIncome ? '+' : '-'} Rs. ${amount.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isIncome ? Colors.green : Colors.red,
              ),
            ),

            const SizedBox(width: 8),

            IconButton(
              tooltip: 'Delete',
              onPressed: () {
                deleteTransaction(index);
              },
              icon: const Icon(Icons.delete, color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    final categories = transactionType == 'Income'
        ? incomeCategories
        : expenseCategories;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  // =================================================
                  // PAGE TITLE
                  // =================================================
                  const Text(
                    'Accounts Management',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'Manage income, expenses and account transactions',
                    style: TextStyle(color: Colors.grey, fontSize: 15),
                  ),

                  const SizedBox(height: 25),
                  // =================================================
                  // ACCOUNT SELECTION
                  // =================================================
                  if (accounts.isNotEmpty)
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedAccount?.id,
                          decoration: const InputDecoration(
                            labelText: 'Select Account',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.account_balance_wallet),
                          ),
                          items: accounts.map((account) {
                            return DropdownMenuItem<String>(
                              value: account.id,
                              child: Text(
                                '${account.name} - Rs. ${account.currentBalance.toStringAsFixed(0)}',
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }

                            setState(() {
                              selectedAccount = accounts.firstWhere(
                                (account) => account.id == value,
                              );
                            });
                          },
                        ),
                      ),
                    ),

                  const SizedBox(height: 25),

                  // =================================================
                  // SUMMARY
                  // =================================================
                  ResponsiveCardRow(
                    minCardWidth: 220,
                    aspectRatio: 2.6,
                    maxColumns: 3,
                    children: [
                      summaryCard(
                        title: 'Total Income',
                        value: 'Rs. ${totalIncome.toStringAsFixed(0)}',
                        icon: Icons.trending_up,
                        color: Colors.green,
                      ),

                      summaryCard(
                        title: 'Total Expense',
                        value: 'Rs. ${totalExpense.toStringAsFixed(0)}',
                        icon: Icons.trending_down,
                        color: Colors.red,
                      ),

                      summaryCard(
                        title: netBalance >= 0 ? 'Net Balance' : 'Net Loss',
                        value: 'Rs. ${netBalance.abs().toStringAsFixed(0)}',
                        icon: netBalance >= 0
                            ? Icons.account_balance
                            : Icons.warning,
                        color: netBalance >= 0 ? Colors.blue : Colors.red,
                      ),
                    ],
                  ),

                  const SizedBox(height: 35),

                  // =================================================
                  // ADD TRANSACTION
                  // =================================================
                  const Text(
                    'Add Account Transaction',
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 18),

                  Card(
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(20),

                      child: Column(
                        children: [
                          // =================================================
                          // TYPE
                          // =================================================
                          DropdownButtonFormField<String>(
                            initialValue: transactionType,
                            decoration: const InputDecoration(
                              labelText: 'Transaction Type',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.swap_horiz),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Income',
                                child: Text('Income'),
                              ),
                              DropdownMenuItem(
                                value: 'Expense',
                                child: Text('Expense'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }

                              updateTransactionType(value);
                            },
                          ),

                          const SizedBox(height: 15),

                          // =================================================
                          // CATEGORY
                          // =================================================
                          DropdownButtonFormField<String>(
                            initialValue: category,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.category),
                            ),
                            items: categories.map((item) {
                              return DropdownMenuItem<String>(
                                value: item,
                                child: Text(item),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }

                              setState(() {
                                category = value;
                              });
                            },
                          ),

                          const SizedBox(height: 15),

                          // =================================================
                          // AMOUNT
                          // =================================================
                          TextField(
                            controller: amountController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Amount',
                              hintText: 'Example: 50000',
                              prefixText: 'Rs. ',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.money),
                            ),
                          ),

                          const SizedBox(height: 15),

                          // =================================================
                          // NOTE
                          // =================================================
                          TextField(
                            controller: noteController,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Note',
                              hintText: 'Example: Rice sale payment',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.description),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // =================================================
                          // ADD BUTTON
                          // =================================================
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed: addTransaction,
                              icon: const Icon(Icons.add),
                              label: const Text(
                                'Add Transaction',
                                style: TextStyle(fontSize: 16),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1B5E20),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 35),

                  // =================================================
                  // TRANSACTION HISTORY
                  // =================================================
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Account Transactions',
                          style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      SizedBox(
                        width: 300,
                        child: TextField(
                          controller: searchController,
                          decoration: InputDecoration(
                            hintText: 'Search transaction...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: searchController.text.isNotEmpty
                                ? IconButton(
                                    onPressed: () {
                                      searchController.clear();
                                    },
                                    icon: const Icon(Icons.clear),
                                  )
                                : null,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // =================================================
                  // EMPTY
                  // =================================================
                  if (filteredTransactions.isEmpty)
                    Card(
                      child: SizedBox(
                        width: double.infinity,
                        height: 220,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.account_balance_wallet_outlined,
                              size: 65,
                              color: Colors.grey,
                            ),

                            const SizedBox(height: 15),

                            Text(
                              transactions.isEmpty
                                  ? 'No account transactions yet'
                                  : 'No transaction found',
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // =================================================
                  // TRANSACTION LIST
                  // =================================================
                  ...filteredTransactions.asMap().entries.map((entry) {
                    return transactionCard(entry.value, entry.key);
                  }),

                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  // =====================================================
  // DISPOSE
  // =====================================================

  @override
  void dispose() {
    amountController.dispose();
    noteController.dispose();
    searchController.dispose();

    super.dispose();
  }
}
