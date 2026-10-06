import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/utils/csv_exporter.dart';
import '../repositories/report_repository.dart';
import '../widgets/responsive_card_row.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  // =====================================================
  // DATA
  // =====================================================

  final List<Map<String, dynamic>> transactions = [];
  final List<Map<String, dynamic>> parties = [];

  bool isLoading = true;

  // =====================================================
  // DATE FILTER
  // =====================================================

  String dateFilter = 'All Time';
  DateTime? customStart;
  DateTime? customEnd;

  static const List<String> dateFilterOptions = [
    'All Time',
    'Today',
    'This Week',
    'This Month',
    'Custom Range',
  ];

  // =====================================================
  // INIT
  // =====================================================

  @override
  void initState() {
    super.initState();
    loadReportData();
  }

  // =====================================================
  // LOAD REPORT DATA
  // =====================================================

  Future<void> loadReportData() async {
    try {
      final reportRepository = ReportRepository();
      final loadedTransactions =
          await reportRepository.getAccountTransactions();
      final loadedParties =
          (await reportRepository.getParties())
              .map((party) => party.toJson())
              .toList();

      if (!mounted) return;

      setState(() {
        transactions
          ..clear()
          ..addAll(loadedTransactions);
        parties
          ..clear()
          ..addAll(loadedParties);
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load report data: $e')),
      );
    }
  }

  // =====================================================
  // DOUBLE CONVERTER
  // =====================================================

  double toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    if (value != null) {
      return double.tryParse(value.toString()) ?? 0;
    }

    return 0;
  }

  // =====================================================
  // DATE FILTERED TRANSACTIONS
  // =====================================================

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    final text = value.toString();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  bool _matchesDateFilter(DateTime? date) {
    if (dateFilter == 'All Time') return true;
    if (date == null) return false;

    final now = DateTime.now();
    final day = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);

    switch (dateFilter) {
      case 'Today':
        return day == today;
      case 'This Week':
        final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        return !day.isBefore(startOfWeek) && !day.isAfter(endOfWeek);
      case 'This Month':
        return date.year == now.year && date.month == now.month;
      case 'Custom Range':
        if (customStart == null || customEnd == null) return true;
        final start = DateTime(
          customStart!.year,
          customStart!.month,
          customStart!.day,
        );
        final end = DateTime(
          customEnd!.year,
          customEnd!.month,
          customEnd!.day,
        );
        return !day.isBefore(start) && !day.isAfter(end);
      default:
        return true;
    }
  }

  List<Map<String, dynamic>> get filteredTransactions {
    if (dateFilter == 'All Time') return transactions;

    return transactions
        .where((t) => _matchesDateFilter(_parseDate(t['date'])))
        .toList();
  }

  String get dateFilterLabel {
    if (dateFilter == 'Custom Range' &&
        customStart != null &&
        customEnd != null) {
      return '${_fmtShort(customStart!)} - ${_fmtShort(customEnd!)}';
    }
    return dateFilter;
  }

  String _fmtShort(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: customStart != null && customEnd != null
          ? DateTimeRange(start: customStart!, end: customEnd!)
          : null,
    );

    if (picked == null) return;

    setState(() {
      customStart = picked.start;
      customEnd = picked.end;
      dateFilter = 'Custom Range';
    });
  }

  // =====================================================
  // TOTAL INCOME
  // =====================================================

  double get totalIncome {
    double total = 0;

    for (final transaction in filteredTransactions) {
      if (transaction['type']?.toString() == 'Income') {
        total += toDouble(transaction['amount']);
      }
    }

    return total;
  }

  // =====================================================
  // TOTAL EXPENSE
  // =====================================================

  double get totalExpense {
    double total = 0;

    for (final transaction in filteredTransactions) {
      if (transaction['type']?.toString() == 'Expense') {
        total += toDouble(transaction['amount']);
      }
    }

    return total;
  }

  // =====================================================
  // NET PROFIT / LOSS
  // =====================================================

  double get netBalance {
    return totalIncome - totalExpense;
  }

  // =====================================================
  // TOTAL RECEIVABLE
  // =====================================================

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

  // =====================================================
  // TOTAL PAYABLE
  // =====================================================

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

  // =====================================================
  // PARTY BALANCE
  // =====================================================

  double getPartyBalance(Map<String, dynamic> party) {
    double balance = 0;

    final openingBalance = toDouble(party['openingBalance']);

    final openingType = party['openingBalanceType']?.toString();

    if (openingType == 'You Give') {
      balance += openingBalance;
    } else if (openingType == 'You Take') {
      balance -= openingBalance;
    }

    final transactionsList = party['transactions'];

    if (transactionsList is List) {
      for (final item in transactionsList) {
        if (item is! Map) {
          continue;
        }

        final transaction = Map<String, dynamic>.from(item);

        final amount = toDouble(transaction['amount']);

        final type = transaction['type']?.toString();

        if (type == 'You Give') {
          balance += amount;
        } else if (type == 'You Take') {
          balance -= amount;
        }
      }
    }

    return balance;
  }

  // =====================================================
  // RICE SALE
  // =====================================================

  double get riceSale {
    double total = 0;

    for (final transaction in filteredTransactions) {
      final type = transaction['type']?.toString();
      final category = transaction['category']?.toString();

      if (type == 'Income' && category == 'Rice Sale') {
        total += toDouble(transaction['amount']);
      }
    }

    return total;
  }

  // =====================================================
  // WHEAT SALE
  // =====================================================

  double get wheatSale {
    double total = 0;

    for (final transaction in filteredTransactions) {
      final type = transaction['type']?.toString();
      final category = transaction['category']?.toString();

      if (type == 'Income' && category == 'Wheat Sale') {
        total += toDouble(transaction['amount']);
      }
    }

    return total;
  }

  // =====================================================
  // FARM INCOME
  // =====================================================

  double get farmIncome {
    double total = 0;

    for (final transaction in filteredTransactions) {
      final type = transaction['type']?.toString();
      final category = transaction['category']?.toString();

      if (type == 'Income' && category == 'Farm Income') {
        total += toDouble(transaction['amount']);
      }
    }

    return total;
  }

  // =====================================================
  // FARM EXPENSE
  // =====================================================

  double get farmExpense {
    double total = 0;

    for (final transaction in filteredTransactions) {
      final type = transaction['type']?.toString();
      final category = transaction['category']?.toString();

      if (type == 'Expense' && category == 'Farm Expense') {
        total += toDouble(transaction['amount']);
      }
    }

    return total;
  }

  // =====================================================
  // RICE PURCHASE
  // =====================================================

  double get ricePurchase {
    double total = 0;

    for (final transaction in filteredTransactions) {
      final type = transaction['type']?.toString();
      final category = transaction['category']?.toString();

      if (type == 'Expense' && category == 'Rice Purchase') {
        total += toDouble(transaction['amount']);
      }
    }

    return total;
  }

  // =====================================================
  // WHEAT PURCHASE
  // =====================================================

  double get wheatPurchase {
    double total = 0;

    for (final transaction in filteredTransactions) {
      final type = transaction['type']?.toString();
      final category = transaction['category']?.toString();

      if (type == 'Expense' && category == 'Wheat Purchase') {
        total += toDouble(transaction['amount']);
      }
    }

    return total;
  }

  // =====================================================
  // CATEGORY TOTAL
  // =====================================================

  double categoryTotal(String category) {
    double total = 0;

    for (final transaction in filteredTransactions) {
      if (transaction['category']?.toString() == category) {
        total += toDouble(transaction['amount']);
      }
    }

    return total;
  }

  // =====================================================
  // MONEY FORMAT
  // =====================================================

  String money(double value) {
    return 'Rs. ${value.toStringAsFixed(0)}';
  }

  // =====================================================
  // CSV REPORT
  // =====================================================

  Future<void> exportCsvReport() async {
    final rows = <List<dynamic>>[
      ['Date', 'Type', 'Category', 'Amount', 'Note'],
      for (final t in filteredTransactions)
        [
          t['date']?.toString() ?? '',
          t['type']?.toString() ?? '',
          t['category']?.toString() ?? '',
          toDouble(t['amount']).toStringAsFixed(2),
          t['note']?.toString() ?? t['description']?.toString() ?? '',
        ],
      [],
      ['Summary', dateFilterLabel, '', '', ''],
      ['Total Income', '', '', totalIncome.toStringAsFixed(2), ''],
      ['Total Expense', '', '', totalExpense.toStringAsFixed(2), ''],
      ['Net Balance', '', '', netBalance.toStringAsFixed(2), ''],
    ];

    if (!mounted) return;
    await CsvExporter.exportAndShow(
      context: context,
      title: 'Export Report as CSV',
      rows: rows,
    );
  }

  // =====================================================
  // PDF REPORT
  // =====================================================

  Future<void> generatePdfReport() async {
    final pdf = pw.Document();

    final incomeTransactions = filteredTransactions
        .where((item) => item['type']?.toString() == 'Income')
        .length;

    final expenseTransactions = filteredTransactions
        .where((item) => item['type']?.toString() == 'Expense')
        .length;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Center(
            child: pw.Text(
              'Farmer Management System',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
          ),

          pw.SizedBox(height: 5),

          pw.Center(
            child: pw.Text(
              'Reports & Analytics',
              style: const pw.TextStyle(fontSize: 16),
            ),
          ),

          pw.SizedBox(height: 5),

          pw.Center(
            child: pw.Text(
              'Period: $dateFilterLabel   |   Generated: '
              '${DateTime.now().day.toString().padLeft(2, '0')}/'
              '${DateTime.now().month.toString().padLeft(2, '0')}/'
              '${DateTime.now().year} '
              '${DateTime.now().hour.toString().padLeft(2, '0')}:'
              '${DateTime.now().minute.toString().padLeft(2, '0')}',
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),

          pw.SizedBox(height: 20),

          pw.Text(
            'Financial Summary',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),

          pw.SizedBox(height: 10),

          pw.TableHelper.fromTextArray(
            headers: ['Report', 'Amount'],
            data: [
              ['Total Income', money(totalIncome)],
              ['Total Expense', money(totalExpense)],
              [
                netBalance >= 0 ? 'Net Profit' : 'Net Loss',
                money(netBalance.abs()),
              ],
            ],
          ),

          pw.SizedBox(height: 25),

          pw.Text(
            'Khata Summary',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),

          pw.SizedBox(height: 10),

          pw.TableHelper.fromTextArray(
            headers: ['Report', 'Value'],
            data: [
              ['Total Parties', parties.length.toString()],
              ['Total Receivable', money(totalReceivable)],
              ['Total Payable', money(totalPayable)],
            ],
          ),

          pw.SizedBox(height: 25),

          pw.Text(
            'Sales Report',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),

          pw.SizedBox(height: 10),

          pw.TableHelper.fromTextArray(
            headers: ['Category', 'Amount'],
            data: [
              ['Rice Sales', money(riceSale)],
              ['Wheat Sales', money(wheatSale)],
              ['Farm Income', money(farmIncome)],
            ],
          ),

          pw.SizedBox(height: 25),

          pw.Text(
            'Purchase & Expense Report',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),

          pw.SizedBox(height: 10),

          pw.TableHelper.fromTextArray(
            headers: ['Category', 'Amount'],
            data: [
              ['Rice Purchase', money(ricePurchase)],
              ['Wheat Purchase', money(wheatPurchase)],
              ['Farm Expense', money(farmExpense)],
              ['Transport', money(categoryTotal('Transport'))],
              ['Labour', money(categoryTotal('Labour'))],
              ['Fertilizer', money(categoryTotal('Fertilizer'))],
              ['Seeds', money(categoryTotal('Seeds'))],
            ],
          ),

          pw.SizedBox(height: 25),

          pw.Text(
            'Account Transaction Summary',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),

          pw.SizedBox(height: 10),

          pw.TableHelper.fromTextArray(
            headers: ['Transaction Type', 'Count'],
            data: [
              ['Total Transactions', filteredTransactions.length.toString()],
              ['Income Transactions', incomeTransactions.toString()],
              ['Expense Transactions', expenseTransactions.toString()],
            ],
          ),

          pw.SizedBox(height: 30),

          pw.Divider(),

          pw.SizedBox(height: 8),

          pw.Center(
            child: pw.Text(
              'Generated by Farmer Management System',
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
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
                      fontSize: 18,
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
  // REPORT ROW
  // =====================================================

  Widget reportRow({
    required String title,
    required double value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: Text(
          money(value),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color,
          ),
        ),
      ),
    );
  }

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Export PDF',
            onPressed: generatePdfReport,
            icon: const Icon(Icons.picture_as_pdf),
          ),
          IconButton(
            tooltip: 'Export CSV',
            onPressed: exportCsvReport,
            icon: const Icon(Icons.table_chart_outlined),
          ),
          IconButton(
            tooltip: 'Refresh Reports',
            onPressed: loadReportData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadReportData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Reports & Analytics',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'View your business income, expenses, profit and khata summary',
                      style: TextStyle(color: Colors.grey, fontSize: 15),
                    ),

                    const SizedBox(height: 25),

                    // =========================================
                    // DATE FILTER
                    // =========================================
                    Row(
                      children: [
                        const Icon(Icons.filter_alt, size: 20, color: Colors.grey),
                        const SizedBox(width: 8),
                        const Text(
                          'Period:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: dateFilterOptions.map((option) {
                              final isSelected = dateFilter == option;

                              return ChoiceChip(
                                label: Text(
                                  option == 'Custom Range' &&
                                          dateFilter == 'Custom Range' &&
                                          customStart != null &&
                                          customEnd != null
                                      ? dateFilterLabel
                                      : option,
                                ),
                                selected: isSelected,
                                selectedColor: const Color(
                                  0xFF1B5E20,
                                ).withValues(alpha: 0.15),
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? const Color(0xFF1B5E20)
                                      : Colors.black87,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                                onSelected: (selected) {
                                  if (!selected) return;

                                  if (option == 'Custom Range') {
                                    pickCustomRange();
                                  } else {
                                    setState(() {
                                      dateFilter = option;
                                    });
                                  }
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // MAIN SUMMARY
                    ResponsiveCardRow(
                      minCardWidth: 220,
                      aspectRatio: 2.6,
                      maxColumns: 3,
                      children: [
                        summaryCard(
                          title: 'Total Income',
                          value: money(totalIncome),
                          icon: Icons.trending_up,
                          color: Colors.green,
                        ),
                        summaryCard(
                          title: 'Total Expense',
                          value: money(totalExpense),
                          icon: Icons.trending_down,
                          color: Colors.red,
                        ),
                        summaryCard(
                          title: netBalance >= 0 ? 'Net Profit' : 'Net Loss',
                          value: money(netBalance.abs()),
                          icon: netBalance >= 0
                              ? Icons.account_balance
                              : Icons.warning,
                          color: netBalance >= 0 ? Colors.blue : Colors.red,
                        ),
                      ],
                    ),

                    const SizedBox(height: 35),

                    // KHATA SUMMARY
                    const Text(
                      'Khata Summary',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 15),

                    ResponsiveCardRow(
                      minCardWidth: 220,
                      aspectRatio: 2.6,
                      maxColumns: 3,
                      children: [
                        summaryCard(
                          title: 'Total Parties',
                          value: parties.length.toString(),
                          icon: Icons.people,
                          color: Colors.blue,
                        ),
                        summaryCard(
                          title: 'Receivable',
                          value: money(totalReceivable),
                          icon: Icons.arrow_downward,
                          color: Colors.green,
                        ),
                        summaryCard(
                          title: 'Payable',
                          value: money(totalPayable),
                          icon: Icons.arrow_upward,
                          color: Colors.red,
                        ),
                      ],
                    ),

                    const SizedBox(height: 35),

                    // SALES REPORT
                    const Text(
                      'Sales Report',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 15),

                    reportRow(
                      title: 'Rice Sales',
                      value: riceSale,
                      icon: Icons.grain,
                      color: Colors.green,
                    ),

                    reportRow(
                      title: 'Wheat Sales',
                      value: wheatSale,
                      icon: Icons.grass,
                      color: Colors.orange,
                    ),

                    reportRow(
                      title: 'Farm Income',
                      value: farmIncome,
                      icon: Icons.agriculture,
                      color: Colors.blue,
                    ),

                    const SizedBox(height: 25),

                    // PURCHASE / EXPENSE REPORT
                    const Text(
                      'Purchase & Expense Report',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 15),

                    reportRow(
                      title: 'Rice Purchase',
                      value: ricePurchase,
                      icon: Icons.shopping_cart,
                      color: Colors.orange,
                    ),

                    reportRow(
                      title: 'Wheat Purchase',
                      value: wheatPurchase,
                      icon: Icons.shopping_bag,
                      color: Colors.deepOrange,
                    ),

                    reportRow(
                      title: 'Farm Expense',
                      value: farmExpense,
                      icon: Icons.agriculture,
                      color: Colors.red,
                    ),

                    reportRow(
                      title: 'Transport',
                      value: categoryTotal('Transport'),
                      icon: Icons.local_shipping,
                      color: Colors.blue,
                    ),

                    reportRow(
                      title: 'Labour',
                      value: categoryTotal('Labour'),
                      icon: Icons.people,
                      color: Colors.purple,
                    ),

                    reportRow(
                      title: 'Fertilizer',
                      value: categoryTotal('Fertilizer'),
                      icon: Icons.eco,
                      color: Colors.green,
                    ),

                    reportRow(
                      title: 'Seeds',
                      value: categoryTotal('Seeds'),
                      icon: Icons.spa,
                      color: Colors.teal,
                    ),

                    const SizedBox(height: 35),

                    // ACCOUNT TRANSACTION SUMMARY
                    const Text(
                      'Account Transaction Summary',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 15),

                    Card(
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.receipt_long,
                                  color: Color(0xFF1B5E20),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Total Transactions',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Text(
                                  filteredTransactions.length.toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),

                            const Divider(height: 30),

                            Row(
                              children: [
                                const Icon(
                                  Icons.arrow_downward,
                                  color: Colors.green,
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text('Income Transactions'),
                                ),
                                Text(incomeTransactionsCount.toString()),
                              ],
                            ),

                            const SizedBox(height: 15),

                            Row(
                              children: [
                                const Icon(
                                  Icons.arrow_upward,
                                  color: Colors.red,
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text('Expense Transactions'),
                                ),
                                Text(expenseTransactionsCount.toString()),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // PDF BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: generatePdfReport,
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text(
                          'Export PDF Report',
                          style: TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B5E20),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // CSV BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: exportCsvReport,
                        icon: const Icon(Icons.table_chart_outlined),
                        label: const Text(
                          'Export CSV (Excel / Sheets)',
                          style: TextStyle(fontSize: 16),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1B5E20),
                          side: const BorderSide(color: Color(0xFF1B5E20)),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // REFRESH BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: loadReportData,
                        icon: const Icon(Icons.refresh),
                        label: const Text(
                          'Refresh Reports',
                          style: TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B5E20),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  // =====================================================
  // TRANSACTION COUNTS
  // =====================================================

  int get incomeTransactionsCount {
    return transactions
        .where((item) => item['type']?.toString() == 'Income')
        .length;
  }

  int get expenseTransactionsCount {
    return transactions
        .where((item) => item['type']?.toString() == 'Expense')
        .length;
  }
}
