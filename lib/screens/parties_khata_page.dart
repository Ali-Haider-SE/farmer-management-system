import 'package:flutter/material.dart';

import '../models/khata_model.dart';
import '../models/party_model.dart';
import '../repositories/party_repository.dart';

class PartiesManagementPage extends StatefulWidget {
  const PartiesManagementPage({super.key});

  @override
  State<PartiesManagementPage> createState() => _PartiesManagementPageState();
}

class _PartiesManagementPageState extends State<PartiesManagementPage> {
  // =====================================================
  // REPOSITORY
  // =====================================================

  final PartyRepository partyRepository = PartyRepository();

  // =====================================================
  // DATA
  // =====================================================

  final List<PartyModel> parties = [];

  // =====================================================
  // PARTY CONTROLLERS
  // =====================================================

  final TextEditingController nameController = TextEditingController();

  final TextEditingController phoneController = TextEditingController();

  final TextEditingController addressController = TextEditingController();

  final TextEditingController openingBalanceController =
      TextEditingController();

  // =====================================================
  // TRANSACTION CONTROLLERS
  // =====================================================

  final TextEditingController transactionAmountController =
      TextEditingController();

  final TextEditingController transactionNoteController =
      TextEditingController();

  // =====================================================
  // SEARCH
  // =====================================================

  final TextEditingController searchController = TextEditingController();

  // =====================================================
  // FILTERS
  // =====================================================

  String openingBalanceType = 'You Give';

  String transactionType = 'You Give';

  String? selectedPartyId;

  String partyTypeFilter = 'All';

  String balanceFilter = 'All';

  DateTime? filterDate;

  // =====================================================
  // STATE
  // =====================================================

  bool isLoading = true;

  String? editingPartyId;

  // =====================================================
  // TOTAL PARTIES
  // =====================================================

  int get totalParties {
    return parties.length;
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

  double getPartyBalance(PartyModel party) {
    double balance = 0;

    if (party.openingBalanceType == 'You Give') {
      balance += party.openingBalance;
    } else {
      balance -= party.openingBalance;
    }

    for (final transaction in party.transactions) {
      balance += transaction.debit;
      balance -= transaction.credit;
    }

    return balance;
  }

  // =====================================================
  // INIT
  // =====================================================

  @override
  void initState() {
    super.initState();

    searchController.addListener(_searchListener);

    loadData();
  }

  // =====================================================
  // SEARCH LISTENER
  // =====================================================

  void _searchListener() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  // =====================================================
  // LOAD DATA
  // =====================================================

  Future<void> loadData() async {
    try {
      final loadedParties = await partyRepository.getParties();

      if (!mounted) {
        return;
      }

      setState(() {
        parties
          ..clear()
          ..addAll(loadedParties);

        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading parties: $e');

      if (!mounted) {
        return;
      }

      setState(() {
        isLoading = false;
      });

      showMessage('Unable to load parties', error: true);
    }
  }

  // =====================================================
  // SAVE PARTY
  // =====================================================

  Future<void> saveParty(PartyModel party) async {
    await partyRepository.save(party);
  }

  // =====================================================
  // MESSAGE
  // =====================================================

  void showMessage(String message, {bool error = false}) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  // =====================================================
  // ADD PARTY
  // =====================================================

  Future<void> addParty() async {
    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    final address = addressController.text.trim();

    final openingText = openingBalanceController.text.trim();

    final openingBalance = double.tryParse(openingText);

    if (name.isEmpty) {
      showMessage('Please enter party name', error: true);
      return;
    }

    if (openingText.isNotEmpty &&
        (openingBalance == null || openingBalance < 0)) {
      showMessage('Please enter a valid opening balance', error: true);
      return;
    }

    final now = DateTime.now();

    final party = PartyModel(
      id: now.microsecondsSinceEpoch.toString(),
      name: name,
      phone: phone,
      address: address,
      partyType: openingBalanceType == 'You Give' ? 'customer' : 'supplier',
      openingBalance: openingBalance ?? 0,
      openingBalanceType: openingBalanceType,
      isActive: true,
      createdAt: now,
      transactions: const [],
    );

    setState(() {
      parties.add(party);
    });

    try {
      await saveParty(party);

      clearPartyForm();

      showMessage('Party added successfully');
    } catch (e) {
      debugPrint('Error saving party: $e');

      setState(() {
        parties.removeWhere((item) => item.id == party.id);
      });

      showMessage('Unable to save party', error: true);
    }
  }

  // =====================================================
  // START EDIT
  // =====================================================

  void startEditParty(PartyModel party) {
    editingPartyId = party.id;

    nameController.text = party.name;
    phoneController.text = party.phone;
    addressController.text = party.address;

    openingBalanceController.text = party.openingBalance == 0
        ? ''
        : party.openingBalance.toStringAsFixed(0);

    openingBalanceType = party.openingBalanceType == 'You Take'
        ? 'You Take'
        : 'You Give';

    setState(() {});

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 300),
      );
    });
  }

  // =====================================================
  // UPDATE PARTY
  // =====================================================

  Future<void> updateParty() async {
    if (editingPartyId == null) {
      return;
    }

    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    final address = addressController.text.trim();

    final openingText = openingBalanceController.text.trim();

    final openingBalance = double.tryParse(openingText);

    if (name.isEmpty) {
      showMessage('Please enter party name', error: true);
      return;
    }

    if (openingText.isNotEmpty &&
        (openingBalance == null || openingBalance < 0)) {
      showMessage('Please enter a valid opening balance', error: true);
      return;
    }

    final index = parties.indexWhere((party) => party.id == editingPartyId);

    if (index == -1) {
      showMessage('Party not found', error: true);
      return;
    }

    final oldParty = parties[index];

    final updatedParty = oldParty.copyWith(
      name: name,
      phone: phone,
      address: address,
      openingBalance: openingBalance ?? 0,
      openingBalanceType: openingBalanceType,
      partyType: openingBalanceType == 'You Give' ? 'customer' : 'supplier',
    );

    setState(() {
      parties[index] = updatedParty;
    });

    try {
      await saveParty(updatedParty);

      clearPartyForm();

      showMessage('Party updated successfully');
    } catch (e) {
      setState(() {
        parties[index] = oldParty;
      });

      showMessage('Unable to update party', error: true);
    }
  }

  // =====================================================
  // CLEAR PARTY FORM
  // =====================================================

  void clearPartyForm() {
    nameController.clear();
    phoneController.clear();
    addressController.clear();
    openingBalanceController.clear();

    editingPartyId = null;
    openingBalanceType = 'You Give';

    if (mounted) {
      setState(() {});
    }
  }

  // =====================================================
  // DELETE PARTY
  // =====================================================

  Future<void> deleteParty(PartyModel party) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Party?'),
          content: Text(
            'Are you sure you want to delete '
            '"${party.name}"?\n\n'
            'All khata transactions of this '
            'party will also be deleted.',
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

    final index = parties.indexWhere((item) => item.id == party.id);

    if (index == -1) {
      return;
    }

    setState(() {
      parties.removeAt(index);

      if (selectedPartyId == party.id) {
        selectedPartyId = null;
      }

      if (editingPartyId == party.id) {
        clearPartyForm();
      }
    });

    try {
      await partyRepository.delete(party.id);

      showMessage('Party deleted successfully');
    } catch (e) {
      setState(() {
        parties.insert(index, party);
      });

      showMessage('Unable to delete party', error: true);
    }
  }

  // =====================================================
  // ADD TRANSACTION
  // =====================================================

  Future<void> addTransaction() async {
    if (selectedPartyId == null) {
      showMessage('Please select a party', error: true);
      return;
    }

    final amount = double.tryParse(transactionAmountController.text.trim());

    final note = transactionNoteController.text.trim();

    if (amount == null || amount <= 0) {
      showMessage('Please enter a valid amount', error: true);
      return;
    }

    final index = parties.indexWhere((party) => party.id == selectedPartyId);

    if (index == -1) {
      showMessage('Party not found', error: true);
      return;
    }

    final party = parties[index];

    final now = DateTime.now();

    final transaction = KhataModel(
      id: now.microsecondsSinceEpoch.toString(),
      partyId: party.id,
      date: now,
      description: note,
      debit: transactionType == 'You Give' ? amount : 0,
      credit: transactionType == 'You Take' ? amount : 0,
      balance: 0,
      reference: null,
    );

    final updatedParty = party.copyWith(
      transactions: [...party.transactions, transaction],
    );

    setState(() {
      parties[index] = updatedParty;
    });

    try {
      await saveParty(updatedParty);

      transactionAmountController.clear();
      transactionNoteController.clear();

      showMessage(
        '$transactionType transaction added '
        'for ${party.name}',
      );
    } catch (e) {
      setState(() {
        parties[index] = party;
      });

      showMessage('Unable to save transaction', error: true);
    }
  }

  // =====================================================
  // EDIT TRANSACTION
  // =====================================================

  Future<void> editTransaction(PartyModel party, int transactionIndex) async {
    if (transactionIndex < 0 || transactionIndex >= party.transactions.length) {
      return;
    }

    final transaction = party.transactions[transactionIndex];

    final amountController = TextEditingController(
      text: transaction.debit > 0
          ? transaction.debit.toStringAsFixed(0)
          : transaction.credit.toStringAsFixed(0),
    );

    final noteController = TextEditingController(text: transaction.description);

    String selectedType = transaction.debit > 0 ? 'You Give' : 'You Take';

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Khata Transaction'),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: selectedType,
                        decoration: const InputDecoration(
                          labelText: 'Transaction Type',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'You Give',
                            child: Text('You Give - Party owes you'),
                          ),
                          DropdownMenuItem(
                            value: 'You Take',
                            child: Text('You Take - You owe party'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }

                          setDialogState(() {
                            selectedType = value;
                          });
                        },
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Amount',
                          prefixText: 'Rs. ',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: noteController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Note',
                          border: OutlineInputBorder(),
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
                    final amount = double.tryParse(
                      amountController.text.trim(),
                    );

                    if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a valid amount'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    Navigator.pop(dialogContext, true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true) {
      amountController.dispose();
      noteController.dispose();
      return;
    }

    final amount = double.tryParse(amountController.text.trim());

    if (amount == null || amount <= 0) {
      amountController.dispose();
      noteController.dispose();
      return;
    }

    final updatedTransaction = transaction.copyWith(
      debit: selectedType == 'You Give' ? amount : 0,
      credit: selectedType == 'You Take' ? amount : 0,
      description: noteController.text.trim(),
    );

    final transactions = List<KhataModel>.from(party.transactions);

    transactions[transactionIndex] = updatedTransaction;

    final updatedParty = party.copyWith(transactions: transactions);

    final index = parties.indexWhere((item) => item.id == party.id);

    if (index != -1) {
      setState(() {
        parties[index] = updatedParty;
      });

      await saveParty(updatedParty);
    }

    amountController.dispose();
    noteController.dispose();

    showMessage('Khata transaction updated successfully');
  }

  // =====================================================
  // DELETE TRANSACTION
  // =====================================================

  Future<void> deleteTransaction(PartyModel party, int transactionIndex) async {
    if (transactionIndex < 0 || transactionIndex >= party.transactions.length) {
      return;
    }

    final transaction = party.transactions[transactionIndex];

    final amount = transaction.debit > 0
        ? transaction.debit
        : transaction.credit;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Transaction?'),
          content: Text(
            'Are you sure you want to delete '
            'this khata entry of '
            'Rs. ${amount.toStringAsFixed(0)}?',
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

    final transactions = List<KhataModel>.from(party.transactions);

    transactions.removeAt(transactionIndex);

    final updatedParty = party.copyWith(transactions: transactions);

    final index = parties.indexWhere((item) => item.id == party.id);

    if (index == -1) {
      return;
    }

    setState(() {
      parties[index] = updatedParty;
    });

    await saveParty(updatedParty);

    showMessage('Khata transaction deleted');
  }

  // =====================================================
  // DATE
  // =====================================================

  String formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');

    final month = date.month.toString().padLeft(2, '0');

    final year = date.year.toString();

    final hour = date.hour == 0
        ? 12
        : date.hour > 12
        ? date.hour - 12
        : date.hour;

    final minute = date.minute.toString().padLeft(2, '0');

    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '$day-$month-$year '
        '$hour:$minute $period';
  }

  bool isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // =====================================================
  // FILTERED PARTIES
  // =====================================================

  List<PartyModel> get filteredParties {
    final query = searchController.text.trim().toLowerCase();

    return parties.where((party) {
      final matchesSearch =
          query.isEmpty ||
          party.name.toLowerCase().contains(query) ||
          party.phone.toLowerCase().contains(query) ||
          party.address.toLowerCase().contains(query);

      if (!matchesSearch) {
        return false;
      }

      // -------------------------------------------------
      // TYPE FILTER
      // -------------------------------------------------

      if (partyTypeFilter != 'All') {
        bool matchesType = false;

        if (party.openingBalanceType == partyTypeFilter) {
          matchesType = true;
        }

        for (final transaction in party.transactions) {
          final type = transaction.debit > 0 ? 'You Give' : 'You Take';

          if (type == partyTypeFilter) {
            matchesType = true;
            break;
          }
        }

        if (!matchesType) {
          return false;
        }
      }

      // -------------------------------------------------
      // BALANCE FILTER
      // -------------------------------------------------

      final balance = getPartyBalance(party);

      if (balanceFilter == 'Receivable' && balance <= 0) {
        return false;
      }

      if (balanceFilter == 'Payable' && balance >= 0) {
        return false;
      }

      // -------------------------------------------------
      // DATE FILTER
      // -------------------------------------------------

      if (filterDate != null) {
        bool matchesDate = isSameDate(party.createdAt, filterDate!);

        for (final transaction in party.transactions) {
          if (isSameDate(transaction.date, filterDate!)) {
            matchesDate = true;
            break;
          }
        }

        if (!matchesDate) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  // =====================================================
  // CLEAR FILTERS
  // =====================================================

  void clearFilters() {
    setState(() {
      partyTypeFilter = 'All';
      balanceFilter = 'All';
      filterDate = null;
    });
  }

  // =====================================================
  // DATE FILTER
  // =====================================================

  Future<void> selectFilterDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: filterDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (selected == null) {
      return;
    }

    setState(() {
      filterDate = selected;
    });
  }

  // =====================================================
  // PARTY DETAILS
  // =====================================================

  void showPartyDetails(PartyModel party) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          child: SizedBox(
            width: 750,
            height: 650,
            child: Padding(
              padding: const EdgeInsets.all(25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 25,
                        backgroundColor: Color(0xFF1B5E20),
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Text(
                          party.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                        },
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Phone: ${party.phone.isEmpty ? 'Not provided' : party.phone}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  if (party.address.isNotEmpty)
                    Text(
                      'Address: ${party.address}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  const SizedBox(height: 20),
                  _buildBalanceBox(party),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Khata History',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        'Opening: Rs. ${party.openingBalance.toStringAsFixed(0)}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(child: _buildTransactionHistory(party)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // =====================================================
  // BALANCE BOX
  // =====================================================

  Widget _buildBalanceBox(PartyModel party) {
    final balance = getPartyBalance(party);

    final isReceivable = balance > 0;

    final isPayable = balance < 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isReceivable
            ? Colors.green.withValues(alpha: 0.08)
            : isPayable
            ? Colors.red.withValues(alpha: 0.08)
            : Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Current Balance', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 5),
          Text(
            'Rs. ${balance.abs().toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
              color: isReceivable
                  ? Colors.green
                  : isPayable
                  ? Colors.red
                  : Colors.grey,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            isReceivable
                ? 'You have to receive'
                : isPayable
                ? 'You have to pay'
                : 'Settled',
            style: TextStyle(
              color: isReceivable
                  ? Colors.green
                  : isPayable
                  ? Colors.red
                  : Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // TRANSACTION HISTORY
  // =====================================================

  Widget _buildTransactionHistory(PartyModel party) {
    if (party.transactions.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 55, color: Colors.grey),
            SizedBox(height: 10),
            Text(
              'No transactions yet',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: party.transactions.length,
      itemBuilder: (context, index) {
        final transaction = party.transactions[index];

        final isGive = transaction.debit > 0;

        final amount = isGive ? transaction.debit : transaction.credit;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isGive
                  ? Colors.green.withValues(alpha: 0.12)
                  : Colors.red.withValues(alpha: 0.12),
              child: Icon(
                isGive ? Icons.arrow_upward : Icons.arrow_downward,
                color: isGive ? Colors.green : Colors.red,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    isGive ? 'You Give' : 'You Take',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  'Rs. ${amount.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isGive ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  transaction.description.isEmpty
                      ? 'No note'
                      : transaction.description,
                ),
                const SizedBox(height: 4),
                Text(
                  formatDate(transaction.date),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'edit') {
                  await editTransaction(party, index);

                  if (mounted) {
                    setState(() {});
                  }
                }

                if (value == 'delete') {
                  await deleteTransaction(party, index);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit),
                      SizedBox(width: 10),
                      Text('Edit'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 10),
                      Text('Delete'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =====================================================
  // PARTY CARD
  // =====================================================

  Widget partyCard(PartyModel party) {
    final balance = getPartyBalance(party);

    final isReceivable = balance > 0;

    final isPayable = balance < 0;

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 600;

            final actions = Wrap(
              spacing: 5,
              children: [
                IconButton(
                  tooltip: 'View Khata',
                  onPressed: () {
                    showPartyDetails(party);
                  },
                  icon: const Icon(Icons.visibility),
                ),
                IconButton(
                  tooltip: 'Edit Party',
                  onPressed: () {
                    startEditParty(party);
                  },
                  icon: const Icon(Icons.edit),
                ),
                IconButton(
                  tooltip: 'Delete Party',
                  onPressed: () {
                    deleteParty(party);
                  },
                  icon: const Icon(Icons.delete, color: Colors.red),
                ),
              ],
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _partyHeader(party),
                  const SizedBox(height: 12),
                  if (party.phone.isNotEmpty)
                    Text(
                      party.phone,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    '${party.transactions.length} transaction(s)',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  _balanceText(balance, isReceivable, isPayable),
                  const SizedBox(height: 10),
                  actions,
                ],
              );
            }

            return Row(
              children: [
                _partyAvatar(),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        party.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      if (party.phone.isNotEmpty)
                        Text(
                          party.phone,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      const SizedBox(height: 5),
                      Text(
                        '${party.transactions.length} transaction(s)',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isReceivable
                            ? 'You have to receive'
                            : isPayable
                            ? 'You have to pay'
                            : 'Settled',
                        style: TextStyle(
                          color: isReceivable
                              ? Colors.green
                              : isPayable
                              ? Colors.red
                              : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Rs. ${balance.abs().toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: isReceivable
                            ? Colors.green
                            : isPayable
                            ? Colors.red
                            : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    actions,
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _partyHeader(PartyModel party) {
    return Row(
      children: [
        _partyAvatar(),
        const SizedBox(width: 15),
        Expanded(
          child: Text(
            party.name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _partyAvatar() {
    return CircleAvatar(
      radius: 27,
      backgroundColor: const Color(0xFF1B5E20).withValues(alpha: 0.10),
      child: const Icon(Icons.person, color: Color(0xFF1B5E20), size: 28),
    );
  }

  Widget _balanceText(double balance, bool isReceivable, bool isPayable) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isReceivable
              ? 'You have to receive'
              : isPayable
              ? 'You have to pay'
              : 'Settled',
          style: TextStyle(
            color: isReceivable
                ? Colors.green
                : isPayable
                ? Colors.red
                : Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Rs. ${balance.abs().toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: isReceivable
                ? Colors.green
                : isPayable
                ? Colors.red
                : Colors.grey,
          ),
        ),
      ],
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
  // SUMMARY
  // =====================================================

  Widget buildSummarySection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        int columns;

        if (constraints.maxWidth >= 1000) {
          columns = 3;
        } else if (constraints.maxWidth >= 600) {
          columns = 2;
        } else {
          columns = 1;
        }

        final cards = [
          summaryCard(
            title: 'Total Parties',
            value: totalParties.toString(),
            icon: Icons.people,
            color: Colors.blue,
          ),
          summaryCard(
            title: 'Total Receivable',
            value: 'Rs. ${totalReceivable.toStringAsFixed(0)}',
            icon: Icons.arrow_downward,
            color: Colors.green,
          ),
          summaryCard(
            title: 'Total Payable',
            value: 'Rs. ${totalPayable.toStringAsFixed(0)}',
            icon: Icons.arrow_upward,
            color: Colors.red,
          ),
        ];

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
            mainAxisExtent: 95,
          ),
          itemBuilder: (context, index) {
            return cards[index];
          },
        );
      },
    );
  }

  // =====================================================
  // FILTER SECTION
  // =====================================================

  Widget buildFilterSection() {
    final hasFilters =
        partyTypeFilter != 'All' ||
        balanceFilter != 'All' ||
        filterDate != null;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Search & Filters',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            LayoutBuilder(
              builder: (context, constraints) {
                final searchField = TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Search name, phone or address...',
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
                );

                final typeDropdown = DropdownButtonFormField<String>(
                  initialValue: partyTypeFilter,
                  decoration: const InputDecoration(
                    labelText: 'Transaction Type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('All Types')),
                    DropdownMenuItem(
                      value: 'You Give',
                      child: Text('You Give'),
                    ),
                    DropdownMenuItem(
                      value: 'You Take',
                      child: Text('You Take'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }

                    setState(() {
                      partyTypeFilter = value;
                    });
                  },
                );

                final balanceDropdown = DropdownButtonFormField<String>(
                  initialValue: balanceFilter,
                  decoration: const InputDecoration(
                    labelText: 'Balance',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('All Balances')),
                    DropdownMenuItem(
                      value: 'Receivable',
                      child: Text('Receivable'),
                    ),
                    DropdownMenuItem(value: 'Payable', child: Text('Payable')),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }

                    setState(() {
                      balanceFilter = value;
                    });
                  },
                );

                final dateButton = OutlinedButton.icon(
                  onPressed: selectFilterDate,
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    filterDate == null
                        ? 'Filter by Date'
                        : '${filterDate!.day.toString().padLeft(2, '0')}-'
                              '${filterDate!.month.toString().padLeft(2, '0')}-'
                              '${filterDate!.year}',
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                  ),
                );

                final clearButton = OutlinedButton.icon(
                  onPressed: hasFilters ? clearFilters : null,
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Clear Filters'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                  ),
                );

                if (constraints.maxWidth < 800) {
                  return Column(
                    children: [
                      searchField,
                      const SizedBox(height: 12),
                      typeDropdown,
                      const SizedBox(height: 12),
                      balanceDropdown,
                      const SizedBox(height: 12),
                      dateButton,
                      const SizedBox(height: 12),
                      clearButton,
                    ],
                  );
                }

                return Column(
                  children: [
                    searchField,
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: typeDropdown),
                        const SizedBox(width: 12),
                        Expanded(child: balanceDropdown),
                        const SizedBox(width: 12),
                        Expanded(child: dateButton),
                        const SizedBox(width: 12),
                        Expanded(child: clearButton),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // PARTY FORM
  // =====================================================

  Widget buildPartyForm() {
    final isEditing = editingPartyId != null;

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Party Name',
                hintText: 'Example: Muhammad Ali',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                hintText: 'Example: 03001234567',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: addressController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Address',
                hintText: 'Party address',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              initialValue: openingBalanceType,
              decoration: const InputDecoration(
                labelText: 'Opening Balance Type',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.swap_horiz),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'You Give',
                  child: Text('You Give - Receivable'),
                ),
                DropdownMenuItem(
                  value: 'You Take',
                  child: Text('You Take - Payable'),
                ),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  openingBalanceType = value;
                });
              },
            ),
            const SizedBox(height: 15),
            TextField(
              controller: openingBalanceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Opening Balance',
                hintText: 'Example: 50000',
                prefixText: 'Rs. ',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.money),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (isEditing)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: clearPartyForm,
                      icon: const Icon(Icons.close),
                      label: const Text('Cancel Edit'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                    ),
                  ),
                if (isEditing) const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isEditing ? updateParty : addParty,
                    icon: Icon(isEditing ? Icons.save : Icons.add),
                    label: Text(isEditing ? 'Update Party' : 'Add Party'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E20),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // TRANSACTION FORM
  // =====================================================

  Widget buildTransactionForm() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: selectedPartyId,
              decoration: const InputDecoration(
                labelText: 'Select Party',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.people),
              ),
              items: parties.map((party) {
                return DropdownMenuItem<String>(
                  value: party.id,
                  child: Text(party.name),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedPartyId = value;
                });
              },
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              initialValue: transactionType,
              decoration: const InputDecoration(
                labelText: 'Transaction Type',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.swap_horiz),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'You Give',
                  child: Text('You Give - Party owes you'),
                ),
                DropdownMenuItem(
                  value: 'You Take',
                  child: Text('You Take - You owe party'),
                ),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  transactionType = value;
                });
              },
            ),
            const SizedBox(height: 15),
            TextField(
              controller: transactionAmountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Amount',
                hintText: 'Example: 25000',
                prefixText: 'Rs. ',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.money),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: transactionNoteController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Note',
                hintText: 'Example: Rice sale, payment received...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: addTransaction,
                icon: const Icon(Icons.add),
                label: const Text(
                  'Add Khata Entry',
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
    );
  }

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parties / Khata'),
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
                  const Text(
                    'Parties / Khata',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Manage customers, suppliers and their khata balances',
                    style: TextStyle(color: Colors.grey, fontSize: 15),
                  ),
                  const SizedBox(height: 25),

                  // SUMMARY
                  buildSummarySection(),

                  const SizedBox(height: 35),

                  // PARTY FORM
                  Text(
                    editingPartyId == null ? 'Add New Party' : 'Edit Party',
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 18),
                  buildPartyForm(),

                  const SizedBox(height: 35),

                  // TRANSACTION
                  const Text(
                    'Add Khata Transaction',
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 18),
                  buildTransactionForm(),

                  const SizedBox(height: 35),

                  // PARTY LIST
                  const Text(
                    'Party List',
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 18),

                  buildFilterSection(),

                  const SizedBox(height: 18),

                  Text(
                    'Showing ${filteredParties.length} '
                    'of ${parties.length} parties',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 12),

                  if (filteredParties.isEmpty)
                    Card(
                      child: SizedBox(
                        width: double.infinity,
                        height: 220,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.people_outline,
                              size: 65,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 15),
                            Text(
                              parties.isEmpty
                                  ? 'No parties added yet'
                                  : 'No party found',
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                            if (parties.isNotEmpty &&
                                (searchController.text.isNotEmpty ||
                                    partyTypeFilter != 'All' ||
                                    balanceFilter != 'All' ||
                                    filterDate != null))
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: TextButton(
                                  onPressed: clearFilters,
                                  child: const Text('Clear Filters'),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                  ...filteredParties.map(partyCard),

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
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    openingBalanceController.dispose();

    transactionAmountController.dispose();

    transactionNoteController.dispose();

    searchController
      ..removeListener(_searchListener)
      ..dispose();

    super.dispose();
  }
}
