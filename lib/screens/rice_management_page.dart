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

  final RiceRepository repository = RiceRepository();

  String selectedType = 'Purchase';
  String? selectedPartyId;

  String searchQuery = '';
  String historyFilter = 'All';

  bool isLoading = true;
  bool isSaving = false;

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
  // HELPERS
  // =====================================================

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _cleanError(Object error) {
    final message = error.toString();

    if (message.startsWith('ApiException: ')) {
      return message.substring('ApiException: '.length);
    }

    return message;
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  Map<String, dynamic> _modelToMap(dynamic transaction) {
    return {
      'id': transaction.id,
      'type': transaction.transactionType,
      'partyId': transaction.partyId,
      'farmerId': transaction.farmerId,
      'quantity': transaction.quantity,
      'rate': transaction.rate,
      'total': transaction.totalAmount,
      'totalAmount': transaction.totalAmount,
      'paidAmount': transaction.paidAmount,
      'receivedAmount': transaction.receivedAmount,
      'remainingAmount': transaction.remainingAmount,
      'date': transaction.date.toIso8601String(),
      'variety': transaction.variety,
      'notes': transaction.notes,
    };
  }

  // =====================================================
  // CALCULATIONS
  // =====================================================

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

  // =====================================================
  // PURCHASE / SALE ACCOUNTING
  // =====================================================

  double get totalPurchasePaid {
    double total = 0;

    for (final transaction in transactions) {
      if (transaction['type'] == 'Purchase') {
        total += _toDouble(transaction['paidAmount']);
      }
    }

    return total;
  }

  double get totalPurchaseRemaining {
    double total = 0;

    for (final transaction in transactions) {
      if (transaction['type'] == 'Purchase') {
        total += _toDouble(transaction['remainingAmount']);
      }
    }

    return total;
  }

  double get totalSaleReceived {
    double total = 0;

    for (final transaction in transactions) {
      if (transaction['type'] == 'Sale') {
        total += _toDouble(transaction['receivedAmount']);
      }
    }

    return total;
  }

  double get totalSaleRemaining {
    double total = 0;

    for (final transaction in transactions) {
      if (transaction['type'] == 'Sale') {
        total += _toDouble(transaction['remainingAmount']);
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
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    await loadParties();

    final List<Map<String, dynamic>> loadedProduction = [];

    try {
      // -------------------------------------------------
      // LOAD RICE TRANSACTIONS FROM API
      // -------------------------------------------------

      final loadedApiTransactions = await repository.getTransactionsFromApi();

      final loadedTransactions = loadedApiTransactions
          .map(_modelToMap)
          .toList();

      // -------------------------------------------------
      // LOAD FARM PRODUCTION
      // -------------------------------------------------

      final farmRepository = FarmRepository();

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
        debugPrint('Error loading rice farm production: $e');
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

        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading rice transactions: $e');

      if (!mounted) {
        return;
      }

      setState(() {
        transactions.clear();
        farmProduction
          ..clear()
          ..addAll(loadedProduction);
        isLoading = false;
      });

      _showErrorSnackBar('Failed to load rice transactions: ${_cleanError(e)}');
    }
  }

  // =====================================================
  // ADD PURCHASE / SALE
  // =====================================================

  Future<void> addTransaction() async {
    if (isSaving) {
      return;
    }

    final quantity = double.tryParse(quantityController.text.trim());

    final rate = double.tryParse(rateController.text.trim());

    final payment = double.tryParse(paymentController.text.trim()) ?? 0;

    if (quantity == null || quantity <= 0 || rate == null || rate <= 0) {
      _showErrorSnackBar('Please enter valid quantity and rate');

      return;
    }

    if (parties.isNotEmpty && selectedPartyId == null) {
      _showErrorSnackBar('Please select a party');

      return;
    }

    final total = quantity * rate;

    if (payment < 0 || payment > total) {
      _showErrorSnackBar(
        'Payment/received amount cannot be greater than total',
      );

      return;
    }

    // ===================================================
    // SALE STOCK CHECK
    // ===================================================

    if (selectedType == 'Sale' && quantity > currentStock) {
      _showErrorSnackBar(
        'Available rice stock is only '
        '${currentStock.toStringAsFixed(2)} Maund',
      );

      return;
    }

    final isPurchase = selectedType == 'Purchase';

    final paidAmount = isPurchase ? payment : 0.0;

    final receivedAmount = isPurchase ? 0.0 : payment;

    final remainingAmount = (total - payment)
        .clamp(0, double.infinity)
        .toDouble();

    final transactionDate = DateTime.now();

    setState(() {
      isSaving = true;
    });

    try {
      // =================================================
      // CREATE THROUGH API
      // =================================================

      final created = await repository.createTransactionFromApi(
        farmerId: null,
        partyId: selectedPartyId,
        date: transactionDate,
        quantity: quantity,
        rate: rate,
        totalAmount: total,
        transactionType: selectedType,
        paidAmount: paidAmount,
        receivedAmount: receivedAmount,
        remainingAmount: remainingAmount,
      );

      final transactionMap = _modelToMap(created);

      if (!mounted) {
        return;
      }

      setState(() {
        transactions.insert(0, transactionMap);
      });

      quantityController.clear();
      rateController.clear();
      paymentController.clear();

      setState(() {
        selectedPartyId = null;
        isSaving = false;
      });

      _showSuccessSnackBar('Rice $selectedType added successfully');
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        isSaving = false;
      });

      _showErrorSnackBar('Failed to add rice transaction: ${_cleanError(e)}');
    }
  }

  // =====================================================
  // DELETE TRANSACTION
  // =====================================================

  Future<void> deleteTransaction(int index) async {
    if (isSaving) {
      return;
    }

    final transaction = transactions[index];

    final transactionId = transaction['id']?.toString();

    if (transactionId == null || transactionId.isEmpty) {
      _showErrorSnackBar('Invalid rice transaction ID');

      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Transaction'),
          content: const Text(
            'Are you sure you want to delete this rice transaction?',
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

    if (confirmed != true) {
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      // =================================================
      // DELETE THROUGH API
      // =================================================

      await repository.deleteTransactionFromApi(transactionId);

      if (!mounted) {
        return;
      }

      setState(() {
        transactions.removeAt(index);
        isSaving = false;
      });

      _showSuccessSnackBar('Transaction deleted successfully');
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        isSaving = false;
      });

      _showErrorSnackBar('Failed to delete transaction: ${_cleanError(e)}');
    }
  }

  // =====================================================
  // EDIT TRANSACTION
  // =====================================================

  Future<void> editTransaction(int index) async {
    if (isSaving) {
      return;
    }

    final transaction = transactions[index];

    final editQuantityController = TextEditingController(
      text: _toDouble(transaction['quantity']).toString(),
    );

    final editRateController = TextEditingController(
      text: _toDouble(transaction['rate']).toString(),
    );

    final oldIsPurchase = transaction['type'] == 'Purchase';

    final oldPayment = oldIsPurchase
        ? _toDouble(transaction['paidAmount'])
        : _toDouble(transaction['receivedAmount']);

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
      _showErrorSnackBar('Please enter valid quantity and rate');

      return;
    }

    final newTotal = newQuantity * newRate;

    if (newPayment < 0 || newPayment > newTotal) {
      _showErrorSnackBar(
        'Payment/received amount cannot be greater than total',
      );

      return;
    }

    // ===================================================
    // SALE STOCK CHECK
    // ===================================================

    if (editType == 'Sale') {
      final oldQuantity = _toDouble(transaction['quantity']);

      final oldType = transaction['type']?.toString();

      double availableExcludingThis = currentStock;

      if (oldType == 'Sale') {
        availableExcludingThis += oldQuantity;
      }

      if (oldType == 'Purchase') {
        availableExcludingThis -= oldQuantity;
      }

      if (newQuantity > availableExcludingThis) {
        _showErrorSnackBar(
          'Available rice stock is only '
          '${availableExcludingThis.toStringAsFixed(2)} Maund',
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

    final transactionId = transaction['id']?.toString();

    if (transactionId == null || transactionId.isEmpty) {
      _showErrorSnackBar('Invalid rice transaction ID');

      return;
    }

    final transactionDate =
        DateTime.tryParse(transaction['date']?.toString() ?? '') ??
        DateTime.now();

    setState(() {
      isSaving = true;
    });

    try {
      // =================================================
      // UPDATE THROUGH API
      // =================================================

      final updated = await repository.updateTransactionFromApi(
        id: transactionId,
        farmerId: transaction['farmerId']?.toString(),
        partyId: editPartyId,
        date: transactionDate,
        quantity: newQuantity,
        rate: newRate,
        totalAmount: newTotal,
        transactionType: editType,
        paidAmount: newPaidAmount,
        receivedAmount: newReceivedAmount,
        remainingAmount: newRemainingAmount,
        variety: transaction['variety']?.toString(),
        notes: transaction['notes']?.toString(),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        transactions[index] = _modelToMap(updated);
        isSaving = false;
      });

      _showSuccessSnackBar('Rice transaction updated successfully');
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        isSaving = false;
      });

      _showErrorSnackBar('Failed to update transaction: ${_cleanError(e)}');
    }
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

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
                        value:
                            '${totalProductionQuantity.toStringAsFixed(2)} Maund',
                        icon: Icons.agriculture,
                        color: Colors.teal,
                      ),
                      summaryCard(
                        title: 'Purchased',
                        value:
                            '${totalPurchaseQuantity.toStringAsFixed(2)} Maund',
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
                            onChanged: isSaving
                                ? null
                                : (value) {
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
                                parties.any(
                                  (party) => party.id == selectedPartyId,
                                )
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
                            onChanged: isSaving
                                ? null
                                : (value) {
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
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
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
                              onPressed: isSaving ? null : addTransaction,
                              icon: isSaving
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
                                isSaving
                                    ? 'Saving...'
                                    : selectedType == 'Purchase'
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
                              Icon(
                                Icons.agriculture,
                                size: 50,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 10),
                              Text(
                                'No rice production recorded from farms',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                ),
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
                        value:
                            'Rs. ${totalPurchaseRemaining.toStringAsFixed(0)}',
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

                    final double quantity = _toDouble(transaction['quantity']);

                    final double rate = _toDouble(transaction['rate']);

                    final double total = _toDouble(
                      transaction['total'] ?? transaction['totalAmount'],
                    );

                    final double paid = _toDouble(transaction['paidAmount']);

                    final double received = _toDouble(
                      transaction['receivedAmount'],
                    );

                    final double remaining = _toDouble(
                      transaction['remainingAmount'],
                    );

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
                                    color: remaining > 0
                                        ? Colors.red
                                        : Colors.green,
                                  ),
                                ),
                              ],
                            ),

                            IconButton(
                              tooltip: 'Edit',
                              onPressed: isSaving
                                  ? null
                                  : () {
                                      editTransaction(index);
                                    },
                              icon: const Icon(Icons.edit, color: Colors.blue),
                            ),

                            IconButton(
                              tooltip: 'Delete',
                              onPressed: isSaving
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
                  }),
                ],
              ),
            ),
    );
  }
}
