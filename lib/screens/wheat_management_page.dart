import 'package:flutter/material.dart';

import '../models/party_model.dart';
import '../repositories/farm_repository.dart';
import '../repositories/party_repository.dart';
import '../repositories/wheat_repository.dart';
import '../widgets/responsive_card_row.dart';

class WheatManagementPage extends StatefulWidget {
  const WheatManagementPage({super.key});

  @override
  State<WheatManagementPage> createState() => _WheatManagementPageState();
}

class _WheatManagementPageState extends State<WheatManagementPage> {
  final List<Map<String, dynamic>> transactions = [];
  final List<Map<String, dynamic>> farmProduction = [];
  final List<PartyModel> parties = [];

  final TextEditingController quantityController = TextEditingController();
  final TextEditingController rateController = TextEditingController();
  final TextEditingController paymentController = TextEditingController();
  final TextEditingController searchController = TextEditingController();

  String selectedType = 'Purchase';
  String? selectedPartyId;

  String searchQuery = '';
  String historyFilter = 'All';

  // ============================================================
  // CALCULATIONS
  // ============================================================

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  double get totalProductionQuantity {
    double total = 0;

    for (final item in farmProduction) {
      total += _toDouble(item['quantity']);
    }

    return total;
  }

  double get totalPurchaseQuantity {
    double total = 0;

    for (final transaction in transactions) {
      if (transaction['type'] == 'Purchase') {
        total += _toDouble(transaction['quantity']);
      }
    }

    return total;
  }

  double get totalSaleQuantity {
    double total = 0;

    for (final transaction in transactions) {
      if (transaction['type'] == 'Sale') {
        total += _toDouble(transaction['quantity']);
      }
    }

    return total;
  }

  double get currentStock {
    return totalProductionQuantity + totalPurchaseQuantity - totalSaleQuantity;
  }

  double get totalPurchaseAmount {
    double total = 0;

    for (final transaction in transactions) {
      if (transaction['type'] == 'Purchase') {
        total += _toDouble(transaction['total'] ?? transaction['totalAmount']);
      }
    }

    return total;
  }

  double get totalSaleAmount {
    double total = 0;

    for (final transaction in transactions) {
      if (transaction['type'] == 'Sale') {
        total += _toDouble(transaction['total'] ?? transaction['totalAmount']);
      }
    }

    return total;
  }

  double get profitLoss {
    return totalSaleAmount - totalPurchaseAmount;
  }

  // ============================================================
  // SEARCH / FILTER
  // ============================================================

  List<MapEntry<int, Map<String, dynamic>>> get filteredTransactions {
    final entries = transactions.asMap().entries.toList();

    return entries.where((entry) {
      final transaction = entry.value;

      final matchesType =
          historyFilter == 'All' || transaction['type'] == historyFilter;

      if (!matchesType) {
        return false;
      }

      if (searchQuery.isEmpty) {
        return true;
      }

      final query = searchQuery.toLowerCase();

      final quantity = transaction['quantity']?.toString() ?? '';
      final rate = transaction['rate']?.toString() ?? '';
      final date = transaction['date']?.toString() ?? '';
      final partyId = transaction['partyId']?.toString() ?? '';

      final party = _getPartyName(partyId);

      return quantity.toLowerCase().contains(query) ||
          rate.toLowerCase().contains(query) ||
          date.toLowerCase().contains(query) ||
          party.toLowerCase().contains(query);
    }).toList();
  }

  // ============================================================
  // PARTY HELPERS
  // ============================================================

  String _getPartyName(String? partyId) {
    if (partyId == null || partyId.isEmpty) {
      return 'No Party';
    }

    for (final party in parties) {
      if (party.id == partyId) {
        return party.name;
      }
    }

    return 'Unknown Party';
  }

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    loadData();
  }

  // ============================================================
  // LOAD DATA
  // ============================================================

  Future<void> loadData() async {
    final repository = WheatRepository();
    final farmRepository = FarmRepository();
    final partyRepository = PartyRepository();

    try {
      final apiTransactions = await repository.getTransactionsFromApi();
      final loadedTransactions =
          apiTransactions.map((item) => item.toJson()).toList();

      final loadedProduction = <Map<String, dynamic>>[];
      for (final farm in await farmRepository.getFarmRecords()) {
        if ((farm['crop']?.toString() ?? '') != 'Wheat') continue;
        final farmId = farm['id']?.toString() ?? '';
        if (farmId.isEmpty) continue;

        for (final item in await farmRepository.getActivities(farmId)) {
          if (item['activityType'] != 'production') continue;
          loadedProduction.add({
            'farmName': farm['name']?.toString() ?? 'Unknown Farm',
            'farmer': farm['farmerName'] ?? farm['farmer'] ?? 'Unknown',
            'quantity': item['quantity'] ?? 0,
            'rate': item['rate'] ?? 0,
            'totalValue': item['amount'] ?? 0,
            'date': item['date'] ?? '',
          });
        }
      }

      final loadedParties = await partyRepository.getActiveParties();

      if (!mounted) return;

      setState(() {
        transactions
          ..clear()
          ..addAll(loadedTransactions);
        farmProduction
          ..clear()
          ..addAll(loadedProduction);
        parties
          ..clear()
          ..addAll(loadedParties);

        if (selectedPartyId != null &&
            !parties.any((party) => party.id == selectedPartyId)) {
          selectedPartyId = null;
        }
      });
    } catch (e, st) {
      debugPrint('Wheat API load ERROR: $e\n$st');
      if (mounted) {
        _showError('Failed to load Wheat data: $e');
      }
    }
  }

  // ============================================================
  // SAVE DATA
  // ============================================================

  Future<void> saveData() async {}

  // ============================================================
  // ADD TRANSACTION
  // ============================================================

  Future<void> addTransaction() async {
    final quantity = double.tryParse(quantityController.text.trim());

    final rate = double.tryParse(rateController.text.trim());

    if (quantity == null || quantity <= 0) {
      _showError('Please enter a valid quantity.');
      return;
    }

    if (rate == null || rate <= 0) {
      _showError('Please enter a valid rate.');
      return;
    }

    if (parties.isNotEmpty &&
        (selectedPartyId == null || selectedPartyId!.isEmpty)) {
      _showError('Please select a party.');
      return;
    }

    final total = quantity * rate;

    final enteredPayment = double.tryParse(paymentController.text.trim());

    if (enteredPayment != null && enteredPayment < 0) {
      _showError('Payment amount cannot be negative.');
      return;
    }

    final payment = (enteredPayment ?? 0).clamp(0, total).toDouble();

    final remaining = total - payment;

    // ----------------------------------------------------------
    // SALE STOCK CHECK
    // ----------------------------------------------------------

    if (selectedType == 'Sale' && quantity > currentStock) {
      _showError(
        'Available wheat stock is only '
        '${currentStock.toStringAsFixed(2)} Maund.',
      );
      return;
    }

    try {
      final saved = await WheatRepository().createTransactionFromApi(
        partyId: selectedPartyId,
       date: DateTime.now(),
        quantity: quantity,
        rate: rate,
        totalAmount: total,
        transactionType: selectedType,
        paidAmount: selectedType == 'Purchase' ? payment : 0,
        receivedAmount: selectedType == 'Sale' ? payment : 0,
        remainingAmount: remaining,
      );

      setState(() {
        transactions.add(saved.toJson());
      });
    } catch (e) {
      _showError('Failed to save Wheat transaction: $e');
      return;
    }

    quantityController.clear();
    rateController.clear();
    paymentController.clear();

    final addedType = selectedType;

    setState(() {
      selectedPartyId = null;
    });

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Wheat $addedType added successfully.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // ============================================================
  // DELETE TRANSACTION
  // ============================================================

  Future<void> deleteTransaction(int index) async {
    if (index < 0 || index >= transactions.length) {
      return;
    }

    final transaction = transactions[index];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Transaction'),
          content: Text(
            'Are you sure you want to delete this '
            '${transaction['type'] ?? 'wheat'} transaction?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
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

    if (confirmed != true) {
      return;
    }

    final transactionId = transaction['id']?.toString();

    if (transactionId == null || transactionId.isEmpty) {
      _showError('Invalid Wheat transaction ID.');
      return;
    }

    try {
      await WheatRepository().deleteTransactionFromApi(transactionId);
      setState(() {
        transactions.removeAt(index);
      });
    } catch (e) {
      _showError('Failed to delete Wheat transaction: $e');
      return;
    }

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transaction deleted successfully.')),
    );
  }

  // ============================================================
  // EDIT TRANSACTION
  // ============================================================

  Future<void> editTransaction(Map<String, dynamic> transaction) async {
    final quantityController = TextEditingController(
      text: _toDouble(transaction['quantity']).toString(),
    );

    final rateController = TextEditingController(
      text: _toDouble(transaction['rate']).toString(),
    );

    final paymentController = TextEditingController(
      text: _toDouble(
        transaction['type'] == 'Purchase'
            ? transaction['paidAmount']
            : transaction['receivedAmount'],
      ).toString(),
    );

    String dialogSelectedType = transaction['type']?.toString() ?? 'Purchase';

    String? dialogSelectedPartyId = transaction['partyId']?.toString();

    if (dialogSelectedPartyId != null &&
        !parties.any((party) => party.id == dialogSelectedPartyId)) {
      dialogSelectedPartyId = null;
    }

    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final quantity =
                double.tryParse(quantityController.text.trim()) ?? 0;

            final rate = double.tryParse(rateController.text.trim()) ?? 0;

            final total = quantity * rate;

            final payment = double.tryParse(paymentController.text.trim()) ?? 0;

            final remaining = (total - payment)
                .clamp(0, double.infinity)
                .toDouble();

            return AlertDialog(
              title: const Text('Edit Wheat Transaction'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: dialogSelectedType,
                        decoration: const InputDecoration(
                          labelText: 'Transaction Type',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Purchase',
                            child: Text('Wheat Purchase'),
                          ),
                          DropdownMenuItem(
                            value: 'Sale',
                            child: Text('Wheat Sale'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }

                          setDialogState(() {
                            dialogSelectedType = value;
                            paymentController.clear();
                          });
                        },
                      ),

                      const SizedBox(height: 12),

                      if (parties.isNotEmpty)
                        DropdownButtonFormField<String?>(
                          initialValue: dialogSelectedPartyId,
                          decoration: const InputDecoration(
                            labelText: 'Party',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('No Party'),
                            ),
                            ...parties.map(
                              (party) => DropdownMenuItem<String?>(
                                value: party.id,
                                child: Text(
                                  party.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              dialogSelectedPartyId = value;
                            });
                          },
                        ),

                      if (parties.isNotEmpty) const SizedBox(height: 12),

                      TextFormField(
                        controller: quantityController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Quantity',
                          suffixText: 'Maund',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final quantity = double.tryParse(value?.trim() ?? '');

                          if (quantity == null || quantity <= 0) {
                            return 'Enter a valid quantity';
                          }

                          return null;
                        },
                        onChanged: (_) {
                          setDialogState(() {});
                        },
                      ),

                      const SizedBox(height: 12),

                      TextFormField(
                        controller: rateController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Rate per Maund',
                          prefixText: 'Rs. ',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final rate = double.tryParse(value?.trim() ?? '');

                          if (rate == null || rate <= 0) {
                            return 'Enter a valid rate';
                          }

                          return null;
                        },
                        onChanged: (_) {
                          setDialogState(() {});
                        },
                      ),

                      const SizedBox(height: 12),

                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Total: Rs. ${total.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      TextFormField(
                        controller: paymentController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: dialogSelectedType == 'Purchase'
                              ? 'Paid Amount'
                              : 'Received Amount',
                          prefixText: 'Rs. ',
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final payment = double.tryParse(value?.trim() ?? '');

                          if (payment == null || payment < 0) {
                            return 'Enter a valid payment amount';
                          }

                          if (payment > total) {
                            return 'Payment cannot exceed total';
                          }

                          return null;
                        },
                        onChanged: (_) {
                          setDialogState(() {});
                        },
                      ),

                      const SizedBox(height: 12),

                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Remaining: Rs. '
                          '${remaining.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
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
                    if (formKey.currentState?.validate() ?? false) {
                      Navigator.pop(dialogContext, true);
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    // ============================================================
    // IMPORTANT:
    // READ VALUES BEFORE DISPOSING CONTROLLERS
    // ============================================================

    final quantity = double.tryParse(quantityController.text.trim()) ?? 0;

    final rate = double.tryParse(rateController.text.trim()) ?? 0;

    final payment = double.tryParse(paymentController.text.trim()) ?? 0;

    quantityController.dispose();
    rateController.dispose();
    paymentController.dispose();

    if (result != true) {
      return;
    }

    // ============================================================
    // CALCULATE UPDATED VALUES
    // ============================================================

    final total = quantity * rate;

    if (quantity <= 0 || rate <= 0) {
      return;
    }

    if (payment < 0 || payment > total) {
      return;
    }

    final remaining = (total - payment).clamp(0, double.infinity).toDouble();

    // ============================================================
    // STOCK VALIDATION FOR EDIT
    // ============================================================

    double purchaseQuantityExcludingCurrent = 0;
    double saleQuantityExcludingCurrent = 0;

    for (final item in transactions) {
      if (item['id'] == transaction['id']) {
        continue;
      }

      final itemQuantity = _toDouble(item['quantity']);

      if (item['type'] == 'Purchase') {
        purchaseQuantityExcludingCurrent += itemQuantity;
      } else if (item['type'] == 'Sale') {
        saleQuantityExcludingCurrent += itemQuantity;
      }
    }

    final newPurchaseQuantity =
        purchaseQuantityExcludingCurrent +
        (dialogSelectedType == 'Purchase' ? quantity : 0);

    final newSaleQuantity =
        saleQuantityExcludingCurrent +
        (dialogSelectedType == 'Sale' ? quantity : 0);

    final availableStockAfterEdit =
        totalProductionQuantity + newPurchaseQuantity - newSaleQuantity;

    if (availableStockAfterEdit < -0.000001) {
      if (mounted) {
        _showError('Sale quantity cannot exceed available wheat stock.');
      }

      return;
    }

    // ============================================================
    // UPDATE TRANSACTION
    // ============================================================

    final updatedTransaction = Map<String, dynamic>.from(transaction);

    updatedTransaction['type'] = dialogSelectedType;
    updatedTransaction['quantity'] = quantity;
    updatedTransaction['rate'] = rate;
    updatedTransaction['total'] = total;
    updatedTransaction['totalAmount'] = total;
    updatedTransaction['partyId'] = dialogSelectedPartyId;

    updatedTransaction['paidAmount'] = dialogSelectedType == 'Purchase'
        ? payment
        : 0.0;

    updatedTransaction['receivedAmount'] = dialogSelectedType == 'Sale'
        ? payment
        : 0.0;

    updatedTransaction['remainingAmount'] = remaining;

    updatedTransaction['date'] =
        transaction['date'] ?? DateTime.now().toIso8601String();

    final index = transactions.indexWhere(
      (item) => item['id'] == transaction['id'],
    );

    if (index < 0) {
      return;
    }

    setState(() {
      transactions[index] = updatedTransaction;
    });

    await saveData();

    // ============================================================
    // STEP 1.6 - SYNC UPDATED WHEAT TRANSACTION WITH PARTY KHATA
    //
    // syncCropTransaction first removes the old auto-entry
    // from every party and then creates the updated one.
    // This also handles:
    // - Party changed
    // - Purchase changed to Sale
    // - Sale changed to Purchase
    // - Amount/payment changed
    // - Transaction fully paid
    // - Party removed
    // ============================================================

    final transactionId =
        updatedTransaction['id']?.toString() ??
        transaction['id']?.toString() ??
        '';

    final transactionDate =
        DateTime.tryParse(updatedTransaction['date']?.toString() ?? '') ??
        DateTime.now();

    await PartyRepository().syncCropTransaction(
      partyId: dialogSelectedPartyId,
      transactionId: transactionId,
      crop: 'Wheat',
      type: dialogSelectedType,
      date: transactionDate,
      totalAmount: total,
      remainingAmount: remaining,
      quantity: quantity,
      rate: rate,
    );

    await loadData();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Wheat transaction updated successfully.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // ============================================================
  // ERROR MESSAGE
  // ============================================================

  void _showError(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    quantityController.dispose();
    rateController.dispose();
    paymentController.dispose();
    searchController.dispose();

    super.dispose();
  }

  // ============================================================
  // SUMMARY CARD
  // ============================================================

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
                  const SizedBox(height: 5),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
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

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wheat Management'),
        backgroundColor: Colors.brown,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Wheat Management',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 25),

            // ==================================================
            // STOCK SUMMARY
            // ==================================================
            ResponsiveCardRow(
              minCardWidth: 200,
              aspectRatio: 2.4,
              maxColumns: 4,
              children: [
                summaryCard(
                  title: 'Current Stock',
                  value: '${currentStock.toStringAsFixed(2)} Maund',
                  icon: Icons.inventory,
                  color: Colors.brown,
                ),
                summaryCard(
                  title: 'Farm Production',
                  value: '${totalProductionQuantity.toStringAsFixed(2)} Maund',
                  icon: Icons.agriculture,
                  color: Colors.teal,
                ),
                summaryCard(
                  title: 'Purchased',
                  value: '${totalPurchaseQuantity.toStringAsFixed(2)} Maund',
                  icon: Icons.shopping_cart,
                  color: Colors.orange,
                ),
                summaryCard(
                  title: 'Sold',
                  value: '${totalSaleQuantity.toStringAsFixed(2)} Maund',
                  icon: Icons.sell,
                  color: Colors.blue,
                ),
              ],
            ),

            const SizedBox(height: 35),

            // ==================================================
            // ADD TRANSACTION
            // ==================================================
            const Text(
              'Add Wheat Transaction',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Transaction Type',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.swap_horiz),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Purchase',
                          child: Text('Wheat Purchase'),
                        ),
                        DropdownMenuItem(
                          value: 'Sale',
                          child: Text('Wheat Sale'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }

                        setState(() {
                          selectedType = value;
                          paymentController.clear();
                        });
                      },
                    ),

                    const SizedBox(height: 15),

                    if (parties.isNotEmpty)
                      DropdownButtonFormField<String>(
                        initialValue: selectedPartyId,
                        decoration: const InputDecoration(
                          labelText: 'Party',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                        items: parties.map((party) {
                          return DropdownMenuItem<String>(
                            value: party.id,
                            child: Text(
                              party.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedPartyId = value;
                          });
                        },
                      ),

                    if (parties.isNotEmpty) const SizedBox(height: 15),

                    TextField(
                      controller: quantityController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        hintText: 'Example: 100',
                        suffixText: 'Maund',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.scale),
                      ),
                    ),

                    const SizedBox(height: 15),

                    TextField(
                      controller: rateController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Rate per Maund',
                        hintText: 'Example: 12000',
                        prefixText: 'Rs. ',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.money),
                      ),
                    ),

                    const SizedBox(height: 15),

                    TextField(
                      controller: paymentController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: selectedType == 'Purchase'
                            ? 'Paid Amount'
                            : 'Received Amount',
                        hintText: 'Example: 50000',
                        prefixText: 'Rs. ',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.payments),
                      ),
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: addTransaction,
                        icon: const Icon(Icons.add),
                        label: Text(
                          selectedType == 'Purchase'
                              ? 'Add Wheat Purchase'
                              : 'Add Wheat Sale',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 35),

            // ==================================================
            // FARM PRODUCTION
            // ==================================================
            const Text(
              'Wheat Produced From Farms',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 15),

            if (farmProduction.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(30),
                  child: Center(
                    child: Column(
                      children: const [
                        Icon(Icons.agriculture, size: 50, color: Colors.grey),
                        SizedBox(height: 10),
                        Text(
                          'No wheat production recorded from farms',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            ...farmProduction.map((production) {
              final quantity = _toDouble(production['quantity']);

              final rate = _toDouble(production['rate']);

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.brown,
                    child: Icon(Icons.agriculture, color: Colors.white),
                  ),
                  title: Text(
                    production['farmName']?.toString() ?? 'Farm',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Farmer: '
                    '${production['farmer']}\n'
                    'Quantity: '
                    '${quantity.toStringAsFixed(2)} Maund\n'
                    'Estimated Rate: Rs. '
                    '${rate.toStringAsFixed(0)}',
                  ),
                  trailing: const Text(
                    'PRODUCTION',
                    style: TextStyle(
                      color: Colors.brown,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(height: 35),

            // ==================================================
            // FINANCIAL SUMMARY
            // ==================================================
            const Text(
              'Financial Summary',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 15),

            ResponsiveCardRow(
              minCardWidth: 220,
              aspectRatio: 2.4,
              maxColumns: 3,
              children: [
                summaryCard(
                  title: 'Purchase Amount',
                  value: 'Rs. ${totalPurchaseAmount.toStringAsFixed(0)}',
                  icon: Icons.shopping_cart,
                  color: Colors.orange,
                ),
                summaryCard(
                  title: 'Sale Amount',
                  value: 'Rs. ${totalSaleAmount.toStringAsFixed(0)}',
                  icon: Icons.sell,
                  color: Colors.blue,
                ),
                summaryCard(
                  title: profitLoss >= 0 ? 'Profit' : 'Loss',
                  value: 'Rs. ${profitLoss.abs().toStringAsFixed(0)}',
                  icon: profitLoss >= 0
                      ? Icons.trending_up
                      : Icons.trending_down,
                  color: profitLoss >= 0 ? Colors.green : Colors.red,
                ),
              ],
            ),

            const SizedBox(height: 35),

            // ==================================================
            // TRANSACTION HISTORY
            // ==================================================
            const Text(
              'Wheat Transaction History',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: searchController,
              onChanged: (value) {
                setState(() {
                  searchQuery = value.trim();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search by party, quantity, rate or date...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          searchController.clear();

                          setState(() {
                            searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            Wrap(
              spacing: 10,
              children: ['All', 'Purchase', 'Sale'].map((type) {
                final selected = historyFilter == type;

                return ChoiceChip(
                  label: Text(type),
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      historyFilter = type;
                    });
                  },
                  selectedColor: const Color(0xFF1B5E20),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : Colors.black87,
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            if (filteredTransactions.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.receipt_long,
                          size: 60,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 15),
                        Text(
                          transactions.isEmpty
                              ? 'No wheat transactions yet'
                              : 'No transactions match your search',
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            ...filteredTransactions.map((entry) {
              final index = entry.key;
              final transaction = entry.value;

              final bool isPurchase = transaction['type'] == 'Purchase';

              final double quantity = _toDouble(transaction['quantity']);

              final double rate = _toDouble(transaction['rate']);

              final double total = _toDouble(
                transaction['total'] ?? transaction['totalAmount'],
              );

              final double paid = _toDouble(transaction['paidAmount']);

              final double received = _toDouble(transaction['receivedAmount']);

              final double remaining = _toDouble(
                transaction['remainingAmount'] ??
                    (total - (isPurchase ? paid : received)),
              ).clamp(0, double.infinity);

              final String partyName = _getPartyName(
                transaction['partyId']?.toString(),
              );

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
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
                    isPurchase ? 'Wheat Purchase' : 'Wheat Sale',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),

                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Party: $partyName\n'
                      'Quantity: '
                      '${quantity.toStringAsFixed(2)} Maund\n'
                      'Rate: Rs. '
                      '${rate.toStringAsFixed(0)}\n'
                      'Total: Rs. '
                      '${total.toStringAsFixed(0)}\n'
                      '${isPurchase ? 'Paid' : 'Received'}: '
                      'Rs. '
                      '${(isPurchase ? paid : received).toStringAsFixed(0)}\n'
                      'Remaining: Rs. '
                      '${remaining.toStringAsFixed(0)}',
                    ),
                  ),

                  trailing: Wrap(
                    spacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      IconButton(
                        tooltip: 'Edit',
                        onPressed: () {
                          editTransaction(transaction);
                        },
                        icon: const Icon(Icons.edit, color: Colors.blue),
                      ),
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
            }),
          ],
        ),
      ),
    );
  }
}
