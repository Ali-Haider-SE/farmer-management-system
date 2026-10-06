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
  // REPOSITORY
  // =====================================================

  final AccountRepository repository = AccountRepository();

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
  bool isTransactionLoading = false;
  bool isSavingTransaction = false;

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
      if (transaction['type']?.toString() == 'Income') {
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
      if (transaction['type']?.toString() == 'Expense') {
        total += _toDouble(transaction['amount']);
      }
    }

    return total;
  }

  // =====================================================
  // NET TRANSACTION BALANCE
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
  // LOAD ACCOUNTS + FIRST ACCOUNT TRANSACTIONS
  // =====================================================

  Future<void> loadData() async {
    debugPrint('========== ACCOUNTS LOAD START ==========');

    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      debugPrint('Calling GET /accounts...');

      final loadedAccounts = await repository.getAccountsFromApi();

      debugPrint('GET /accounts completed');
      debugPrint('API ACCOUNTS COUNT: ${loadedAccounts.length}');
      debugPrint('API ACCOUNTS: ${loadedAccounts.map((e) => e.name).toList()}');

      if (!mounted) {
        debugPrint('Widget is no longer mounted.');
        return;
      }

      accounts
        ..clear()
        ..addAll(loadedAccounts);

      debugPrint('Accounts added to UI: ${accounts.length}');

      if (accounts.isEmpty) {
        setState(() {
          selectedAccount = null;
          transactions.clear();
          isLoading = false;
        });

        debugPrint('NO ACCOUNTS FOUND');
        return;
      }

      selectedAccount = accounts.first;

      debugPrint(
        'Selected account: ${selectedAccount!.name} '
        '(${selectedAccount!.id})',
      );

      await loadTransactionsForSelectedAccount();

      if (!mounted) {
        return;
      }

      setState(() {
        isLoading = false;
      });

      debugPrint('========== ACCOUNTS LOAD COMPLETE ==========');
    } catch (error, stackTrace) {
      debugPrint('========== ACCOUNTS LOAD ERROR ==========');
      debugPrint('ERROR: $error');
      debugPrint('STACK: $stackTrace');

      if (!mounted) {
        return;
      }

      setState(() {
        isLoading = false;
        transactions.clear();
      });

      _showErrorSnackBar('Failed to load accounts: ${_cleanError(error)}');
    }
  }

  Future<void> loadTransactionsForSelectedAccount() async {
    if (selectedAccount == null) {
      transactions.clear();
      return;
    }

    if (mounted) {
      setState(() {
        isTransactionLoading = true;
      });
    }

    try {
      final loadedTransactions = await repository.getAccountTransactionsFromApi(
        selectedAccount!.id,
      );

      if (!mounted) return;

      setState(() {
        transactions
          ..clear()
          ..addAll(loadedTransactions);
        isTransactionLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        transactions.clear();
        isTransactionLoading = false;
      });

      _showErrorSnackBar('Failed to load transactions: ${_cleanError(error)}');
    }
  }

  // =====================================================
  // REFRESH ACCOUNTS FROM API
  // =====================================================

  Future<void> refreshAccounts({bool reloadTransactions = true}) async {
    try {
      final selectedId = selectedAccount?.id;

      final loadedAccounts = await repository.getAccountsFromApi();

      if (!mounted) {
        return;
      }

      setState(() {
        accounts
          ..clear()
          ..addAll(loadedAccounts);

        if (accounts.isEmpty) {
          selectedAccount = null;
        } else if (selectedId != null) {
          final matchingAccount = accounts.where(
            (account) => account.id == selectedId,
          );

          if (matchingAccount.isNotEmpty) {
            selectedAccount = matchingAccount.first;
          } else {
            selectedAccount = accounts.first;
          }
        } else {
          selectedAccount = accounts.first;
        }
      });

      if (reloadTransactions) {
        await loadTransactionsForSelectedAccount();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showErrorSnackBar('Failed to refresh accounts: ${_cleanError(error)}');
    }
  }

  // =====================================================
  // ACCOUNT SELECTION
  // =====================================================

  Future<void> changeSelectedAccount(String accountId) async {
    AccountModel? newAccount;

    for (final account in accounts) {
      if (account.id == accountId) {
        newAccount = account;
        break;
      }
    }

    if (newAccount == null) {
      return;
    }

    setState(() {
      selectedAccount = newAccount;
      transactions.clear();
    });

    await loadTransactionsForSelectedAccount();
  }

  // =====================================================
  // ADD TRANSACTION
  // =====================================================

  Future<void> addTransaction() async {
    final account = selectedAccount;

    if (account == null) {
      _showErrorSnackBar('Please select an account first.');
      return;
    }

    final amountText = amountController.text.trim();
    final amount = double.tryParse(amountText);
    final note = noteController.text.trim();

    // ===================================================
    // VALIDATION
    // ===================================================

    if (amount == null || amount <= 0) {
      _showErrorSnackBar('Please enter a valid amount.');
      return;
    }

    if (isSavingTransaction) {
      return;
    }

    setState(() {
      isSavingTransaction = true;
    });

    try {
      // =================================================
      // CREATE TRANSACTION THROUGH API
      // =================================================

      await repository.createAccountTransactionApi(
        accountId: account.id,
        date: DateTime.now(),
        type: transactionType,
        amount: amount,
        category: category,
        note: note,
      );

      // =================================================
      // CLEAR INPUTS
      // =================================================

      amountController.clear();
      noteController.clear();

      // =================================================
      // REFRESH ACCOUNT + TRANSACTIONS FROM API
      // =================================================

      await refreshAccounts(reloadTransactions: true);

      if (!mounted) {
        return;
      }

      setState(() {
        isSavingTransaction = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$transactionType added successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        isSavingTransaction = false;
      });

      _showErrorSnackBar('Failed to add transaction: ${_cleanError(error)}');
    }
  }

  // =====================================================
  // DELETE TRANSACTION
  // =====================================================

  Future<void> deleteTransaction(int index) async {
    if (index < 0 || index >= filteredTransactions.length) {
      return;
    }

    final transaction = filteredTransactions[index];

    final transactionId = transaction['id']?.toString();

    if (transactionId == null || transactionId.isEmpty) {
      _showErrorSnackBar('Invalid transaction ID.');
      return;
    }

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

    final account = selectedAccount;

    if (account == null) {
      _showErrorSnackBar('Please select an account first.');
      return;
    }

    setState(() {
      isTransactionLoading = true;
    });

    try {
      // =================================================
      // DELETE THROUGH API
      // =================================================

      await repository.deleteAccountTransactionApi(
        accountId: account.id,
        transactionId: transactionId,
      );

      // =================================================
      // REFRESH ACCOUNT + TRANSACTIONS
      // =================================================

      await refreshAccounts(reloadTransactions: true);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        isTransactionLoading = false;
      });

      _showErrorSnackBar('Failed to delete transaction: ${_cleanError(error)}');
    }
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

      final note =
          transaction['note']?.toString().toLowerCase() ??
          transaction['description']?.toString().toLowerCase() ??
          '';

      final amount = transaction['amount']?.toString().toLowerCase() ?? '';

      final date = transaction['date']?.toString().toLowerCase() ?? '';

      return type.contains(query) ||
          category.contains(query) ||
          note.contains(query) ||
          amount.contains(query) ||
          date.contains(query);
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
      final date = DateTime.parse(value.toString()).toLocal();

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
  // ERROR MESSAGE
  // =====================================================

  String _cleanError(Object error) {
    final message = error.toString();

    if (message.startsWith('Exception: ')) {
      return message.substring('Exception: '.length);
    }

    return message;
  }

  // =====================================================
  // ERROR SNACKBAR
  // =====================================================

  void _showErrorSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
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

    final transactionCategory = transaction['category']?.toString() ?? 'Other';

    final note =
        transaction['note']?.toString() ??
        transaction['description']?.toString() ??
        '';

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
          transactionCategory,
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
        // AMOUNT + DELETE
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
              onPressed: isTransactionLoading
                  ? null
                  : () {
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
                                '${account.name} - Rs. '
                                '${account.currentBalance.toStringAsFixed(0)}',
                              ),
                            );
                          }).toList(),

                          onChanged: isTransactionLoading
                              ? null
                              : (value) async {
                                  if (value == null) {
                                    return;
                                  }

                                  await changeSelectedAccount(value);
                                },
                        ),
                      ),
                    ),

                  if (accounts.isEmpty)
                    Card(
                      child: SizedBox(
                        width: double.infinity,
                        height: 130,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.account_balance_wallet_outlined,
                              size: 45,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'No accounts available',
                              style: TextStyle(
                                fontSize: 17,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: loadData,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Refresh'),
                            ),
                          ],
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
                          // =========================================
                          // TYPE
                          // =========================================
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

                            onChanged: isSavingTransaction
                                ? null
                                : (value) {
                                    if (value == null) {
                                      return;
                                    }

                                    updateTransactionType(value);
                                  },
                          ),

                          const SizedBox(height: 15),

                          // =========================================
                          // CATEGORY
                          // =========================================
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

                            onChanged: isSavingTransaction
                                ? null
                                : (value) {
                                    if (value == null) {
                                      return;
                                    }

                                    setState(() {
                                      category = value;
                                    });
                                  },
                          ),

                          const SizedBox(height: 15),

                          // =========================================
                          // AMOUNT
                          // =========================================
                          TextField(
                            controller: amountController,

                            enabled: !isSavingTransaction,

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

                          // =========================================
                          // NOTE
                          // =========================================
                          TextField(
                            controller: noteController,

                            enabled: !isSavingTransaction,

                            maxLines: 2,

                            decoration: const InputDecoration(
                              labelText: 'Note',
                              hintText: 'Example: Rice sale payment',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.description),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // =========================================
                          // ADD BUTTON
                          // =========================================
                          SizedBox(
                            width: double.infinity,
                            height: 52,

                            child: ElevatedButton.icon(
                              onPressed:
                                  selectedAccount == null || isSavingTransaction
                                  ? null
                                  : addTransaction,

                              icon: isSavingTransaction
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.add),

                              label: Text(
                                isSavingTransaction
                                    ? 'Saving...'
                                    : 'Add Transaction',
                                style: const TextStyle(fontSize: 16),
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
                  // TRANSACTION LOADING
                  // =================================================
                  if (isTransactionLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Center(child: CircularProgressIndicator()),
                    ),

                  // =================================================
                  // EMPTY
                  // =================================================
                  if (!isTransactionLoading && filteredTransactions.isEmpty)
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
                  if (!isTransactionLoading)
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
