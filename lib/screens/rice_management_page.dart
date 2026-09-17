import 'package:flutter/material.dart';

import '../models/party_model.dart';
import '../repositories/farm_repository.dart';
import '../repositories/party_repository.dart';
import '../repositories/rice_repository.dart';
import '../widgets/responsive_card_row.dart';

class RiceManagementPage extends StatefulWidget {
  const RiceManagementPage({super.key});

  @override
  State<RiceManagementPage> createState() => _RiceManagementPageState();
}

class _RiceManagementPageState extends State<RiceManagementPage> {
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

  // =====================================================
  // PARTY
  // =====================================================

  String getPartyName(String? partyId) {
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

  Future<void> loadParties() async {
    try {
      final loadedParties = await PartyRepository().getActiveParties();

      if (!mounted) {
        return;
      }

      setState(() {
        parties
          ..clear()
          ..addAll(loadedParties);

        if (selectedPartyId != null &&
            !parties.any((party) => party.id == selectedPartyId)) {
          selectedPartyId = null;
        }
      });
    } catch (e) {
      debugPrint('Error loading parties: $e');
    }
  }

  // =====================================================
  // CALCULATIONS
  // =====================================================

  double get totalProductionQuantity {
    double total = 0;

    for (final item in farmProduction) {
      final quantity = item['quantity'];

      if (quantity is num) {
        total += quantity.toDouble();
      }
    }

    return total;
  }

  double get totalPurchaseQuantity {
    double total = 0;

    for (final transaction in transactions) {
      if (transaction['type'] == 'Purchase') {
        final quantity = transaction['quantity'];

        if (quantity is num) {
          total += quantity.toDouble();
        }
      }
    }

    return total;
  }

  double get totalSaleQuantity {
    double total = 0;

    for (final transaction in transactions) {
      if (transaction['type'] == 'Sale') {
        final quantity = transaction['quantity'];

        if (quantity is num) {
          total += quantity.toDouble();
        }
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
        final amount = (transaction['total'] as num?)?.toDouble() ?? 0;

        total += amount;
      }
    }

    return total;
  }

  double get totalSaleAmount {
    double total = 0;

    for (final transaction in transactions) {
      if (transaction['type'] == 'Sale') {
        final amount = (transaction['total'] as num?)?.toDouble() ?? 0;

        total += amount;
      }
    }

    return total;
  }

  // =====================================================
  // PURCHASE / SALE ACCOUNTING
  // =====================================================

  double get totalPurchasePaid {
    double total = 0;

    for (final transaction in transactions) {
      if (transaction['type'] == 'Purchase') {
        total += (transaction['paidAmount'] as num?)?.toDouble() ?? 0;
      }
    }

    return total;
  }

  double get totalPurchaseRemaining {
    double total = 0;

    for (final transaction in transactions) {
      if (transaction['type'] == 'Purchase') {
        total += (transaction['remainingAmount'] as num?)?.toDouble() ?? 0;
      }
    }

    return total;
  }

  double get totalSaleReceived {
    double total = 0;

    for (final transaction in transactions) {
      if (transaction['type'] == 'Sale') {
        total += (transaction['receivedAmount'] as num?)?.toDouble() ?? 0;
      }
    }

    return total;
  }

  double get totalSaleRemaining {
    double total = 0;

    for (final transaction in transactions) {
      if (transaction['type'] == 'Sale') {
        total += (transaction['remainingAmount'] as num?)?.toDouble() ?? 0;
      }
    }

    return total;
  }

  // =====================================================
  // PROFIT / LOSS
  // =====================================================

  double get profitLoss {
    return totalSaleAmount - totalPurchaseAmount;
  }

  // =====================================================
  // SEARCH / FILTER
  // =====================================================

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

      final partyName = getPartyName(transaction['partyId']?.toString());

      return quantity.contains(query) ||
          rate.contains(query) ||
          date.toLowerCase().contains(query) ||
          partyName.toLowerCase().contains(query);
    }).toList();
  }

  // =====================================================
  // LOAD DATA
  // =====================================================

  @override
  void initState() {
    super.initState();

    loadData();
  }

  Future<void> loadData() async {
    final repository = RiceRepository();
    final farmRepository = FarmRepository();

    final loadedTransactions = repository.getRawTransactions();

    final List<Map<String, dynamic>> loadedProduction = [];

    loadParties();

    try {
      for (final farm in await farmRepository.getFarmRecords()) {
        final farmMap = Map<String, dynamic>.from(farm);

        if (farmMap['crop'] != 'Rice') {
          continue;
        }

        final production = farmMap['production'];

        if (production is! List) {
          continue;
        }

        for (final item in production) {
          if (item is! Map) {
            continue;
          }

          final productionItem = Map<String, dynamic>.from(item);

          loadedProduction.add({
            'farmName': farmMap['name']?.toString() ?? 'Unknown Farm',
            'farmer': farmMap['farmer']?.toString() ?? 'Unknown',
            'quantity': productionItem['quantity'] ?? 0,
            'rate': productionItem['rate'] ?? 0,
            'totalValue': productionItem['totalValue'] ?? 0,
            'date': productionItem['date'] ?? '',
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading rice data: $e');
    }

    // -----------------------------------------------------
    // BACKWARD COMPATIBILITY
    // -----------------------------------------------------

    for (final transaction in loadedTransactions) {
      final type =
          transaction['type']?.toString() ??
          transaction['transactionType']?.toString() ??
          'Purchase';

      final total =
          (transaction['total'] as num?)?.toDouble() ??
          (transaction['totalAmount'] as num?)?.toDouble() ??
          0;

      final paid = (transaction['paidAmount'] as num?)?.toDouble() ?? 0;

      final received = (transaction['receivedAmount'] as num?)?.toDouble() ?? 0;

      transaction['type'] = type;
      transaction['total'] = total;

      transaction['paidAmount'] = paid;
      transaction['receivedAmount'] = received;

      final existingRemaining = transaction['remainingAmount'];

      if (existingRemaining is num) {
        transaction['remainingAmount'] = existingRemaining.toDouble();
      } else {
        transaction['remainingAmount'] = type == 'Purchase'
            ? (total - paid).clamp(0, double.infinity)
            : (total - received).clamp(0, double.infinity);
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      transactions
        ..clear()
        ..addAll(loadedTransactions);

      farmProduction
        ..clear()
        ..addAll(loadedProduction);
    });
  }

  // =====================================================
  // SAVE DATA
  // =====================================================

  Future<void> saveData() async {
    await RiceRepository().saveRawTransactions(transactions);
  }

  // =====================================================
  // ADD PURCHASE / SALE
  // =====================================================

  Future<void> addTransaction() async {
    final quantity = double.tryParse(quantityController.text.trim());

    final rate = double.tryParse(rateController.text.trim());

    final payment = double.tryParse(paymentController.text.trim()) ?? 0;

    if (quantity == null || quantity <= 0 || rate == null || rate <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter valid quantity and rate'),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    if (parties.isNotEmpty && selectedPartyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a party'),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    final total = quantity * rate;

    if (payment < 0 || payment > total) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment/received amount cannot be greater than total'),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    // ===================================================
    // SALE STOCK CHECK
    // ===================================================

    if (selectedType == 'Sale' && quantity > currentStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Available rice stock is only '
            '${currentStock.toStringAsFixed(2)} Maund',
          ),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    final isPurchase = selectedType == 'Purchase';

    final paidAmount = isPurchase ? payment : 0.0;

    final receivedAmount = isPurchase ? 0.0 : payment;

    final remainingAmount = (total - payment)
        .clamp(0, double.infinity)
        .toDouble();

    final transactionId = DateTime.now().millisecondsSinceEpoch.toString();

    final transactionDate = DateTime.now();

    final transaction = <String, dynamic>{
      'id': transactionId,

      'type': selectedType,

      'partyId': selectedPartyId ?? '',

      'quantity': quantity,

      'rate': rate,

      'total': total,

      'totalAmount': total,

      'paidAmount': paidAmount,

      'receivedAmount': receivedAmount,

      'remainingAmount': remainingAmount,

      'date': transactionDate.toIso8601String(),
    };

    setState(() {
      transactions.add(transaction);
    });

    await saveData();

    // ===================================================
    // PARTY KHATA SYNC
    // ===================================================

    await PartyRepository().syncCropTransaction(
      partyId: selectedPartyId,
      transactionId: transactionId,
      crop: 'Rice',
      type: selectedType,
      date: transactionDate,
      totalAmount: total,
      remainingAmount: remainingAmount,
      quantity: quantity,
      rate: rate,
    );

    quantityController.clear();
    rateController.clear();
    paymentController.clear();

    if (!mounted) {
      return;
    }

    setState(() {
      selectedPartyId = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Rice $selectedType added successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // =====================================================
  // DELETE TRANSACTION
  // =====================================================

  Future<void> deleteTransaction(int index) async {
    final transaction = transactions[index];

    final transactionId = transaction['id']?.toString();

    setState(() {
      transactions.removeAt(index);
    });

    await saveData();

    // ===================================================
    // REMOVE FROM PARTY KHATA
    // ===================================================

    if (transactionId != null && transactionId.isNotEmpty) {
      await PartyRepository().removeCropTransactionKhata(
        transactionId: transactionId,
        crop: 'Rice',
      );
    }

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Transaction deleted')));
  }

  // =====================================================
  // EDIT TRANSACTION
  // =====================================================

  Future<void> editTransaction(int index) async {
    final transaction = transactions[index];

    final editQuantityController = TextEditingController(
      text: ((transaction['quantity'] as num?) ?? 0).toString(),
    );

    final editRateController = TextEditingController(
      text: ((transaction['rate'] as num?) ?? 0).toString(),
    );

    final oldIsPurchase = transaction['type'] == 'Purchase';

    final oldPayment = oldIsPurchase
        ? ((transaction['paidAmount'] as num?) ?? 0).toDouble()
        : ((transaction['receivedAmount'] as num?) ?? 0).toDouble();

    final editPaymentController = TextEditingController(
      text: oldPayment.toString(),
    );

    String editType = transaction['type']?.toString() ?? 'Purchase';

    String? editPartyId = transaction['partyId']?.toString();

    if (editPartyId != null && editPartyId.isEmpty) {
      editPartyId = null;
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Rice Transaction'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: editType,
                      decoration: const InputDecoration(
                        labelText: 'Type',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Purchase',
                          child: Text('Purchase'),
                        ),
                        DropdownMenuItem(value: 'Sale', child: Text('Sale')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            editType = value;
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 15),

                    DropdownButtonFormField<String>(
                      initialValue:
                          parties.any((party) => party.id == editPartyId)
                          ? editPartyId
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Party Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      items: parties
                          .map(
                            (party) => DropdownMenuItem<String>(
                              value: party.id,
                              child: Text(
                                party.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          editPartyId = value;
                        });
                      },
                    ),

                    const SizedBox(height: 15),

                    TextField(
                      controller: editQuantityController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Quantity (Maund)',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 15),

                    TextField(
                      controller: editRateController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Rate per Maund',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 15),

                    TextField(
                      controller: editPaymentController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: editType == 'Purchase'
                            ? 'Paid Amount'
                            : 'Received Amount',
                        prefixText: 'Rs. ',
                        border: const OutlineInputBorder(),
                        prefixIcon: Icon(
                          editType == 'Purchase'
                              ? Icons.payments
                              : Icons.account_balance_wallet,
                        ),
                      ),
                    ),
                  ],
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
                    Navigator.pop(dialogContext, true);
                  },
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

    // ===================================================
    // READ VALUES BEFORE DISPOSING
    // ===================================================

    final newQuantity = double.tryParse(editQuantityController.text.trim());

    final newRate = double.tryParse(editRateController.text.trim());

    final newPayment = double.tryParse(editPaymentController.text.trim()) ?? 0;

    editQuantityController.dispose();
    editRateController.dispose();
    editPaymentController.dispose();

    if (saved != true) {
      return;
    }

    // ===================================================
    // VALIDATION
    // ===================================================

    if (newQuantity == null ||
        newQuantity <= 0 ||
        newRate == null ||
        newRate <= 0) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter valid quantity and rate'),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    final newTotal = newQuantity * newRate;

    if (newPayment < 0 || newPayment > newTotal) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment/received amount cannot be greater than total'),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    // ===================================================
    // SALE STOCK CHECK
    // ===================================================

    if (editType == 'Sale') {
      final oldQuantity = ((transaction['quantity'] as num?) ?? 0).toDouble();

      final oldType = transaction['type']?.toString();

      double availableExcludingThis = currentStock;

      if (oldType == 'Sale') {
        availableExcludingThis += oldQuantity;
      }

      if (oldType == 'Purchase') {
        availableExcludingThis -= oldQuantity;
      }

      if (newQuantity > availableExcludingThis) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Available rice stock is only '
              '${availableExcludingThis.toStringAsFixed(2)} Maund',
            ),
            backgroundColor: Colors.red,
          ),
        );

        return;
      }
    }

    // ===================================================
    // NEW ACCOUNTING VALUES
    // ===================================================

    final newIsPurchase = editType == 'Purchase';

    final newPaidAmount = newIsPurchase ? newPayment : 0.0;

    final newReceivedAmount = newIsPurchase ? 0.0 : newPayment;

    final newRemainingAmount = (newTotal - newPayment)
        .clamp(0, double.infinity)
        .toDouble();

    final transactionId =
        transaction['id']?.toString() ??
        DateTime.now().millisecondsSinceEpoch.toString();

    final transactionDate =
        DateTime.tryParse(transaction['date']?.toString() ?? '') ??
        DateTime.now();

    // ===================================================
    // UPDATE RICE TRANSACTION
    // ===================================================

    final updatedTransaction = <String, dynamic>{
      ...transaction,

      'id': transactionId,

      'type': editType,

      'partyId': editPartyId ?? '',

      'quantity': newQuantity,

      'rate': newRate,

      'total': newTotal,

      'totalAmount': newTotal,

      'paidAmount': newPaidAmount,

      'receivedAmount': newReceivedAmount,

      'remainingAmount': newRemainingAmount,

      'date': transaction['date'] ?? transactionDate.toIso8601String(),
    };

    setState(() {
      transactions[index] = updatedTransaction;
    });

    await saveData();

    // ===================================================
    // PARTY KHATA SYNC
    // ===================================================

    await PartyRepository().syncCropTransaction(
      partyId: editPartyId,
      transactionId: transactionId,
      crop: 'Rice',
      type: editType,
      date: transactionDate,
      totalAmount: newTotal,
      remainingAmount: newRemainingAmount,
      quantity: newQuantity,
      rate: newRate,
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Rice transaction updated successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // =====================================================
  // DISPOSE
  // =====================================================

  @override
  void dispose() {
    quantityController.dispose();
    rateController.dispose();
    paymentController.dispose();
    searchController.dispose();

    super.dispose();
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

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rice Management'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            const Text(
              'Rice Management',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 25),

            // =================================================
            // STOCK SUMMARY
            // =================================================
            ResponsiveCardRow(
              minCardWidth: 200,
              aspectRatio: 2.4,
              maxColumns: 4,
              children: [
                summaryCard(
                  title: 'Current Stock',
                  value: '${currentStock.toStringAsFixed(2)} Maund',
                  icon: Icons.inventory,
                  color: Colors.green,
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

            // =================================================
            // ADD TRANSACTION
            // =================================================
            const Text(
              'Add Rice Transaction',
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
                          child: Text('Rice Purchase'),
                        ),
                        DropdownMenuItem(
                          value: 'Sale',
                          child: Text('Rice Sale'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }

                        setState(() {
                          selectedType = value;
                        });
                      },
                    ),

                    const SizedBox(height: 15),

                    DropdownButtonFormField<String>(
                      initialValue:
                          parties.any((party) => party.id == selectedPartyId)
                          ? selectedPartyId
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Party Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      items: parties
                          .map(
                            (party) => DropdownMenuItem<String>(
                              value: party.id,
                              child: Text(
                                party.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedPartyId = value;
                        });
                      },
                    ),

                    if (parties.isEmpty) ...[
                      const SizedBox(height: 8),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'No active parties found. '
                          'You can add this transaction without a party.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                    ],

                    const SizedBox(height: 15),

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
                        prefixIcon: Icon(
                          selectedType == 'Purchase'
                              ? Icons.payments
                              : Icons.account_balance_wallet,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        selectedType == 'Purchase'
                            ? 'Remaining Payable = Total − Paid Amount'
                            : 'Remaining Receivable = Total − Received Amount',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
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
                              ? 'Add Rice Purchase'
                              : 'Add Rice Sale',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 35),

            // =================================================
            // FARM PRODUCTION
            // =================================================
            const Text(
              'Rice Produced From Farms',
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
                          'No rice production recorded from farms',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            ...farmProduction.map((production) {
              final quantity =
                  (production['quantity'] as num?)?.toDouble() ?? 0;

              final rate = (production['rate'] as num?)?.toDouble() ?? 0;

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.green,
                    child: Icon(Icons.agriculture, color: Colors.white),
                  ),
                  title: Text(
                    production['farmName'] ?? 'Farm',
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
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(height: 35),

            // =================================================
            // FINANCIAL SUMMARY
            // =================================================
            const Text(
              'Financial Summary',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 15),

            ResponsiveCardRow(
              minCardWidth: 200,
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
                  title: 'Purchase Remaining',
                  value: 'Rs. ${totalPurchaseRemaining.toStringAsFixed(0)}',
                  icon: Icons.payment,
                  color: Colors.red,
                ),

                summaryCard(
                  title: 'Sale Amount',
                  value: 'Rs. ${totalSaleAmount.toStringAsFixed(0)}',
                  icon: Icons.sell,
                  color: Colors.blue,
                ),

                summaryCard(
                  title: 'Sale Received',
                  value: 'Rs. ${totalSaleReceived.toStringAsFixed(0)}',
                  icon: Icons.account_balance_wallet,
                  color: Colors.teal,
                ),

                summaryCard(
                  title: 'Sale Remaining',
                  value: 'Rs. ${totalSaleRemaining.toStringAsFixed(0)}',
                  icon: Icons.receipt_long,
                  color: Colors.deepOrange,
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

            // =================================================
            // TRANSACTION HISTORY
            // =================================================
            const Text(
              'Rice Transaction History',
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
                              ? 'No rice transactions yet'
                              : 'No transactions match your search',
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
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

              final double quantity = ((transaction['quantity'] as num?) ?? 0)
                  .toDouble();

              final double rate = ((transaction['rate'] as num?) ?? 0)
                  .toDouble();

              final double total =
                  ((transaction['total'] as num?) ??
                          (transaction['totalAmount'] as num?) ??
                          0)
                      .toDouble();

              final double paid = ((transaction['paidAmount'] as num?) ?? 0)
                  .toDouble();

              final double received =
                  ((transaction['receivedAmount'] as num?) ?? 0).toDouble();

              final double remaining =
                  ((transaction['remainingAmount'] as num?) ?? 0).toDouble();

              final partyName = getPartyName(
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
                    isPurchase ? 'Rice Purchase' : 'Rice Sale',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      'Party: $partyName\n'
                      'Quantity: '
                      '${quantity.toStringAsFixed(2)} Maund\n'
                      'Rate: Rs. '
                      '${rate.toStringAsFixed(0)}\n'
                      'Total: Rs. '
                      '${total.toStringAsFixed(0)}\n'
                      '${isPurchase ? 'Paid' : 'Received'}: Rs. '
                      '${(isPurchase ? paid : received).toStringAsFixed(0)}\n'
                      'Remaining: Rs. '
                      '${remaining.toStringAsFixed(0)}',
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Rs. '
                            '${total.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isPurchase ? 'PAYABLE' : 'RECEIVABLE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: remaining > 0 ? Colors.red : Colors.green,
                            ),
                          ),
                        ],
                      ),

                      IconButton(
                        tooltip: 'Edit',
                        onPressed: () {
                          editTransaction(index);
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
