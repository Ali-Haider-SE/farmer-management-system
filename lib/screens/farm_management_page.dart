import 'package:flutter/material.dart';
import '../providers/farm_provider.dart';

import '../widgets/responsive_card_row.dart';

class FarmManagementPage extends StatefulWidget {
  const FarmManagementPage({super.key});

  @override
  State<FarmManagementPage> createState() => _FarmManagementPageState();
}

class _FarmManagementPageState extends State<FarmManagementPage> {
  // =====================================================
  // DATA
  // =====================================================

  final List<Map<String, dynamic>> farms = [];

  final FarmProvider _farmProvider = FarmProvider();

  // =====================================================
  // SEARCH
  // =====================================================

  final TextEditingController searchController = TextEditingController();
  String searchQuery = '';

  // =====================================================
  // FARM CONTROLLERS
  // =====================================================

  final TextEditingController farmNameController = TextEditingController();
  final TextEditingController farmerController = TextEditingController();
  final TextEditingController areaController = TextEditingController();
  final TextEditingController locationController = TextEditingController();

  // =====================================================
  // EXPENSE CONTROLLER
  // =====================================================

  final TextEditingController expenseAmountController = TextEditingController();

  // =====================================================
  // INCOME CONTROLLERS
  // =====================================================

  final TextEditingController incomeQuantityController =
      TextEditingController();

  final TextEditingController incomeRateController = TextEditingController();

  // =====================================================
  // HARVEST CONTROLLERS
  // =====================================================

  final TextEditingController harvestQuantityController =
      TextEditingController();

  final TextEditingController harvestRateController = TextEditingController();

  // =====================================================
  // DROPDOWNS
  // =====================================================

  String selectedCrop = 'Rice';

  String selectedExpense = 'Tractor';

  String selectedIncomeType = 'Crop Sale';

  // =====================================================
  // INIT
  // =====================================================

  @override
  void initState() {
    super.initState();
    loadData();
  }

  // =====================================================
  // SAVE DATA
  // =====================================================

  Future<void> saveData() async {
    await _farmProvider.saveFarmRecords(farms);
  }

  // =====================================================
  // LOAD DATA
  // =====================================================

  Future<void> loadData() async {
    try {
      final loadedFarms = await _farmProvider.loadFarmRecords();

      for (final farmData in loadedFarms) {
        // =================================================
        // OLD DATA COMPATIBILITY
        // =================================================
        farmData['expenses'] ??= <Map<String, dynamic>>[];
        farmData['incomes'] ??= <Map<String, dynamic>>[];
        farmData['production'] ??= <Map<String, dynamic>>[];
        farmData['id'] ??= DateTime.now().millisecondsSinceEpoch.toString();
      }

      if (!mounted) return;

      setState(() {
        farms
          ..clear()
          ..addAll(loadedFarms);
      });
    } catch (e) {
      debugPrint('Error loading farm data: $e');
    }
  }

  // =====================================================
  // ADD FARM
  // =====================================================

  Future<void> addFarm() async {
    final farmName = farmNameController.text.trim();

    final farmerName = farmerController.text.trim();

    final area = double.tryParse(areaController.text.trim());

    final location = locationController.text.trim();

    if (farmName.isEmpty ||
        farmerName.isEmpty ||
        area == null ||
        area <= 0 ||
        location.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all farm details correctly'),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    setState(() {
      farms.add({
        // =================================================
        // FARM BASIC DATA
        // =================================================
        'id': DateTime.now().millisecondsSinceEpoch.toString(),

        'name': farmName,

        'farmer': farmerName,

        'area': area,

        'location': location,

        'crop': selectedCrop,

        // =================================================
        // FARM EXPENSES
        // =================================================
        'expenses': <Map<String, dynamic>>[],

        // =================================================
        // FARM INCOMES
        // =================================================
        'incomes': <Map<String, dynamic>>[],

        // =================================================
        // CROP PRODUCTION / HARVEST
        // =================================================
        'production': <Map<String, dynamic>>[],
      });
    });

    await saveData();

    clearFarmFields();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Farm added successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // =====================================================
  // CLEAR FARM FIELDS
  // =====================================================

  void clearFarmFields() {
    farmNameController.clear();

    farmerController.clear();

    areaController.clear();

    locationController.clear();

    selectedCrop = 'Rice';
  }

  // =====================================================
  // EDIT FARM
  // =====================================================

  Future<void> editFarm(int index) async {
    final farm = farms[index];

    final editNameController = TextEditingController(
      text: farm['name']?.toString() ?? '',
    );
    final editFarmerController = TextEditingController(
      text: farm['farmer']?.toString() ?? '',
    );
    final editAreaController = TextEditingController(
      text: farm['area']?.toString() ?? '',
    );
    final editLocationController = TextEditingController(
      text: farm['location']?.toString() ?? '',
    );
    String editCrop = farm['crop']?.toString() ?? 'Rice';

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Farm'),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextField(
                        controller: editNameController,
                        decoration: const InputDecoration(
                          labelText: 'Farm Name',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.agriculture),
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: editFarmerController,
                        decoration: const InputDecoration(
                          labelText: 'Farmer / Owner Name',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: editAreaController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Zameen ka Area',
                          suffixText: 'Acre',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.landscape),
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: editLocationController,
                        decoration: const InputDecoration(
                          labelText: 'Location',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.location_on),
                        ),
                      ),
                      const SizedBox(height: 15),
                      DropdownButtonFormField<String>(
                        initialValue: editCrop,
                        decoration: const InputDecoration(
                          labelText: 'Crop',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.eco),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Rice', child: Text('Rice')),
                          DropdownMenuItem(
                            value: 'Wheat',
                            child: Text('Wheat'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => editCrop = value);
                          }
                        },
                      ),
                    ],
                  ),
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
                    backgroundColor: Colors.green,
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

    final newName = editNameController.text.trim();
    final newFarmer = editFarmerController.text.trim();
    final newArea = double.tryParse(editAreaController.text.trim());
    final newLocation = editLocationController.text.trim();

    if (newName.isEmpty ||
        newFarmer.isEmpty ||
        newArea == null ||
        newArea <= 0 ||
        newLocation.isEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all farm details correctly'),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    setState(() {
      farms[index]['name'] = newName;
      farms[index]['farmer'] = newFarmer;
      farms[index]['area'] = newArea;
      farms[index]['location'] = newLocation;
      farms[index]['crop'] = editCrop;
    });

    await saveData();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Farm updated successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // =====================================================
  // DELETE FARM
  // =====================================================

  Future<void> deleteFarm(int index) async {
    final farmName = farms[index]['name']?.toString() ?? 'this farm';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Farm?'),
          content: Text(
            'Delete "$farmName" and all its harvest, income and '
            'expense records? This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
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

    if (confirmed != true) return;

    setState(() {
      farms.removeAt(index);
    });

    await saveData();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Farm deleted successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // =====================================================
  // ADD HARVEST / PRODUCTION
  // =====================================================

  Future<void> addHarvest(int farmIndex) async {
    final quantity = double.tryParse(harvestQuantityController.text.trim());

    final rate = double.tryParse(harvestRateController.text.trim());

    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid harvest quantity'),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    final farm = farms[farmIndex];

    final String crop = farm['crop']?.toString() ?? 'Rice';

    // =====================================================
    // MAKE SURE PRODUCTION LIST EXISTS
    // =====================================================

    farm['production'] ??= <Map<String, dynamic>>[];

    final Map<String, dynamic> productionRecord = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),

      'crop': crop,

      'quantity': quantity,

      'unit': 'Maund',

      'rate': rate ?? 0,

      'totalValue': rate != null ? quantity * rate : 0,

      'date': DateTime.now().toIso8601String(),
    };

    setState(() {
      farms[farmIndex]['production'].add(productionRecord);
    });

    await saveData();

    harvestQuantityController.clear();

    harvestRateController.clear();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$crop harvest added successfully.\n'
          '$quantity Maund added to production.',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  // =====================================================
  // TOTAL FARM PRODUCTION
  // =====================================================

  double totalFarmProduction(int index) {
    double total = 0;

    final dynamic productionData = farms[index]['production'];

    if (productionData is! List) {
      return 0;
    }

    for (final item in productionData) {
      if (item is Map) {
        final quantity = item['quantity'];

        if (quantity is num) {
          total += quantity.toDouble();
        } else if (quantity != null) {
          total += double.tryParse(quantity.toString()) ?? 0;
        }
      }
    }

    return total;
  }

  // =====================================================
  // TOTAL RICE PRODUCTION
  // =====================================================

  double get totalRiceProduction {
    double total = 0;

    for (int i = 0; i < farms.length; i++) {
      final crop = farms[i]['crop']?.toString();

      if (crop == 'Rice') {
        total += totalFarmProduction(i);
      }
    }

    return total;
  }

  // =====================================================
  // TOTAL WHEAT PRODUCTION
  // =====================================================

  double get totalWheatProduction {
    double total = 0;

    for (int i = 0; i < farms.length; i++) {
      final crop = farms[i]['crop']?.toString();

      if (crop == 'Wheat') {
        total += totalFarmProduction(i);
      }
    }

    return total;
  }

  // =====================================================
  // SHOW HARVEST DIALOG
  // =====================================================

  void showHarvestDialog(int farmIndex) {
    harvestQuantityController.clear();

    harvestRateController.clear();

    final String crop = farms[farmIndex]['crop']?.toString() ?? 'Rice';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Add $crop Harvest'),

          content: SizedBox(
            width: 450,

            child: Column(
              mainAxisSize: MainAxisSize.min,

              children: [
                Text(
                  'Farm: ${farms[farmIndex]['name']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 8),

                Text(
                  'Crop: $crop',
                  style: const TextStyle(color: Colors.green),
                ),

                const SizedBox(height: 15),

                const Text(
                  'Harvest will be saved in Farm Management '
                  'and automatically available to '
                  'Rice/Wheat Management.',
                  style: TextStyle(color: Colors.grey),
                ),

                const SizedBox(height: 20),

                // =================================================
                // QUANTITY
                // =================================================
                TextField(
                  controller: harvestQuantityController,

                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),

                  decoration: const InputDecoration(
                    labelText: 'Harvest Quantity',

                    hintText: 'Example: 100',

                    suffixText: 'Maund',

                    border: OutlineInputBorder(),

                    prefixIcon: Icon(Icons.agriculture),
                  ),
                ),

                const SizedBox(height: 15),

                // =================================================
                // RATE
                // =================================================
                TextField(
                  controller: harvestRateController,

                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),

                  decoration: const InputDecoration(
                    labelText: 'Estimated Rate',

                    hintText: 'Example: 12000',

                    prefixText: 'Rs. ',

                    suffixText: '/ Maund',

                    border: OutlineInputBorder(),

                    prefixIcon: Icon(Icons.money),
                  ),
                ),
              ],
            ),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),

            ElevatedButton.icon(
              onPressed: () async {
                await addHarvest(farmIndex);

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },

              icon: const Icon(Icons.add),

              label: const Text('Add Harvest'),
            ),
          ],
        );
      },
    );
  }

  // =====================================================
  // ADD EXPENSE
  // =====================================================

  Future<void> addExpense(int farmIndex) async {
    final amount = double.tryParse(expenseAmountController.text.trim());

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid expense amount'),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    farms[farmIndex]['expenses'] ??= <Map<String, dynamic>>[];

    setState(() {
      farms[farmIndex]['expenses'].add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),

        'type': selectedExpense,

        'amount': amount,

        'date': DateTime.now().toIso8601String(),
      });
    });

    await saveData();

    expenseAmountController.clear();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Expense added successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // =====================================================
  // ADD INCOME
  // =====================================================

  Future<void> addIncome(int farmIndex) async {
    final quantity = double.tryParse(incomeQuantityController.text.trim());

    final rate = double.tryParse(incomeRateController.text.trim());

    if (quantity == null || quantity <= 0 || rate == null || rate <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter valid quantity and rate'),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    final total = quantity * rate;

    farms[farmIndex]['incomes'] ??= <Map<String, dynamic>>[];

    setState(() {
      farms[farmIndex]['incomes'].add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),

        'type': selectedIncomeType,

        'quantity': quantity,

        'rate': rate,

        'total': total,

        'date': DateTime.now().toIso8601String(),
      });
    });

    await saveData();

    incomeQuantityController.clear();

    incomeRateController.clear();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Income added successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // =====================================================
  // TOTAL FARM EXPENSE
  // =====================================================

  double totalFarmExpense(int index) {
    double total = 0;

    final dynamic expenses = farms[index]['expenses'];

    if (expenses is! List) {
      return 0;
    }

    for (final expense in expenses) {
      if (expense is Map) {
        final amount = expense['amount'];

        if (amount is num) {
          total += amount.toDouble();
        } else if (amount != null) {
          total += double.tryParse(amount.toString()) ?? 0;
        }
      }
    }

    return total;
  }

  // =====================================================
  // TOTAL FARM INCOME
  // =====================================================

  double totalFarmIncome(int index) {
    double total = 0;

    final dynamic incomes = farms[index]['incomes'];

    if (incomes is! List) {
      return 0;
    }

    for (final income in incomes) {
      if (income is Map) {
        final amount = income['total'];

        if (amount is num) {
          total += amount.toDouble();
        } else if (amount != null) {
          total += double.tryParse(amount.toString()) ?? 0;
        }
      }
    }

    return total;
  }

  // =====================================================
  // FARM PROFIT / LOSS
  // =====================================================

  double farmProfitLoss(int index) {
    return totalFarmIncome(index) - totalFarmExpense(index);
  }

  // =====================================================
  // SEARCH FILTER
  // =====================================================

  List<MapEntry<int, Map<String, dynamic>>> get _filteredFarmEntries {
    final entries = farms.asMap().entries;

    if (searchQuery.isEmpty) {
      return entries.toList();
    }

    return entries.where((entry) {
      final farm = entry.value;

      final name = farm['name']?.toString().toLowerCase() ?? '';
      final farmer = farm['farmer']?.toString().toLowerCase() ?? '';
      final location = farm['location']?.toString().toLowerCase() ?? '';

      return name.contains(searchQuery) ||
          farmer.contains(searchQuery) ||
          location.contains(searchQuery);
    }).toList();
  }

  // =====================================================
  // TOTAL AREA
  // =====================================================

  double get totalArea {
    double total = 0;

    for (final farm in farms) {
      final area = farm['area'];

      if (area is num) {
        total += area.toDouble();
      } else if (area != null) {
        total += double.tryParse(area.toString()) ?? 0;
      }
    }

    return total;
  }

  // =====================================================
  // TOTAL EXPENSES
  // =====================================================

  double get totalAllExpenses {
    double total = 0;

    for (int i = 0; i < farms.length; i++) {
      total += totalFarmExpense(i);
    }

    return total;
  }

  // =====================================================
  // TOTAL INCOME
  // =====================================================

  double get totalAllIncome {
    double total = 0;

    for (int i = 0; i < farms.length; i++) {
      total += totalFarmIncome(i);
    }

    return total;
  }

  // =====================================================
  // TOTAL PROFIT / LOSS
  // =====================================================

  double get totalProfitLoss {
    return totalAllIncome - totalAllExpenses;
  }

  // =====================================================
  // SHOW EXPENSE DIALOG
  // =====================================================

  void showExpenseDialog(int farmIndex) {
    expenseAmountController.clear();

    selectedExpense = 'Tractor';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                'Add Expense - '
                '${farms[farmIndex]['name']}',
              ),

              content: SizedBox(
                width: 400,

                child: Column(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedExpense,

                      decoration: const InputDecoration(
                        labelText: 'Expense Type',
                        border: OutlineInputBorder(),
                      ),

                      items: const [
                        DropdownMenuItem(
                          value: 'Tractor',
                          child: Text('Tractor / Harrow'),
                        ),

                        DropdownMenuItem(value: 'Seed', child: Text('Seeds')),

                        DropdownMenuItem(
                          value: 'Fertilizer',
                          child: Text('Fertilizer / Khaad'),
                        ),

                        DropdownMenuItem(
                          value: 'Medicine',
                          child: Text('Medicine / Spray'),
                        ),

                        DropdownMenuItem(
                          value: 'Labour',
                          child: Text('Labour'),
                        ),

                        DropdownMenuItem(
                          value: 'Water',
                          child: Text('Water / Irrigation'),
                        ),

                        DropdownMenuItem(
                          value: 'Diesel',
                          child: Text('Diesel'),
                        ),

                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],

                      onChanged: (value) {
                        if (value == null) return;

                        setDialogState(() {
                          selectedExpense = value;
                        });
                      },
                    ),

                    const SizedBox(height: 15),

                    TextField(
                      controller: expenseAmountController,

                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),

                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        prefixText: 'Rs. ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),

              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),

                ElevatedButton(
                  onPressed: () async {
                    await addExpense(farmIndex);

                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                  },
                  child: const Text('Add Expense'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // =====================================================
  // SHOW INCOME DIALOG
  // =====================================================

  void showIncomeDialog(int farmIndex) {
    incomeQuantityController.clear();

    incomeRateController.clear();

    selectedIncomeType = 'Crop Sale';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                'Add Income - '
                '${farms[farmIndex]['name']}',
              ),

              content: SizedBox(
                width: 450,

                child: Column(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedIncomeType,

                      decoration: const InputDecoration(
                        labelText: 'Income Type',
                        border: OutlineInputBorder(),
                      ),

                      items: const [
                        DropdownMenuItem(
                          value: 'Crop Sale',
                          child: Text('Crop Sale'),
                        ),

                        DropdownMenuItem(
                          value: 'Other',
                          child: Text('Other Income'),
                        ),
                      ],

                      onChanged: (value) {
                        if (value == null) return;

                        setDialogState(() {
                          selectedIncomeType = value;
                        });
                      },
                    ),

                    const SizedBox(height: 15),

                    TextField(
                      controller: incomeQuantityController,

                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),

                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        suffixText: 'Maund',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 15),

                    TextField(
                      controller: incomeRateController,

                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),

                      decoration: const InputDecoration(
                        labelText: 'Rate per Maund',
                        prefixText: 'Rs. ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),

              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),

                ElevatedButton.icon(
                  onPressed: () async {
                    await addIncome(farmIndex);

                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                  },

                  icon: const Icon(Icons.add),

                  label: const Text('Add Income'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // =====================================================
  // FARM DETAILS
  // =====================================================

  void showFarmDetails(int index) {
    final farm = farms[index];

    final double production = totalFarmProduction(index);

    final double income = totalFarmIncome(index);

    final double expense = totalFarmExpense(index);

    final double profit = farmProfitLoss(index);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(farm['name'].toString()),

          content: SizedBox(
            width: 550,

            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    'Farmer / Owner: '
                    '${farm['farmer']}',
                  ),

                  const SizedBox(height: 8),

                  Text('Area: ${farm['area']} Acre'),

                  const SizedBox(height: 8),

                  Text('Location: ${farm['location']}'),

                  const SizedBox(height: 8),

                  Text('Crop: ${farm['crop']}'),

                  const SizedBox(height: 20),

                  const Divider(),

                  const SizedBox(height: 10),

                  // =================================================
                  // PRODUCTION
                  // =================================================
                  Text(
                    'Harvested Production: '
                    '${production.toStringAsFixed(2)} Maund',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                      fontSize: 17,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // =================================================
                  // INCOME
                  // =================================================
                  Text(
                    'Total Income: '
                    'Rs. ${income.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // =================================================
                  // EXPENSE
                  // =================================================
                  Text(
                    'Total Expense: '
                    'Rs. ${expense.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // =================================================
                  // PROFIT / LOSS
                  // =================================================
                  Text(
                    profit >= 0
                        ? 'Profit: '
                              'Rs. ${profit.toStringAsFixed(0)}'
                        : 'Loss: '
                              'Rs. ${profit.abs().toStringAsFixed(0)}',

                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: profit >= 0 ? Colors.green : Colors.red,
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Divider(),

                  const SizedBox(height: 10),

                  // =================================================
                  // PRODUCTION RECORDS
                  // =================================================
                  const Text(
                    'Production Records',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 10),

                  if (farm['production'] is List &&
                      (farm['production'] as List).isEmpty)
                    const Text(
                      'No production records yet.',
                      style: TextStyle(color: Colors.grey),
                    ),

                  if (farm['production'] is List)
                    ...(farm['production'] as List).map<Widget>((item) {
                      if (item is! Map) {
                        return const SizedBox();
                      }

                      final quantity = item['quantity'] ?? 0;

                      final rate = item['rate'] ?? 0;

                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.green,

                            child: Icon(Icons.grass, color: Colors.white),
                          ),

                          title: Text('$quantity Maund'),

                          subtitle: Text('Rate: Rs. $rate / Maund'),

                          trailing: Text(
                            item['totalValue'] != null
                                ? 'Rs. ${item['totalValue']}'
                                : 'Rs. 0',
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),

          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
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
  // ADD FARM DIALOG
  // =====================================================

  void showAddFarmDialog() {
    clearFarmFields();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add New Farm'),

              content: SizedBox(
                width: 500,

                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextField(
                        controller: farmNameController,

                        decoration: const InputDecoration(
                          labelText: 'Farm Name',
                          hintText: 'Example: Ali Farm',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.agriculture),
                        ),
                      ),

                      const SizedBox(height: 15),

                      TextField(
                        controller: farmerController,

                        decoration: const InputDecoration(
                          labelText: 'Farmer / Owner Name',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                      ),

                      const SizedBox(height: 15),

                      TextField(
                        controller: areaController,

                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),

                        decoration: const InputDecoration(
                          labelText: 'Zameen ka Area',
                          hintText: 'Example: 10',
                          suffixText: 'Acre',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.landscape),
                        ),
                      ),

                      const SizedBox(height: 15),

                      TextField(
                        controller: locationController,

                        decoration: const InputDecoration(
                          labelText: 'Location',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.location_on),
                        ),
                      ),

                      const SizedBox(height: 15),

                      DropdownButtonFormField<String>(
                        initialValue: selectedCrop,

                        decoration: const InputDecoration(
                          labelText: 'Crop',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.grass),
                        ),

                        items: const [
                          DropdownMenuItem(value: 'Rice', child: Text('Rice')),

                          DropdownMenuItem(
                            value: 'Wheat',
                            child: Text('Wheat'),
                          ),
                        ],

                        onChanged: (value) {
                          if (value == null) return;

                          setDialogState(() {
                            selectedCrop = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),

              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },

                  child: const Text('Cancel'),
                ),

                ElevatedButton.icon(
                  onPressed: () async {
                    final beforeCount = farms.length;

                    await addFarm();

                    if (farms.length > beforeCount && dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                  },

                  icon: const Icon(Icons.save),

                  label: const Text('Save Farm'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // =====================================================
  // DISPOSE
  // =====================================================

  @override
  void dispose() {
    farmNameController.dispose();

    farmerController.dispose();

    areaController.dispose();

    locationController.dispose();

    expenseAmountController.dispose();

    incomeQuantityController.dispose();

    incomeRateController.dispose();

    harvestQuantityController.dispose();

    searchController.dispose();

    harvestRateController.dispose();

    _farmProvider.dispose();

    super.dispose();
  }

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Farm Management'),

        backgroundColor: Colors.green,

        foregroundColor: Colors.white,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            // =================================================
            // HEADER
            // =================================================
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 480;

                final title = Text(
                  'Farm / Zameen Management',
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                );

                final button = ElevatedButton.icon(
                  onPressed: showAddFarmDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Add New Farm'),
                );

                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      title,
                      const SizedBox(height: 12),
                      SizedBox(width: double.infinity, child: button),
                    ],
                  );
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(child: title),
                    button,
                  ],
                );
              },
            ),

            const SizedBox(height: 25),

            // =================================================
            // SUMMARY
            // =================================================
            ResponsiveCardRow(
              minCardWidth: 190,
              aspectRatio: 1.9,
              maxColumns: 6,
              children: [
                summaryCard(
                  title: 'Total Farms',
                  value: farms.length.toString(),
                  icon: Icons.agriculture,
                  color: Colors.green,
                ),
                summaryCard(
                  title: 'Total Area',
                  value: '${totalArea.toStringAsFixed(1)} Acre',
                  icon: Icons.landscape,
                  color: Colors.blue,
                ),
                summaryCard(
                  title: 'Rice Production',
                  value: '${totalRiceProduction.toStringAsFixed(2)} Maund',
                  icon: Icons.rice_bowl,
                  color: Colors.amber,
                ),
                summaryCard(
                  title: 'Wheat Production',
                  value: '${totalWheatProduction.toStringAsFixed(2)} Maund',
                  icon: Icons.grass,
                  color: Colors.brown,
                ),
                summaryCard(
                  title: 'Total Income',
                  value: 'Rs. ${totalAllIncome.toStringAsFixed(0)}',
                  icon: Icons.trending_up,
                  color: Colors.green,
                ),
                summaryCard(
                  title: 'Total Expense',
                  value: 'Rs. ${totalAllExpenses.toStringAsFixed(0)}',
                  icon: Icons.trending_down,
                  color: Colors.red,
                ),
              ],
            ),

            const SizedBox(height: 30),

            // =================================================
            // SEARCH
            // =================================================
            TextField(
              controller: searchController,
              onChanged: (value) {
                setState(() {
                  searchQuery = value.trim().toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search by farm name, farmer or location...',
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

            const SizedBox(height: 20),

            // =================================================
            // FARM LIST
            // =================================================
            const Text(
              'My Farms',

              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 15),

            if (farms.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(40),

                  child: Center(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.agriculture,
                          size: 70,
                          color: Colors.grey,
                        ),

                        const SizedBox(height: 15),

                        const Text(
                          'No farms added yet',

                          style: TextStyle(fontSize: 20, color: Colors.grey),
                        ),

                        const SizedBox(height: 15),

                        ElevatedButton.icon(
                          onPressed: showAddFarmDialog,

                          icon: const Icon(Icons.add),

                          label: const Text('Add Your First Farm'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (_filteredFarmEntries.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Column(
                      children: const [
                        Icon(Icons.search_off, size: 60, color: Colors.grey),
                        SizedBox(height: 15),
                        Text(
                          'No farms match your search',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // =================================================
            // FARM CARDS
            // =================================================
            ..._filteredFarmEntries.map((entry) {
              final index = entry.key;

              final farm = entry.value;

              final profit = farmProfitLoss(index);

              final production = totalFarmProduction(index);

              final String crop = farm['crop']?.toString() ?? 'Rice';

              return Card(
                margin: const EdgeInsets.only(bottom: 15),

                child: Padding(
                  padding: const EdgeInsets.all(18),

                  child: Row(
                    children: [
                      // =================================================
                      // FARM ICON
                      // =================================================
                      CircleAvatar(
                        radius: 30,

                        backgroundColor: Colors.green.shade100,

                        child: Icon(
                          crop == 'Rice' ? Icons.rice_bowl : Icons.grass,

                          color: Colors.green,

                          size: 30,
                        ),
                      ),

                      const SizedBox(width: 18),

                      // =================================================
                      // FARM INFORMATION
                      // =================================================
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [
                            Text(
                              farm['name'].toString(),

                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 6),

                            Text(
                              'Owner: '
                              '${farm['farmer']}',
                            ),

                            Text(
                              'Area: '
                              '${farm['area']} Acre',
                            ),

                            Text(
                              'Location: '
                              '${farm['location']}',
                            ),

                            Text('Crop: $crop'),

                            const SizedBox(height: 8),

                            // =================================================
                            // HARVEST
                            // =================================================
                            Text(
                              'Harvest: '
                              '${production.toStringAsFixed(2)} Maund',

                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            // =================================================
                            // INCOME
                            // =================================================
                            Text(
                              'Income: '
                              'Rs. ${totalFarmIncome(index).toStringAsFixed(0)}',

                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            // =================================================
                            // EXPENSE
                            // =================================================
                            Text(
                              'Expense: '
                              'Rs. ${totalFarmExpense(index).toStringAsFixed(0)}',

                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            // =================================================
                            // PROFIT / LOSS
                            // =================================================
                            Text(
                              profit >= 0
                                  ? 'Profit: '
                                        'Rs. ${profit.toStringAsFixed(0)}'
                                  : 'Loss: '
                                        'Rs. ${profit.abs().toStringAsFixed(0)}',

                              style: TextStyle(
                                color: profit >= 0 ? Colors.green : Colors.red,

                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // =================================================
                      // BUTTONS
                      // =================================================
                      Column(
                        children: [
                          // ADD HARVEST
                          IconButton(
                            tooltip: 'Add Harvest',

                            onPressed: () {
                              showHarvestDialog(index);
                            },

                            icon: const Icon(Icons.grass, color: Colors.green),
                          ),

                          // VIEW DETAILS
                          IconButton(
                            tooltip: 'View Details',

                            onPressed: () {
                              showFarmDetails(index);
                            },

                            icon: const Icon(
                              Icons.visibility,

                              color: Colors.blue,
                            ),
                          ),

                          // ADD INCOME
                          IconButton(
                            tooltip: 'Add Income',

                            onPressed: () {
                              showIncomeDialog(index);
                            },

                            icon: const Icon(
                              Icons.attach_money,

                              color: Colors.green,
                            ),
                          ),

                          // ADD EXPENSE
                          IconButton(
                            tooltip: 'Add Expense',

                            onPressed: () {
                              showExpenseDialog(index);
                            },

                            icon: const Icon(
                              Icons.money_off,

                              color: Colors.red,
                            ),
                          ),

                          // EDIT FARM
                          IconButton(
                            tooltip: 'Edit Farm',
                            onPressed: () {
                              editFarm(index);
                            },
                            icon: const Icon(Icons.edit, color: Colors.orange),
                          ),

                          // DELETE FARM
                          IconButton(
                            tooltip: 'Delete Farm',
                            onPressed: () {
                              deleteFarm(index);
                            },
                            icon: const Icon(Icons.delete, color: Colors.red),
                          ),
                        ],
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
