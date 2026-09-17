// dashboard_page.dart
//
// Complete Dashboard for Farmer Management System
// Includes:
// Dashboard
// Farm Management
// Rice Management
// Wheat Management
// Parties / Khata
// Accounts
// Stock
// Reports
// Settings

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'farm_management_page.dart';
import 'rice_management_page.dart';
import 'wheat_management_page.dart';
import 'parties_khata_page.dart';
import 'reports_page.dart';
import 'stock_management_page.dart';
import 'settings_page.dart';
import 'login_page.dart';

import '../services/storage_service.dart';
import '../repositories/auth_repository.dart';
import '../repositories/account_repository.dart';
import '../widgets/summary_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/quick_action.dart';
import '../widgets/responsive_card_row.dart';
import '../services/backup_service.dart';
import '../services/notification_center.dart';
import '../core/utils/responsive.dart';
import '../core/security/role_permissions.dart';

class DashboardPage extends StatefulWidget {
  final String role;

  const DashboardPage({super.key, required this.role});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int selectedIndex = 0;

  final List<String> menuItems = [
    'Dashboard',
    'Farm Management',
    'Rice Management',
    'Wheat Management',
    'Parties / Khata',
    'Accounts',
    'Stock',
    'Reports',
    'Settings',
  ];

  final List<IconData> menuIcons = [
    Icons.dashboard,
    Icons.agriculture,
    Icons.rice_bowl,
    Icons.grass,
    Icons.people,
    Icons.account_balance_wallet,
    Icons.inventory,
    Icons.bar_chart,
    Icons.settings,
  ];

  // =========================================================
  // ROLE-BASED ACCESS
  // =========================================================
  // Menu index reference:
  // 0 Dashboard, 1 Farm Management, 2 Rice Management,
  // 3 Wheat Management, 4 Parties/Khata, 5 Accounts,
  // 6 Stock, 7 Reports, 8 Settings

  List<int> get accessibleMenuIndices {
    return RolePermissions.accessibleMenuIndices(
      widget.role,
    ).toList(growable: false);
  }

  bool _canAccess(int index) =>
      RolePermissions.canAccessMenu(widget.role, index);

  // =========================================================
  // DATA
  // =========================================================

  List<Map<String, dynamic>> farms = [];
  List<Map<String, dynamic>> riceTransactions = [];
  List<Map<String, dynamic>> wheatTransactions = [];
  List<Map<String, dynamic>> parties = [];
  List<Map<String, dynamic>> accountTransactions = [];

  bool isLoading = true;

  // =========================================================
  // ACCOUNT CONTROLLERS
  // =========================================================

  final TextEditingController accountAmountController = TextEditingController();

  final TextEditingController accountNoteController = TextEditingController();

  String accountTransactionType = 'Income';
  String accountCategory = 'Other Income';

  static const List<String> incomeCategories = [
    'Rice Sale',
    'Wheat Sale',
    'Farm Income',
    'Other Income',
  ];

  static const List<String> expenseCategories = [
    'Rice Purchase',
    'Wheat Purchase',
    'Farm Expense',
    'Transport',
    'Labour',
    'Fertilizer',
    'Seeds',
    'Other Expense',
  ];

  // =========================================================
  // HELPERS
  // =========================================================

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    if (value != null) {
      return double.tryParse(value.toString()) ?? 0;
    }

    return 0;
  }

  // =========================================================
  // FARM TOTAL AREA
  // =========================================================

  double get totalArea {
    double total = 0;

    for (final farm in farms) {
      total += _toDouble(farm['area']);
    }

    return total;
  }

  // =========================================================
  // FARM INCOME
  // =========================================================

  double get totalFarmIncome {
    double total = 0;

    for (final farm in farms) {
      final incomes = farm['incomes'];

      if (incomes is List) {
        for (final income in incomes) {
          if (income is Map) {
            if (income['total'] != null) {
              total += _toDouble(income['total']);
            } else {
              total += _toDouble(income['amount']);
            }
          }
        }
      }
    }

    return total;
  }

  // =========================================================
  // FARM EXPENSE
  // =========================================================

  double get totalFarmExpense {
    double total = 0;

    for (final farm in farms) {
      final expenses = farm['expenses'];

      if (expenses is List) {
        for (final expense in expenses) {
          if (expense is Map) {
            total += _toDouble(expense['amount']);
          }
        }
      }
    }

    return total;
  }

  // =========================================================
  // ACCOUNT INCOME
  // =========================================================

  double get totalAccountIncome {
    double total = 0;

    for (final transaction in accountTransactions) {
      if (transaction['type'] == 'Income') {
        total += _toDouble(transaction['amount']);
      }
    }

    return total;
  }

  // =========================================================
  // ACCOUNT EXPENSE
  // =========================================================

  double get totalAccountExpense {
    double total = 0;

    for (final transaction in accountTransactions) {
      if (transaction['type'] == 'Expense') {
        total += _toDouble(transaction['amount']);
      }
    }

    return total;
  }

  // =========================================================
  // TOTAL INCOME
  // =========================================================

  double get totalIncome {
    return totalFarmIncome + totalAccountIncome;
  }

  // =========================================================
  // TOTAL EXPENSE
  // =========================================================

  double get totalExpense {
    return totalFarmExpense + totalAccountExpense;
  }

  // =========================================================
  // RICE FARM PRODUCTION
  // =========================================================

  double get totalRiceFarmProduction {
    double total = 0;

    for (final farm in farms) {
      if (farm['crop'] != 'Rice') {
        continue;
      }

      final production = farm['production'];

      if (production is List) {
        for (final item in production) {
          if (item is Map) {
            total += _toDouble(item['quantity']);
          }
        }
      }
    }

    return total;
  }

  // =========================================================
  // RICE PURCHASE
  // =========================================================

  double get totalRicePurchase {
    double total = 0;

    for (final transaction in riceTransactions) {
      if (transaction['type'] == 'Purchase') {
        total += _toDouble(transaction['quantity']);
      }
    }

    return total;
  }

  // =========================================================
  // RICE SALE
  // =========================================================

  double get totalRiceSale {
    double total = 0;

    for (final transaction in riceTransactions) {
      if (transaction['type'] == 'Sale') {
        total += _toDouble(transaction['quantity']);
      }
    }

    return total;
  }

  // =========================================================
  // RICE STOCK
  // =========================================================

  double get currentRiceStock {
    return totalRiceFarmProduction + totalRicePurchase - totalRiceSale;
  }

  // =========================================================
  // RICE PURCHASE AMOUNT
  // =========================================================

  double get totalRicePurchaseAmount {
    double total = 0;

    for (final transaction in riceTransactions) {
      if (transaction['type'] == 'Purchase') {
        total += _toDouble(transaction['total']);
      }
    }

    return total;
  }

  // =========================================================
  // RICE SALE AMOUNT
  // =========================================================

  double get totalRiceSaleAmount {
    double total = 0;

    for (final transaction in riceTransactions) {
      if (transaction['type'] == 'Sale') {
        total += _toDouble(transaction['total']);
      }
    }

    return total;
  }

  // =========================================================
  // RICE PROFIT / LOSS
  // =========================================================

  double get riceProfitLoss {
    return totalRiceSaleAmount - totalRicePurchaseAmount;
  }

  // =========================================================
  // WHEAT FARM PRODUCTION
  // =========================================================

  double get totalWheatFarmProduction {
    double total = 0;

    for (final farm in farms) {
      if (farm['crop'] != 'Wheat') {
        continue;
      }

      final production = farm['production'];

      if (production is List) {
        for (final item in production) {
          if (item is Map) {
            total += _toDouble(item['quantity']);
          }
        }
      }
    }

    return total;
  }

  // =========================================================
  // WHEAT PURCHASE
  // =========================================================

  double get totalWheatPurchase {
    double total = 0;

    for (final transaction in wheatTransactions) {
      if (transaction['type'] == 'Purchase') {
        total += _toDouble(transaction['quantity']);
      }
    }

    return total;
  }

  // =========================================================
  // WHEAT SALE
  // =========================================================

  double get totalWheatSale {
    double total = 0;

    for (final transaction in wheatTransactions) {
      if (transaction['type'] == 'Sale') {
        total += _toDouble(transaction['quantity']);
      }
    }

    return total;
  }

  // =========================================================
  // WHEAT STOCK
  // =========================================================

  double get currentWheatStock {
    return totalWheatFarmProduction + totalWheatPurchase - totalWheatSale;
  }

  // =========================================================
  // WHEAT PURCHASE AMOUNT
  // =========================================================

  double get totalWheatPurchaseAmount {
    double total = 0;

    for (final transaction in wheatTransactions) {
      if (transaction['type'] == 'Purchase') {
        total += _toDouble(transaction['total']);
      }
    }

    return total;
  }

  // =========================================================
  // WHEAT SALE AMOUNT
  // =========================================================

  double get totalWheatSaleAmount {
    double total = 0;

    for (final transaction in wheatTransactions) {
      if (transaction['type'] == 'Sale') {
        total += _toDouble(transaction['total']);
      }
    }

    return total;
  }

  // =========================================================
  // WHEAT PROFIT / LOSS
  // =========================================================

  double get wheatProfitLoss {
    return totalWheatSaleAmount - totalWheatPurchaseAmount;
  }

  // =========================================================
  // PARTY BALANCE
  // =========================================================

  double getPartyBalance(Map<String, dynamic> party) {
    double balance = 0;

    if (party['openingBalanceType'] == 'You Give') {
      balance += _toDouble(party['openingBalance']);
    } else {
      balance -= _toDouble(party['openingBalance']);
    }

    final transactions = party['transactions'];

    if (transactions is List) {
      for (final item in transactions) {
        if (item is! Map) {
          continue;
        }

        final type = item['type']?.toString();
        final amount = _toDouble(item['amount']);

        if (type == 'You Give') {
          balance += amount;
        } else if (type == 'You Take') {
          balance -= amount;
        }
      }
    }

    return balance;
  }

  // =========================================================
  // PARTY TOTALS
  // =========================================================

  int get totalParties {
    return parties.length;
  }

  double get totalReceivable {
    double total = 0;

    for (final party in parties) {
      final balance = getPartyBalance(party);

      if (balance > 0) {
        total += balance;
      }
    }

    return total;
  }

  double get totalPayable {
    double total = 0;

    for (final party in parties) {
      final balance = getPartyBalance(party);

      if (balance < 0) {
        total += balance.abs();
      }
    }

    return total;
  }

  // =========================================================
  // NET PROFIT
  // =========================================================

  double get netProfit {
    return totalIncome - totalExpense + riceProfitLoss + wheatProfitLoss;
  }

  // =========================================================
  // TOTAL STOCK
  // =========================================================

  double get totalStock {
    return currentRiceStock + currentWheatStock;
  }

  // =========================================================
  // LOAD DATA
  // =========================================================

  Future<void> loadDashboardData() async {
    final storage = StorageService.instance;

    List<Map<String, dynamic>> loadedFarms = [];
    List<Map<String, dynamic>> loadedRiceTransactions = [];
    List<Map<String, dynamic>> loadedWheatTransactions = [];
    List<Map<String, dynamic>> loadedParties = [];
    List<Map<String, dynamic>> loadedAccounts = [];

    // ---------------- FARMS ----------------

    final farmData = storage.getString('farms_data');

    if (farmData != null && farmData.isNotEmpty) {
      try {
        final decodedData = jsonDecode(farmData);

        if (decodedData is List) {
          loadedFarms = decodedData
              .whereType<Map>()
              .map<Map<String, dynamic>>(
                (farm) => Map<String, dynamic>.from(farm),
              )
              .toList();
        }
      } catch (e) {
        debugPrint('Error loading farm data: $e');
      }
    }

    // ---------------- RICE ----------------

    final riceData = storage.getString('rice_transactions');

    if (riceData != null && riceData.isNotEmpty) {
      try {
        final decodedData = jsonDecode(riceData);

        if (decodedData is List) {
          loadedRiceTransactions = decodedData
              .whereType<Map>()
              .map<Map<String, dynamic>>(
                (item) => Map<String, dynamic>.from(item),
              )
              .toList();
        }
      } catch (e) {
        debugPrint('Error loading rice transactions: $e');
      }
    }

    // ---------------- WHEAT ----------------

    final wheatData = storage.getString('wheat_transactions');

    if (wheatData != null && wheatData.isNotEmpty) {
      try {
        final decodedData = jsonDecode(wheatData);

        if (decodedData is List) {
          loadedWheatTransactions = decodedData
              .whereType<Map>()
              .map<Map<String, dynamic>>(
                (item) => Map<String, dynamic>.from(item),
              )
              .toList();
        }
      } catch (e) {
        debugPrint('Error loading wheat transactions: $e');
      }
    }

    // ---------------- PARTIES ----------------

    final partiesData = storage.getString('parties_data');

    if (partiesData != null && partiesData.isNotEmpty) {
      try {
        final decodedData = jsonDecode(partiesData);

        if (decodedData is List) {
          loadedParties = decodedData
              .whereType<Map>()
              .map<Map<String, dynamic>>(
                (item) => Map<String, dynamic>.from(item),
              )
              .toList();
        }
      } catch (e) {
        debugPrint('Error loading parties: $e');
      }
    }

    // ---------------- ACCOUNTS ----------------

    final canonicalAccounts = AccountRepository().getRawTransactions();
    final accountsData = canonicalAccounts.isNotEmpty
        ? jsonEncode(canonicalAccounts)
        : storage.getString('accounts_data');

    if (accountsData != null && accountsData.isNotEmpty) {
      try {
        final decodedData = jsonDecode(accountsData);

        if (decodedData is List) {
          loadedAccounts = decodedData
              .whereType<Map>()
              .map<Map<String, dynamic>>(
                (item) => Map<String, dynamic>.from(item),
              )
              .toList();
        }
      } catch (e) {
        debugPrint('Error loading accounts: $e');
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      farms = loadedFarms;
      riceTransactions = loadedRiceTransactions;
      wheatTransactions = loadedWheatTransactions;
      parties = loadedParties;
      accountTransactions = loadedAccounts;
      isLoading = false;
    });

    _generateSystemAlerts();
  }

  /// Raises real, rule-based notifications (low stock etc) after data has
  /// finished loading. Respects the "Enable Notifications" setting and
  /// de-duplicates so the same alert isn't repeated on every refresh.
  Future<void> _generateSystemAlerts() async {
    await NotificationCenter.instance.checkLowStock(
      label: 'Rice',
      quantity: currentRiceStock,
      threshold: 50,
    );
    await NotificationCenter.instance.checkLowStock(
      label: 'Wheat',
      quantity: currentWheatStock,
      threshold: 50,
    );

    // Khata alerts: large outstanding balances and old receivables.
    for (final party in parties) {
      final partyId = party['id']?.toString() ?? '';
      final partyName = party['name']?.toString() ?? 'Party';
      if (partyId.isEmpty) continue;

      var balance = 0.0;
      final opening = _toDouble(party['openingBalance']);
      final openingType = party['openingBalanceType']?.toString();
      if (openingType == 'You Give') balance += opening;
      if (openingType == 'You Take') balance -= opening;

      DateTime? oldestDate;
      final transactions = party['transactions'];
      if (transactions is List) {
        for (final item in transactions) {
          if (item is! Map) continue;
          final amount = _toDouble(item['amount']);
          final type = item['type']?.toString();
          if (type == 'You Give') balance += amount;
          if (type == 'You Take') balance -= amount;

          if (type == 'You Give') {
            final date = DateTime.tryParse(item['date']?.toString() ?? '');
            if (date != null &&
                (oldestDate == null || date.isBefore(oldestDate))) {
              oldestDate = date;
            }
          }
        }
      }

      await NotificationCenter.instance.checkKhataDue(
        partyName: partyName,
        partyId: partyId,
        balance: balance,
        threshold: 10000,
      );
      await NotificationCenter.instance.checkAgedKhata(
        partyName: partyName,
        partyId: partyId,
        balance: balance,
        oldestDate: oldestDate,
        days: 30,
      );
    }
  }

  // =========================================================
  // SAVE ACCOUNTS
  // =========================================================

  Future<void> logout() async {
    final storage = StorageService.instance;
    await storage.remove('current_user');

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  // =========================================================

  Future<void> saveAccounts() async {
    await AccountRepository().saveRawTransactions(accountTransactions);
  }

  // =========================================================
  // BACKUP / RESTORE
  // =========================================================

  /// All application data that must survive a backup/restore cycle.
  /// Keeping this list in one place prevents newly added modules from being
  /// silently omitted from backups.
  static const List<String> backupStorageKeys = [
    'users',
    'user_credentials',
    'current_user',
    'farmers',
    'farms',
    'farms_data',
    'crops',
    'rice_transactions',
    'wheat_transactions',
    'parties_data',
    'khata_entries',
    'accounts',
    'accounts_data',
    'accounts_transactions',
    'stock',
    'stock_movements',
    'payments',
    'app_notifications',
    'settings_theme_mode',
    'settings_compact_mode',
    'settings_notifications_enabled',
    'settings_language',
    'settings_currency',
    'settings_date_format',
    'settings_business_name',
  ];

  Future<void> createBackup() async {
    final backupJson = await BackupService.instance.createBackup(
      backupStorageKeys,
    );

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Backup Created'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Copy this backup and save it somewhere safe '
                  '(a text file, notes app, etc). You can paste it '
                  'back later using Restore Backup.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      backupJson,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: backupJson));

                if (!dialogContext.mounted) return;

                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('Backup copied to clipboard'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> restoreBackup() async {
    final controller = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Restore Backup'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Paste your backup data below. This will overwrite '
                  'your current farms, rice, wheat, parties and '
                  'accounts data.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: controller,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    hintText: 'Paste backup JSON here',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
                foregroundColor: Colors.white,
              ),
              child: const Text('Restore'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final backupText = controller.text.trim();

    if (backupText.isEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please paste backup data first'),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    final success = await BackupService.instance.restoreBackup(backupText);

    if (!mounted) return;

    if (success) {
      await NotificationCenter.instance.reload();
      await loadDashboardData();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backup restored successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid backup data. Restore failed.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // =========================================================
  // ADD ACCOUNT TRANSACTION
  // =========================================================

  Future<void> addAccountTransaction() async {
    final amountText = accountAmountController.text.trim();
    final note = accountNoteController.text.trim();

    final amount = double.tryParse(amountText);

    if (amount == null || amount <= 0) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount'),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    final transaction = <String, dynamic>{
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'type': accountTransactionType,
      'category': accountCategory,
      'amount': amount,
      'note': note,
      'date': DateTime.now().toIso8601String(),
    };

    setState(() {
      accountTransactions.add(transaction);
    });

    await saveAccounts();

    accountAmountController.clear();
    accountNoteController.clear();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$accountTransactionType added successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // =========================================================
  // DELETE ACCOUNT TRANSACTION
  // =========================================================

  Future<void> deleteAccountTransaction(int index) async {
    final transaction = accountTransactions[index];

    final type = transaction['type']?.toString() ?? 'Transaction';

    final amount = _toDouble(transaction['amount']);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Transaction?'),
          content: Text(
            'Delete $type of Rs. '
            '${amount.toStringAsFixed(0)}?',
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

    setState(() {
      accountTransactions.removeAt(index);
    });

    await saveAccounts();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transaction deleted successfully')),
    );
  }

  // =========================================================
  // EDIT ACCOUNT TRANSACTION
  // =========================================================

  Future<void> editAccountTransaction(int index) async {
    final transaction = accountTransactions[index];

    final editAmountController = TextEditingController(
      text: _toDouble(transaction['amount']).toString(),
    );
    final editNoteController = TextEditingController(
      text: transaction['note']?.toString() ?? '',
    );
    String editType = transaction['type']?.toString() ?? 'Income';
    String editCategory =
        transaction['category']?.toString() ??
        (editType == 'Income'
            ? incomeCategories.first
            : expenseCategories.first);

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final categoryOptions = editType == 'Income'
                ? incomeCategories
                : expenseCategories;

            if (!categoryOptions.contains(editCategory)) {
              editCategory = categoryOptions.first;
            }

            return AlertDialog(
              title: const Text('Edit Transaction'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: editType,
                      decoration: const InputDecoration(
                        labelText: 'Transaction Type',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.swap_horiz),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Income',
                          child: Text('Income - Money Received'),
                        ),
                        DropdownMenuItem(
                          value: 'Expense',
                          child: Text('Expense - Money Spent'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            editType = value;
                            final options = editType == 'Income'
                                ? incomeCategories
                                : expenseCategories;
                            editCategory = options.first;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      initialValue: editCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: categoryOptions
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => editCategory = value);
                        }
                      },
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: editAmountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        prefixText: 'Rs. ',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.money),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: editNoteController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description / Note',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true) return;

    final newAmount = double.tryParse(editAmountController.text.trim());

    if (newAmount == null || newAmount <= 0) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount'),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    setState(() {
      accountTransactions[index]['type'] = editType;
      accountTransactions[index]['category'] = editCategory;
      accountTransactions[index]['amount'] = newAmount;
      accountTransactions[index]['note'] = editNoteController.text.trim();
    });

    await saveAccounts();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Transaction updated successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> openFarmManagement() async {
    if (!_canAccess(1)) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FarmManagementPage()),
    );

    if (!mounted) return;

    await loadDashboardData();

    if (mounted) {
      setState(() {
        selectedIndex = 0;
      });
    }
  }

  // =========================================================
  // OPEN RICE
  // =========================================================

  Future<void> openRiceManagement() async {
    if (!_canAccess(2)) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RiceManagementPage()),
    );

    if (!mounted) return;

    await loadDashboardData();

    if (mounted) {
      setState(() {
        selectedIndex = 0;
      });
    }
  }

  // =========================================================
  // OPEN WHEAT
  // =========================================================

  Future<void> openWheatManagement() async {
    if (!_canAccess(3)) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const WheatManagementPage()),
    );

    if (!mounted) return;

    await loadDashboardData();

    if (mounted) {
      setState(() {
        selectedIndex = 0;
      });
    }
  }

  // =========================================================
  // OPEN PARTIES
  // =========================================================

  Future<void> openPartiesManagement() async {
    if (!_canAccess(4)) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PartiesManagementPage()),
    );

    if (!mounted) return;

    await loadDashboardData();

    if (mounted) {
      setState(() {
        selectedIndex = 0;
      });
    }
  }

  // =========================================================
  // OPEN REPORTS
  // =========================================================

  Future<void> openReports() async {
    if (!_canAccess(7)) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ReportsPage()),
    );

    if (!mounted) return;

    await loadDashboardData();
  }

  // =========================================================
  // OPEN STOCK
  // =========================================================

  Future<void> openStockManagement() async {
    if (!_canAccess(6)) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const StockManagementPage()),
    );

    if (!mounted) return;

    await loadDashboardData();

    if (mounted) {
      setState(() {
        selectedIndex = 0;
      });
    }
  }

  // =========================================================
  // LOGOUT
  // =========================================================

  Future<void> performLogout() async {
    await AuthRepository().logout();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  // =========================================================
  // INIT
  // =========================================================

  @override
  void initState() {
    super.initState();
    loadDashboardData();
  }

  // =========================================================
  // SIDEBAR ITEM
  // =========================================================

  Widget buildSidebarItem(int index) {
    final bool selected = selectedIndex == index;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: ListTile(
          leading: Icon(
            menuIcons[index],
            color: selected ? const Color(0xFF1B5E20) : Colors.white,
          ),
          title: Text(
            menuItems[index],
            style: TextStyle(
              color: selected ? const Color(0xFF1B5E20) : Colors.white,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          onTap: () async {
            if (index == 1) {
              setState(() {
                selectedIndex = index;
              });

              await openFarmManagement();
            } else if (index == 2) {
              setState(() {
                selectedIndex = index;
              });

              await openRiceManagement();
            } else if (index == 3) {
              setState(() {
                selectedIndex = index;
              });

              await openWheatManagement();
            } else if (index == 4) {
              setState(() {
                selectedIndex = index;
              });

              await openPartiesManagement();
            } else {
              setState(() {
                selectedIndex = index;
              });
            }
          },
        ),
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final showPermanentSidebar = Responsive.showPermanentSidebar(context);

    return Scaffold(
      key: _scaffoldKey,
      // On phones/small tablets the sidebar becomes a Drawer, opened via
      // the hamburger button in the top bar, instead of eating ~250px of
      // an already-narrow screen permanently.
      drawer: showPermanentSidebar
          ? null
          : Drawer(child: SafeArea(child: _buildSidebarContent())),
      body: Row(
        children: [
          // ===================================================
          // SIDEBAR (permanent — wide screens only)
          // ===================================================
          if (showPermanentSidebar)
            Material(
              color: const Color(0xFF1B5E20),
              child: SizedBox(width: 250, child: _buildSidebarContent()),
            ),

          // ===================================================
          // MAIN
          // ===================================================
          Expanded(
            child: Column(
              children: [
                _buildTopBar(showPermanentSidebar),
                Expanded(child: _buildMainContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Closes the Drawer after a menu tap, when it's open as a Drawer
  /// (mobile/small tablet). No-op on wide screens where the sidebar is
  /// permanent and there's nothing to close.
  void _closeDrawerIfOpen() {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      _scaffoldKey.currentState?.closeDrawer();
    }
  }

  // =========================================================
  // SIDEBAR CONTENT (shared between the permanent sidebar and Drawer)
  // =========================================================

  Widget _buildSidebarContent() {
    return Column(
      children: [
        const SizedBox(height: 30),

        Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 2,
            ),
          ),
          child: const Icon(Icons.agriculture, size: 42, color: Colors.white),
        ),

        const SizedBox(height: 14),

        const Text(
          'Farmer Management',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 5),

        const Text(
          'Management System',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),

        const SizedBox(height: 30),

        Expanded(
          child: ListView.builder(
            itemCount: accessibleMenuIndices.length,
            itemBuilder: (context, position) {
              final index = accessibleMenuIndices[position];

              return ListTile(
                leading: Icon(
                  menuIcons[index],
                  color: selectedIndex == index
                      ? const Color(0xFF1B5E20)
                      : Colors.white,
                ),
                title: Text(
                  menuItems[index],
                  style: TextStyle(
                    color: selectedIndex == index
                        ? const Color(0xFF1B5E20)
                        : Colors.white,
                    fontWeight: selectedIndex == index
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                selected: selectedIndex == index,
                selectedTileColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                onTap: () async {
                  _closeDrawerIfOpen();

                  if (index == 1) {
                    setState(() {
                      selectedIndex = index;
                    });

                    await openFarmManagement();
                  } else if (index == 2) {
                    setState(() {
                      selectedIndex = index;
                    });

                    await openRiceManagement();
                  } else if (index == 3) {
                    setState(() {
                      selectedIndex = index;
                    });

                    await openWheatManagement();
                  } else if (index == 4) {
                    setState(() {
                      selectedIndex = index;
                    });

                    await openPartiesManagement();
                  } else {
                    setState(() {
                      selectedIndex = index;
                    });
                  }
                },
              );
            },
          ),
        ),

        const Divider(color: Colors.white30),

        ListTile(
          leading: const Icon(Icons.logout, color: Colors.white),
          title: const Text('Logout', style: TextStyle(color: Colors.white)),
          onTap: () async {
            _closeDrawerIfOpen();

            final confirmed = await showDialog<bool>(
              context: context,
              builder: (dialogContext) {
                return AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B5E20),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Logout'),
                    ),
                  ],
                );
              },
            );

            if (confirmed == true) {
              await performLogout();
            }
          },
        ),

        const SizedBox(height: 15),
      ],
    );
  }

  // =========================================================
  // TOP BAR
  // =========================================================

  Widget _buildTopBar(bool showPermanentSidebar) {
    final isNarrow = Responsive.isMobile(context);

    return Container(
      height: 75,
      padding: EdgeInsets.symmetric(horizontal: isNarrow ? 12 : 25),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          // Hamburger — only needed when the sidebar is a Drawer.
          if (!showPermanentSidebar)
            IconButton(
              icon: const Icon(Icons.menu),
              tooltip: 'Menu',
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),

          Expanded(
            child: Text(
              menuItems[selectedIndex],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: isNarrow ? 19 : 25,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const _NotificationBell(),

          const SizedBox(width: 10),

          const CircleAvatar(
            backgroundColor: Color(0xFF1B5E20),
            child: Icon(Icons.person, color: Colors.white),
          ),

          // Hide the role label on very narrow screens — the avatar is
          // enough, and it saves the width the title needs to ellipsize
          // gracefully instead of clipping.
          if (!isNarrow) ...[
            const SizedBox(width: 10),
            Text(
              widget.role,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ],
      ),
    );
  }

  // =========================================================
  // MAIN CONTENT SWITCH
  // =========================================================

  Widget _buildMainContent() {
    switch (selectedIndex) {
      case 0:
        return DashboardContent(
          farmsCount: farms.length,
          totalArea: totalArea,
          totalIncome: totalIncome,
          totalExpense: totalExpense,
          netProfit: netProfit,
          totalParties: totalParties,
          totalReceivable: totalReceivable,
          totalPayable: totalPayable,
          riceStock: currentRiceStock,
          riceProduction: totalRiceFarmProduction,
          ricePurchase: totalRicePurchase,
          riceSale: totalRiceSale,
          ricePurchaseAmount: totalRicePurchaseAmount,
          riceSaleAmount: totalRiceSaleAmount,
          wheatStock: currentWheatStock,
          wheatProduction: totalWheatFarmProduction,
          wheatPurchase: totalWheatPurchase,
          wheatSale: totalWheatSale,
          wheatPurchaseAmount: totalWheatPurchaseAmount,
          wheatSaleAmount: totalWheatSaleAmount,
          riceTransactions: riceTransactions,
          wheatTransactions: wheatTransactions,
          onOpenFarm: openFarmManagement,
          onOpenRice: openRiceManagement,
          onOpenWheat: openWheatManagement,
          onOpenParties: openPartiesManagement,
          accessibleIndices: accessibleMenuIndices,
          isLoading: isLoading,
        );

      case 5:
        if (!_canAccess(5)) return const SizedBox.shrink();
        return AccountsContent(
          transactions: accountTransactions,
          totalIncome: totalAccountIncome,
          totalExpense: totalAccountExpense,
          amountController: accountAmountController,
          noteController: accountNoteController,
          transactionType: accountTransactionType,
          category: accountCategory,
          incomeCategories: incomeCategories,
          expenseCategories: expenseCategories,
          onTypeChanged: (value) {
            setState(() {
              accountTransactionType = value;
              accountCategory = value == 'Income'
                  ? incomeCategories.first
                  : expenseCategories.first;
            });
          },
          onCategoryChanged: (value) {
            setState(() {
              accountCategory = value;
            });
          },
          onAdd: addAccountTransaction,
          onEdit: editAccountTransaction,
          onDelete: deleteAccountTransaction,
        );

      case 8:
        if (!_canAccess(8)) return const SizedBox.shrink();
        return SettingsPage(
          role: widget.role,
          onCreateBackup: createBackup,
          onRestoreBackup: restoreBackup,
          onLogout: () {
            performLogout();
          },
        );

      // These modules are full pages. Returning them here as well as from
      // the drawer keeps desktop and narrow layouts consistent and removes
      // the old "Coming Soon" fallback.
      case 1:
        if (!_canAccess(1)) return const SizedBox.shrink();
        return const FarmManagementPage();
      case 2:
        if (!_canAccess(2)) return const SizedBox.shrink();
        return const RiceManagementPage();
      case 3:
        if (!_canAccess(3)) return const SizedBox.shrink();
        return const WheatManagementPage();
      case 4:
        if (!_canAccess(4)) return const SizedBox.shrink();
        return const PartiesManagementPage();
      case 6:
        if (!_canAccess(6)) return const SizedBox.shrink();
        return const StockManagementPage();
      case 7:
        if (!_canAccess(7)) return const SizedBox.shrink();
        return const ReportsPage();
      default:
        return EmptyState(
          title: 'No module selected',
          message: 'Choose a module from the navigation menu.',
        );
    }
  }

  // =========================================================
  // DISPOSE
  // =========================================================

  @override
  void dispose() {
    accountAmountController.dispose();
    accountNoteController.dispose();

    super.dispose();
  }
}

// =============================================================
// DASHBOARD CONTENT
// =============================================================

// =========================================================
// NOTIFICATION BELL (top bar)
// =========================================================
//
// Real notification dropdown backed by NotificationCenter. Shows an unread
// badge, lists notifications newest-first, lets the user mark a single item
// read (tap) or clear everything, and updates live via AnimatedBuilder.
class _NotificationBell extends StatelessWidget {
  const _NotificationBell();

  IconData _iconFor(String type) {
    switch (type) {
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'reminder':
        return Icons.event_available_outlined;
      default:
        return Icons.info_outline;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'warning':
        return Colors.orange;
      case 'reminder':
        return Colors.blue;
      default:
        return const Color(0xFF1B5E20);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: NotificationCenter.instance,
      builder: (context, _) {
        final center = NotificationCenter.instance;
        final items = center.notifications;
        final unread = center.unreadCount;

        return PopupMenuButton<String>(
          tooltip: 'Notifications',
          offset: const Offset(0, 45),
          constraints: const BoxConstraints(maxWidth: 360, maxHeight: 420),
          itemBuilder: (context) {
            if (items.isEmpty) {
              return [
                const PopupMenuItem<String>(
                  enabled: false,
                  child: Text('No notifications yet'),
                ),
              ];
            }

            return [
              PopupMenuItem<String>(
                enabled: true,
                onTap: () => center.markAllRead(),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Notifications',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Mark all read',
                      style: TextStyle(
                        color: Color(0xFF1B5E20),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              ...items.map(
                (n) => PopupMenuItem<String>(
                  value: n.id,
                  onTap: () => center.markRead(n.id),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(_iconFor(n.type), color: _colorFor(n.type)),
                    title: Text(
                      n.title,
                      style: TextStyle(
                        fontWeight: n.isRead
                            ? FontWeight.normal
                            : FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      n.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ];
          },
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.notifications_none, size: 28),
            ),
          ),
        );
      },
    );
  }
}

class DashboardContent extends StatelessWidget {
  final int farmsCount;
  final double totalArea;

  final double totalIncome;
  final double totalExpense;
  final double netProfit;

  final int totalParties;
  final double totalReceivable;
  final double totalPayable;

  final double riceStock;
  final double riceProduction;
  final double ricePurchase;
  final double riceSale;

  final double ricePurchaseAmount;
  final double riceSaleAmount;

  final double wheatStock;
  final double wheatProduction;
  final double wheatPurchase;
  final double wheatSale;

  final double wheatPurchaseAmount;
  final double wheatSaleAmount;

  final List<Map<String, dynamic>> riceTransactions;
  final List<Map<String, dynamic>> wheatTransactions;

  final VoidCallback onOpenFarm;
  final VoidCallback onOpenRice;
  final VoidCallback onOpenWheat;
  final VoidCallback onOpenParties;

  final List<int> accessibleIndices;

  final bool isLoading;

  const DashboardContent({
    super.key,
    required this.farmsCount,
    required this.totalArea,
    required this.totalIncome,
    required this.totalExpense,
    required this.netProfit,
    required this.totalParties,
    required this.totalReceivable,
    required this.totalPayable,
    required this.riceStock,
    required this.riceProduction,
    required this.ricePurchase,
    required this.riceSale,
    required this.ricePurchaseAmount,
    required this.riceSaleAmount,
    required this.wheatStock,
    required this.wheatProduction,
    required this.wheatPurchase,
    required this.wheatSale,
    required this.wheatPurchaseAmount,
    required this.wheatSaleAmount,
    required this.riceTransactions,
    required this.wheatTransactions,
    required this.onOpenFarm,
    required this.onOpenRice,
    required this.onOpenWheat,
    required this.onOpenParties,
    required this.accessibleIndices,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final recentRiceTransactions = riceTransactions.reversed.take(5).toList();

    final recentWheatTransactions = wheatTransactions.reversed.take(5).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Business Overview',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 20),

          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;

              int crossAxisCount;
              double aspectRatio;

              if (width < 650) {
                crossAxisCount = 1;
                aspectRatio = 3.2;
              } else if (width < 950) {
                crossAxisCount = 2;
                aspectRatio = 2.4;
              } else if (width < 1300) {
                crossAxisCount = 3;
                aspectRatio = 2.0;
              } else {
                crossAxisCount = 4;
                aspectRatio = 1.9;
              }

              return GridView.count(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 18,
                mainAxisSpacing: 18,
                shrinkWrap: true,
                childAspectRatio: aspectRatio,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  SummaryCard(
                    title: 'Total Income',
                    value: 'Rs. ${totalIncome.toStringAsFixed(0)}',
                    icon: Icons.trending_up,
                    color: Colors.green,
                  ),
                  SummaryCard(
                    title: 'Total Expense',
                    value: 'Rs. ${totalExpense.toStringAsFixed(0)}',
                    icon: Icons.trending_down,
                    color: Colors.red,
                  ),
                  SummaryCard(
                    title: netProfit >= 0 ? 'Net Profit' : 'Net Loss',
                    value: 'Rs. ${netProfit.abs().toStringAsFixed(0)}',
                    icon: netProfit >= 0
                        ? Icons.account_balance
                        : Icons.warning,
                    color: netProfit >= 0 ? Colors.blue : Colors.red,
                  ),
                  SummaryCard(
                    title: 'Total Receivable',
                    value: 'Rs. ${totalReceivable.toStringAsFixed(0)}',
                    icon: Icons.call_received,
                    color: Colors.orange,
                  ),
                  SummaryCard(
                    title: 'Total Payable',
                    value: 'Rs. ${totalPayable.toStringAsFixed(0)}',
                    icon: Icons.call_made,
                    color: Colors.red,
                  ),
                  SummaryCard(
                    title: 'Total Parties',
                    value: totalParties.toString(),
                    icon: Icons.people,
                    color: Colors.indigo,
                  ),
                  SummaryCard(
                    title: 'Rice Stock',
                    value: '${riceStock.toStringAsFixed(2)} Maund',
                    icon: Icons.rice_bowl,
                    color: Colors.amber,
                  ),
                  SummaryCard(
                    title: 'Wheat Stock',
                    value: '${wheatStock.toStringAsFixed(2)} Maund',
                    icon: Icons.grass,
                    color: Colors.brown,
                  ),
                  SummaryCard(
                    title: 'Total Farms',
                    value: farmsCount.toString(),
                    icon: Icons.agriculture,
                    color: Colors.teal,
                  ),
                  SummaryCard(
                    title: 'Total Area',
                    value: '${totalArea.toStringAsFixed(1)} Acre',
                    icon: Icons.landscape,
                    color: Colors.purple,
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 35),

          const Text(
            'Parties / Khata Overview',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 20),

          ResponsiveCardRow(
            minCardWidth: 220,
            aspectRatio: 2.6,
            maxColumns: 3,
            children: [
              SummaryCard(
                title: 'Total Parties',
                value: totalParties.toString(),
                icon: Icons.people,
                color: Colors.indigo,
              ),
              SummaryCard(
                title: 'Receivable',
                value: 'Rs. ${totalReceivable.toStringAsFixed(0)}',
                icon: Icons.arrow_downward,
                color: Colors.green,
              ),
              SummaryCard(
                title: 'Payable',
                value: 'Rs. ${totalPayable.toStringAsFixed(0)}',
                icon: Icons.arrow_upward,
                color: Colors.red,
              ),
            ],
          ),

          const SizedBox(height: 15),

          if (accessibleIndices.contains(4))
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: onOpenParties,
                icon: const Icon(Icons.people),
                label: const Text(
                  'Open Parties / Khata',
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20),
                  foregroundColor: Colors.white,
                ),
              ),
            ),

          const SizedBox(height: 35),

          const Text(
            'Rice Overview',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 20),

          ResponsiveCardRow(
            minCardWidth: 200,
            aspectRatio: 2.2,
            maxColumns: 4,
            children: [
              SummaryCard(
                title: 'Farm Production',
                value: '${riceProduction.toStringAsFixed(2)} Maund',
                icon: Icons.agriculture,
                color: Colors.teal,
              ),
              SummaryCard(
                title: 'Rice Purchased',
                value: '${ricePurchase.toStringAsFixed(2)} Maund',
                icon: Icons.shopping_cart,
                color: Colors.orange,
              ),
              SummaryCard(
                title: 'Rice Sold',
                value: '${riceSale.toStringAsFixed(2)} Maund',
                icon: Icons.sell,
                color: Colors.blue,
              ),
              SummaryCard(
                title: 'Current Stock',
                value: '${riceStock.toStringAsFixed(2)} Maund',
                icon: Icons.inventory,
                color: Colors.green,
              ),
            ],
          ),

          const SizedBox(height: 20),

          ResponsiveCardRow(
            minCardWidth: 220,
            aspectRatio: 2.6,
            maxColumns: 2,
            children: [
              SummaryCard(
                title: 'Purchase Amount',
                value: 'Rs. ${ricePurchaseAmount.toStringAsFixed(0)}',
                icon: Icons.money_off,
                color: Colors.red,
              ),
              SummaryCard(
                title: 'Sale Amount',
                value: 'Rs. ${riceSaleAmount.toStringAsFixed(0)}',
                icon: Icons.payments,
                color: Colors.green,
              ),
            ],
          ),

          const SizedBox(height: 35),

          const Text(
            'Wheat Overview',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 20),

          ResponsiveCardRow(
            minCardWidth: 200,
            aspectRatio: 2.2,
            maxColumns: 4,
            children: [
              SummaryCard(
                title: 'Farm Production',
                value: '${wheatProduction.toStringAsFixed(2)} Maund',
                icon: Icons.agriculture,
                color: Colors.teal,
              ),
              SummaryCard(
                title: 'Wheat Purchased',
                value: '${wheatPurchase.toStringAsFixed(2)} Maund',
                icon: Icons.shopping_cart,
                color: Colors.orange,
              ),
              SummaryCard(
                title: 'Wheat Sold',
                value: '${wheatSale.toStringAsFixed(2)} Maund',
                icon: Icons.sell,
                color: Colors.blue,
              ),
              SummaryCard(
                title: 'Current Stock',
                value: '${wheatStock.toStringAsFixed(2)} Maund',
                icon: Icons.inventory,
                color: Colors.brown,
              ),
            ],
          ),

          const SizedBox(height: 20),

          ResponsiveCardRow(
            minCardWidth: 220,
            aspectRatio: 2.6,
            maxColumns: 2,
            children: [
              SummaryCard(
                title: 'Purchase Amount',
                value: 'Rs. ${wheatPurchaseAmount.toStringAsFixed(0)}',
                icon: Icons.money_off,
                color: Colors.red,
              ),
              SummaryCard(
                title: 'Sale Amount',
                value: 'Rs. ${wheatSaleAmount.toStringAsFixed(0)}',
                icon: Icons.payments,
                color: Colors.green,
              ),
            ],
          ),

          const SizedBox(height: 35),

          const Text(
            'Quick Actions',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 20),

          Wrap(
            spacing: 15,
            runSpacing: 15,
            children: [
              if (accessibleIndices.contains(1))
                QuickAction(
                  title: 'Farm Management',
                  icon: Icons.agriculture,
                  color: Colors.green,
                  onTap: onOpenFarm,
                ),
              if (accessibleIndices.contains(2)) ...[
                QuickAction(
                  title: 'Rice Purchase',
                  icon: Icons.shopping_cart,
                  color: Colors.orange,
                  onTap: onOpenRice,
                ),
                QuickAction(
                  title: 'Rice Sale',
                  icon: Icons.sell,
                  color: Colors.blue,
                  onTap: onOpenRice,
                ),
              ],
              if (accessibleIndices.contains(3)) ...[
                QuickAction(
                  title: 'Wheat Purchase',
                  icon: Icons.shopping_cart,
                  color: Colors.brown,
                  onTap: onOpenWheat,
                ),
                QuickAction(
                  title: 'Wheat Sale',
                  icon: Icons.sell,
                  color: Colors.teal,
                  onTap: onOpenWheat,
                ),
              ],
              if (accessibleIndices.contains(4))
                QuickAction(
                  title: 'Parties / Khata',
                  icon: Icons.people,
                  color: const Color(0xFF1B5E20),
                  onTap: onOpenParties,
                ),
            ],
          ),

          const SizedBox(height: 35),

          const Text(
            'Recent Rice Transactions',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 15),

          if (recentRiceTransactions.isEmpty)
            const EmptyTransactionCard(message: 'No rice transactions yet'),

          ...recentRiceTransactions.map((transaction) {
            return TransactionCard(transaction: transaction, crop: 'Rice');
          }),

          const SizedBox(height: 35),

          const Text(
            'Recent Wheat Transactions',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 15),

          if (recentWheatTransactions.isEmpty)
            const EmptyTransactionCard(message: 'No wheat transactions yet'),

          ...recentWheatTransactions.map((transaction) {
            return TransactionCard(transaction: transaction, crop: 'Wheat');
          }),

          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

// =============================================================
// ACCOUNTS CONTENT
// =============================================================

class AccountsContent extends StatefulWidget {
  final List<Map<String, dynamic>> transactions;

  final double totalIncome;
  final double totalExpense;

  final TextEditingController amountController;
  final TextEditingController noteController;

  final String transactionType;
  final ValueChanged<String> onTypeChanged;

  final String category;
  final List<String> incomeCategories;
  final List<String> expenseCategories;
  final ValueChanged<String> onCategoryChanged;

  final VoidCallback onAdd;
  final Future<void> Function(int index) onEdit;
  final Future<void> Function(int index) onDelete;

  const AccountsContent({
    super.key,
    required this.transactions,
    required this.totalIncome,
    required this.totalExpense,
    required this.amountController,
    required this.noteController,
    required this.transactionType,
    required this.onTypeChanged,
    required this.category,
    required this.incomeCategories,
    required this.expenseCategories,
    required this.onCategoryChanged,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<AccountsContent> createState() => _AccountsContentState();
}

class _AccountsContentState extends State<AccountsContent> {
  final TextEditingController _searchController = TextEditingController();
  String _typeFilter = 'All';
  String _dateFilter = 'All';
  DateTime? _customDate;

  double get netBalance => widget.totalIncome - widget.totalExpense;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MapEntry<int, Map<String, dynamic>>> get _filteredTransactions {
    final query = _searchController.text.trim().toLowerCase();
    final now = DateTime.now();

    final filtered = <MapEntry<int, Map<String, dynamic>>>[];

    for (var index = 0; index < widget.transactions.length; index++) {
      final transaction = widget.transactions[index];
      final type = transaction['type']?.toString() ?? 'Income';
      final note = transaction['note']?.toString() ?? '';
      final amount = _accountToDouble(transaction['amount']);
      final date = _parseDate(transaction['date']);

      if (_typeFilter != 'All' && type != _typeFilter) continue;

      if (query.isNotEmpty) {
        final searchable = '$type $note ${amount.toString()}'.toLowerCase();
        if (!searchable.contains(query)) continue;
      }

      if (!_matchesDateFilter(date, now)) continue;

      filtered.add(MapEntry(index, transaction));
    }

    filtered.sort((a, b) {
      final aDate = _parseDate(a.value['date']);
      final bDate = _parseDate(b.value['date']);
      if (aDate == null && bDate == null) return b.key.compareTo(a.key);
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });

    return filtered;
  }

  bool _matchesDateFilter(DateTime? date, DateTime now) {
    if (_dateFilter == 'All') return true;
    if (date == null) return false;

    final day = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);

    switch (_dateFilter) {
      case 'Today':
        return day == today;
      case 'This Week':
        final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        return !day.isBefore(startOfWeek) && !day.isAfter(endOfWeek);
      case 'This Month':
        return date.year == now.year && date.month == now.month;
      case 'Custom Date':
        if (_customDate == null) return true;
        return day ==
            DateTime(_customDate!.year, _customDate!.month, _customDate!.day);
      default:
        return true;
    }
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    final text = value.toString();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  Future<void> _selectCustomDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _customDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked == null) return;

    setState(() {
      _customDate = picked;
      _dateFilter = 'Custom Date';
    });
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _typeFilter = 'All';
      _dateFilter = 'All';
      _customDate = null;
    });
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final filteredTransactions = _filteredTransactions;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Accounts',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Manage income, expenses and account balance',
            style: TextStyle(color: Colors.grey, fontSize: 15),
          ),
          const SizedBox(height: 25),
          ResponsiveCardRow(
            minCardWidth: 220,
            aspectRatio: 2.6,
            maxColumns: 3,
            children: [
              SummaryCard(
                title: 'Total Income',
                value: 'Rs. ${widget.totalIncome.toStringAsFixed(0)}',
                icon: Icons.arrow_downward,
                color: Colors.green,
              ),
              SummaryCard(
                title: 'Total Expense',
                value: 'Rs. ${widget.totalExpense.toStringAsFixed(0)}',
                icon: Icons.arrow_upward,
                color: Colors.red,
              ),
              SummaryCard(
                title: netBalance >= 0 ? 'Net Balance' : 'Net Loss',
                value: 'Rs. ${netBalance.abs().toStringAsFixed(0)}',
                icon: netBalance >= 0 ? Icons.account_balance : Icons.warning,
                color: netBalance >= 0 ? Colors.blue : Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 35),
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
                  DropdownButtonFormField<String>(
                    initialValue: widget.transactionType,
                    decoration: const InputDecoration(
                      labelText: 'Transaction Type',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.swap_horiz),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Income',
                        child: Text('Income - Money Received'),
                      ),
                      DropdownMenuItem(
                        value: 'Expense',
                        child: Text('Expense - Money Spent'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) widget.onTypeChanged(value);
                    },
                  ),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    initialValue:
                        (widget.transactionType == 'Income'
                                ? widget.incomeCategories
                                : widget.expenseCategories)
                            .contains(widget.category)
                        ? widget.category
                        : (widget.transactionType == 'Income'
                              ? widget.incomeCategories.first
                              : widget.expenseCategories.first),
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category),
                    ),
                    items:
                        (widget.transactionType == 'Income'
                                ? widget.incomeCategories
                                : widget.expenseCategories)
                            .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)),
                            )
                            .toList(),
                    onChanged: (value) {
                      if (value != null) widget.onCategoryChanged(value);
                    },
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: widget.amountController,
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
                  TextField(
                    controller: widget.noteController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description / Note',
                      hintText: 'Example: Farm income, fertilizer expense...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.description),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: widget.onAdd,
                      icon: const Icon(Icons.add),
                      label: Text(
                        'Add ${widget.transactionType}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.transactionType == 'Income'
                            ? Colors.green
                            : Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 35),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Account Transaction History',
                  style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                '${filteredTransactions.length} Entries',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Search transactions',
                      hintText: 'Search type, note or amount...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.clear),
                            ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final narrow = constraints.maxWidth < 600;
                      final children = [
                        DropdownButtonFormField<String>(
                          initialValue: _typeFilter,
                          decoration: const InputDecoration(
                            labelText: 'Type',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.filter_list),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'All',
                              child: Text('All Types'),
                            ),
                            DropdownMenuItem(
                              value: 'Income',
                              child: Text('Income Only'),
                            ),
                            DropdownMenuItem(
                              value: 'Expense',
                              child: Text('Expense Only'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _typeFilter = value);
                          },
                        ),
                        DropdownButtonFormField<String>(
                          initialValue: _dateFilter,
                          decoration: const InputDecoration(
                            labelText: 'Date',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'All',
                              child: Text('All Dates'),
                            ),
                            DropdownMenuItem(
                              value: 'Today',
                              child: Text('Today'),
                            ),
                            DropdownMenuItem(
                              value: 'This Week',
                              child: Text('This Week'),
                            ),
                            DropdownMenuItem(
                              value: 'This Month',
                              child: Text('This Month'),
                            ),
                            DropdownMenuItem(
                              value: 'Custom Date',
                              child: Text('Custom Date'),
                            ),
                          ],
                          onChanged: (value) async {
                            if (value == null) return;
                            if (value == 'Custom Date') {
                              await _selectCustomDate();
                            } else {
                              setState(() {
                                _dateFilter = value;
                                _customDate = null;
                              });
                            }
                          },
                        ),
                      ];

                      if (narrow) {
                        return Column(
                          children: [
                            children[0],
                            const SizedBox(height: 12),
                            children[1],
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: children[0]),
                          const SizedBox(width: 12),
                          Expanded(child: children[1]),
                        ],
                      );
                    },
                  ),
                  if (_dateFilter == 'Custom Date' && _customDate != null) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Selected date: ${_formatDate(_customDate!)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                  if (_searchController.text.isNotEmpty ||
                      _typeFilter != 'All' ||
                      _dateFilter != 'All') ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _clearFilters,
                        icon: const Icon(Icons.clear_all),
                        label: const Text('Clear Filters'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),
          if (filteredTransactions.isEmpty)
            Card(
              child: SizedBox(
                width: double.infinity,
                height: 220,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.search_off, size: 65, color: Colors.grey),
                    SizedBox(height: 15),
                    Text(
                      'No transactions match the current filters',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ...filteredTransactions.map((entry) {
            final actualIndex = entry.key;
            final transaction = entry.value;
            final type = transaction['type']?.toString() ?? 'Income';
            final category = transaction['category']?.toString() ?? '';
            final amount = _accountToDouble(transaction['amount']);
            final note = transaction['note']?.toString() ?? '';
            final date = _parseDate(transaction['date']);
            final isIncome = type == 'Income';

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                leading: CircleAvatar(
                  radius: 25,
                  backgroundColor: isIncome
                      ? Colors.green.withValues(alpha: 0.12)
                      : Colors.red.withValues(alpha: 0.12),
                  child: Icon(
                    isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                    color: isIncome ? Colors.green : Colors.red,
                  ),
                ),
                title: Text(
                  category.isNotEmpty ? '$type · $category' : type,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (note.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(note),
                      ),
                    if (date != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _formatDate(date),
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${isIncome ? '+' : '-'} Rs. ${amount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isIncome ? Colors.green : Colors.red,
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'Edit',
                      onPressed: () => widget.onEdit(actualIndex),
                      icon: const Icon(Icons.edit, color: Colors.orange),
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      onPressed: () => widget.onDelete(actualIndex),
                      icon: const Icon(Icons.delete, color: Colors.red),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  static double _accountToDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value != null) return double.tryParse(value.toString()) ?? 0;
    return 0;
  }
}

// =============================================================
// STOCK CONTENT
// =============================================================

class StockContent extends StatelessWidget {
  final double riceStock;
  final double wheatStock;

  final double riceProduction;
  final double wheatProduction;

  final double ricePurchase;
  final double wheatPurchase;

  final double riceSale;
  final double wheatSale;

  const StockContent({
    super.key,
    required this.riceStock,
    required this.wheatStock,
    required this.riceProduction,
    required this.wheatProduction,
    required this.ricePurchase,
    required this.wheatPurchase,
    required this.riceSale,
    required this.wheatSale,
  });

  @override
  Widget build(BuildContext context) {
    final totalStock = riceStock + wheatStock;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Stock Management',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          const Text(
            'Current crop stock and movement',
            style: TextStyle(color: Colors.grey),
          ),

          const SizedBox(height: 25),

          ResponsiveCardRow(
            minCardWidth: 220,
            aspectRatio: 2.6,
            maxColumns: 3,
            children: [
              SummaryCard(
                title: 'Total Stock',
                value: '${totalStock.toStringAsFixed(2)} Maund',
                icon: Icons.inventory,
                color: Colors.green,
              ),
              SummaryCard(
                title: 'Rice Stock',
                value: '${riceStock.toStringAsFixed(2)} Maund',
                icon: Icons.rice_bowl,
                color: Colors.amber,
              ),
              SummaryCard(
                title: 'Wheat Stock',
                value: '${wheatStock.toStringAsFixed(2)} Maund',
                icon: Icons.grass,
                color: Colors.brown,
              ),
            ],
          ),

          const SizedBox(height: 35),

          const Text(
            'Rice Stock Details',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 15),

          ResponsiveCardRow(
            minCardWidth: 220,
            aspectRatio: 2.6,
            maxColumns: 3,
            children: [
              SummaryCard(
                title: 'Farm Production',
                value: '${riceProduction.toStringAsFixed(2)} Maund',
                icon: Icons.agriculture,
                color: Colors.teal,
              ),
              SummaryCard(
                title: 'Purchased',
                value: '${ricePurchase.toStringAsFixed(2)} Maund',
                icon: Icons.shopping_cart,
                color: Colors.orange,
              ),
              SummaryCard(
                title: 'Sold',
                value: '${riceSale.toStringAsFixed(2)} Maund',
                icon: Icons.sell,
                color: Colors.blue,
              ),
            ],
          ),

          const SizedBox(height: 35),

          const Text(
            'Wheat Stock Details',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 15),

          ResponsiveCardRow(
            minCardWidth: 220,
            aspectRatio: 2.6,
            maxColumns: 3,
            children: [
              SummaryCard(
                title: 'Farm Production',
                value: '${wheatProduction.toStringAsFixed(2)} Maund',
                icon: Icons.agriculture,
                color: Colors.teal,
              ),
              SummaryCard(
                title: 'Purchased',
                value: '${wheatPurchase.toStringAsFixed(2)} Maund',
                icon: Icons.shopping_cart,
                color: Colors.orange,
              ),
              SummaryCard(
                title: 'Sold',
                value: '${wheatSale.toStringAsFixed(2)} Maund',
                icon: Icons.sell,
                color: Colors.blue,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================
// REPORTS CONTENT
// =============================================================

class ReportsContent extends StatelessWidget {
  final VoidCallback onOpenReports;

  const ReportsContent({super.key, required this.onOpenReports});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reports',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          const Text(
            'View and generate business reports',
            style: TextStyle(color: Colors.grey),
          ),

          const SizedBox(height: 30),

          Card(
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.bar_chart,
                    size: 60,
                    color: Color(0xFF1B5E20),
                  ),

                  const SizedBox(height: 15),

                  const Text(
                    'Business Reports',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    'Open the reports section to view detailed '
                    'farm, rice, wheat, accounts and business data.',
                    style: TextStyle(color: Colors.grey, fontSize: 15),
                  ),

                  const SizedBox(height: 20),

                  ElevatedButton.icon(
                    onPressed: onOpenReports,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open Reports'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E20),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 25,
                        vertical: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================
// EMPTY TRANSACTION CARD
// =============================================================

class EmptyTransactionCard extends StatelessWidget {
  final String message;

  const EmptyTransactionCard({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        width: double.infinity,
        height: 180,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.receipt_long, size: 50, color: Colors.grey),

              const SizedBox(height: 10),

              Text(
                message,
                style: const TextStyle(fontSize: 17, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================
// TRANSACTION CARD
// =============================================================

class TransactionCard extends StatelessWidget {
  final Map<String, dynamic> transaction;
  final String crop;

  const TransactionCard({
    super.key,
    required this.transaction,
    required this.crop,
  });

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    if (value != null) {
      return double.tryParse(value.toString()) ?? 0;
    }

    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final bool isPurchase = transaction['type'] == 'Purchase';

    final double quantity = _toDouble(transaction['quantity']);

    final double rate = _toDouble(transaction['rate']);

    final double total = _toDouble(transaction['total']);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isPurchase
              ? Colors.orange.withValues(alpha: 0.15)
              : Colors.blue.withValues(alpha: 0.15),
          child: Icon(
            isPurchase ? Icons.shopping_cart : Icons.sell,
            color: isPurchase ? Colors.orange : Colors.blue,
          ),
        ),

        title: Text(
          isPurchase ? '$crop Purchase' : '$crop Sale',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),

        subtitle: Text(
          'Quantity: '
          '${quantity.toStringAsFixed(2)} Maund\n'
          'Rate: Rs. '
          '${rate.toStringAsFixed(0)}',
        ),

        trailing: Text(
          'Rs. ${total.toStringAsFixed(0)}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }
}
