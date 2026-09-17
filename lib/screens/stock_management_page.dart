import 'package:flutter/material.dart';

import '../repositories/farm_repository.dart';
import '../repositories/rice_repository.dart';
import '../repositories/stock_repository.dart';
import '../repositories/wheat_repository.dart';
import '../widgets/responsive_card_row.dart';

class StockManagementPage extends StatefulWidget {
  const StockManagementPage({super.key});

  @override
  State<StockManagementPage> createState() => _StockManagementPageState();
}

class _StockManagementPageState extends State<StockManagementPage> {
  bool isLoading = true;

  double riceFarmProduction = 0;
  double ricePurchase = 0;
  double riceSale = 0;

  double wheatFarmProduction = 0;
  double wheatPurchase = 0;
  double wheatSale = 0;

  final List<Map<String, dynamic>> stockMovements = [];

  final TextEditingController quantityController = TextEditingController();
  final TextEditingController sourceController = TextEditingController();
  final TextEditingController noteController = TextEditingController();
  final TextEditingController searchController = TextEditingController();

  String movementCrop = 'Rice';
  String movementType = 'IN';

  String cropFilter = 'All';
  String typeFilter = 'All';

  double get riceStock => riceFarmProduction + ricePurchase - riceSale;

  double get wheatStock => wheatFarmProduction + wheatPurchase - wheatSale;

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
  void initState() {
    super.initState();

    loadStockData();

    searchController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> loadStockData() async {
    final farmRepository = FarmRepository();
    final riceRepository = RiceRepository();
    final wheatRepository = WheatRepository();
    final stockRepository = StockRepository();

    double riceProd = 0;
    double wheatProd = 0;
    for (final farm in await farmRepository.getFarmRecords()) {
      final production = farm['production'];
      if (production is! List) continue;
      for (final item in production) {
        if (item is! Map) continue;
        final quantity = _toDouble(item['quantity']);
        if (farm['crop'] == 'Rice') riceProd += quantity;
        if (farm['crop'] == 'Wheat') wheatProd += quantity;
      }
    }

    double ricePurchaseQty = 0;
    double riceSaleQty = 0;
    for (final item in riceRepository.getRawTransactions()) {
      final quantity = _toDouble(item['quantity']);
      if (item['type'] == 'Purchase') ricePurchaseQty += quantity;
      if (item['type'] == 'Sale') riceSaleQty += quantity;
    }

    double wheatPurchaseQty = 0;
    double wheatSaleQty = 0;
    for (final item in wheatRepository.getRawTransactions()) {
      final quantity = _toDouble(item['quantity']);
      if (item['type'] == 'Purchase') wheatPurchaseQty += quantity;
      if (item['type'] == 'Sale') wheatSaleQty += quantity;
    }

    final loadedMovements = stockRepository.getRawMovements();

    if (!mounted) return;

    setState(() {
      riceFarmProduction = riceProd;
      wheatFarmProduction = wheatProd;
      ricePurchase = ricePurchaseQty;
      riceSale = riceSaleQty;
      wheatPurchase = wheatPurchaseQty;
      wheatSale = wheatSaleQty;
      stockMovements
        ..clear()
        ..addAll(loadedMovements);
      isLoading = false;
    });
  }

  Future<void> saveMovements() async {
    await StockRepository().saveRawMovements(stockMovements);
  }

  String _fmt(double value) {
    return '${value.toStringAsFixed(2)} Maund';
  }

  double getCurrentStock(String crop) {
    if (crop == 'Rice') {
      return riceStock;
    }

    return wheatStock;
  }

  List<Map<String, dynamic>> get filteredMovements {
    final query = searchController.text.trim().toLowerCase();

    return stockMovements.where((movement) {
      final crop = movement['crop']?.toString() ?? '';
      final type = movement['type']?.toString() ?? '';
      final source = movement['source']?.toString().toLowerCase() ?? '';
      final note = movement['note']?.toString().toLowerCase() ?? '';

      final matchesCrop = cropFilter == 'All' || crop == cropFilter;

      final matchesType = typeFilter == 'All' || type == typeFilter;

      final matchesSearch =
          query.isEmpty ||
          crop.toLowerCase().contains(query) ||
          type.toLowerCase().contains(query) ||
          source.contains(query) ||
          note.contains(query);

      return matchesCrop && matchesType && matchesSearch;
    }).toList()..sort((a, b) {
      final dateA =
          DateTime.tryParse(a['date']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);

      final dateB =
          DateTime.tryParse(b['date']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);

      return dateB.compareTo(dateA);
    });
  }

  Future<void> addMovement() async {
    final quantity = double.tryParse(quantityController.text.trim());

    final source = sourceController.text.trim();

    final note = noteController.text.trim();

    if (quantity == null || quantity <= 0) {
      _showMessage('Please enter a valid quantity', Colors.red);
      return;
    }

    if (movementType == 'OUT') {
      final currentStock = getCurrentStock(movementCrop);

      if (quantity > currentStock) {
        _showMessage(
          'Insufficient $movementCrop stock. '
          'Available: ${currentStock.toStringAsFixed(2)} Maund',
          Colors.red,
        );
        return;
      }
    }

    final movement = <String, dynamic>{
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'crop': movementCrop,
      'type': movementType,
      'quantity': quantity,
      'source': source,
      'note': note,
      'date': DateTime.now().toIso8601String(),
    };

    setState(() {
      stockMovements.add(movement);
    });

    await saveMovements();

    quantityController.clear();
    sourceController.clear();
    noteController.clear();

    if (!mounted) {
      return;
    }

    _showMessage(
      '$movementCrop $movementType movement added successfully',
      Colors.green,
    );
  }

  Future<void> deleteMovement(int index) async {
    final movement = filteredMovements[index];

    final movementId = movement['id']?.toString();

    if (movementId == null) {
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Movement?'),
          content: const Text(
            'Are you sure you want to delete this stock movement?',
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
      stockMovements.removeWhere(
        (item) => item['id']?.toString() == movementId,
      );
    });

    await saveMovements();

    if (!mounted) {
      return;
    }

    _showMessage('Stock movement deleted', Colors.green);
  }

  void _showMessage(String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  String _formatDate(String? value) {
    if (value == null || value.isEmpty) {
      return 'Unknown date';
    }

    final date = DateTime.tryParse(value);

    if (date == null) {
      return value;
    }

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    final hour = date.hour == 0
        ? 12
        : (date.hour > 12 ? date.hour - 12 : date.hour);

    final minute = date.minute.toString().padLeft(2, '0');

    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '$day/$month/$year $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Management'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: loadStockData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadStockData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(25),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Stock Management',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Manage and monitor Rice and Wheat stock',
                      style: TextStyle(color: Colors.grey, fontSize: 15),
                    ),
                    const SizedBox(height: 30),

                    ResponsiveCardRow(
                      minCardWidth: 220,
                      aspectRatio: 2.2,
                      maxColumns: 2,
                      children: [
                        _stockCard(
                          title: 'Rice Stock',
                          value: _fmt(riceStock),
                          icon: Icons.rice_bowl,
                          color: Colors.amber,
                        ),
                        _stockCard(
                          title: 'Wheat Stock',
                          value: _fmt(wheatStock),
                          icon: Icons.grass,
                          color: Colors.brown,
                        ),
                      ],
                    ),

                    const SizedBox(height: 35),

                    const Text(
                      'Rice Stock Details',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 20),

                    ResponsiveCardRow(
                      minCardWidth: 180,
                      aspectRatio: 1.5,
                      maxColumns: 4,
                      children: [
                        _detailCard(
                          title: 'Farm Production',
                          value: _fmt(riceFarmProduction),
                          icon: Icons.agriculture,
                          color: Colors.green,
                        ),
                        _detailCard(
                          title: 'Purchased',
                          value: _fmt(ricePurchase),
                          icon: Icons.shopping_cart,
                          color: Colors.orange,
                        ),
                        _detailCard(
                          title: 'Sold',
                          value: _fmt(riceSale),
                          icon: Icons.sell,
                          color: Colors.blue,
                        ),
                        _detailCard(
                          title: 'Current Stock',
                          value: _fmt(riceStock),
                          icon: Icons.inventory,
                          color: Colors.green,
                        ),
                      ],
                    ),

                    const SizedBox(height: 35),

                    const Text(
                      'Wheat Stock Details',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 20),

                    ResponsiveCardRow(
                      minCardWidth: 180,
                      aspectRatio: 1.5,
                      maxColumns: 4,
                      children: [
                        _detailCard(
                          title: 'Farm Production',
                          value: _fmt(wheatFarmProduction),
                          icon: Icons.agriculture,
                          color: Colors.green,
                        ),
                        _detailCard(
                          title: 'Purchased',
                          value: _fmt(wheatPurchase),
                          icon: Icons.shopping_cart,
                          color: Colors.orange,
                        ),
                        _detailCard(
                          title: 'Sold',
                          value: _fmt(wheatSale),
                          icon: Icons.sell,
                          color: Colors.blue,
                        ),
                        _detailCard(
                          title: 'Current Stock',
                          value: _fmt(wheatStock),
                          icon: Icons.inventory,
                          color: Colors.brown,
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),

                    const Text(
                      'Add Stock Movement',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 18),

                    Card(
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            DropdownButtonFormField<String>(
                              initialValue: movementCrop,
                              decoration: const InputDecoration(
                                labelText: 'Crop',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.grass),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'Rice',
                                  child: Text('Rice'),
                                ),
                                DropdownMenuItem(
                                  value: 'Wheat',
                                  child: Text('Wheat'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) {
                                  return;
                                }

                                setState(() {
                                  movementCrop = value;
                                });
                              },
                            ),

                            const SizedBox(height: 15),

                            DropdownButtonFormField<String>(
                              initialValue: movementType,
                              decoration: const InputDecoration(
                                labelText: 'Movement Type',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.swap_vert),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'IN',
                                  child: Text('Stock IN - Add'),
                                ),
                                DropdownMenuItem(
                                  value: 'OUT',
                                  child: Text('Stock OUT - Remove'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) {
                                  return;
                                }

                                setState(() {
                                  movementType = value;
                                });
                              },
                            ),

                            const SizedBox(height: 15),

                            TextField(
                              controller: quantityController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: InputDecoration(
                                labelText: 'Quantity',
                                hintText: 'Example: 50',
                                prefixText: 'Maund ',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.scale),
                                helperText:
                                    'Current $movementCrop stock: '
                                    '${getCurrentStock(movementCrop).toStringAsFixed(2)} Maund',
                              ),
                            ),

                            const SizedBox(height: 15),

                            TextField(
                              controller: sourceController,
                              decoration: const InputDecoration(
                                labelText: 'Source / Party',
                                hintText: 'Example: Muhammad Ali',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.person),
                              ),
                            ),

                            const SizedBox(height: 15),

                            TextField(
                              controller: noteController,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'Note',
                                hintText: 'Example: Warehouse adjustment...',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.description),
                              ),
                            ),

                            const SizedBox(height: 20),

                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton.icon(
                                onPressed: addMovement,
                                icon: const Icon(Icons.add),
                                label: const Text(
                                  'Add Stock Movement',
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

                    const SizedBox(height: 40),

                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Stock Movement History',
                            style: TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
                              controller: searchController,
                              decoration: InputDecoration(
                                hintText:
                                    'Search crop, type, source or note...',
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

                            const SizedBox(height: 15),

                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: cropFilter,
                                    decoration: const InputDecoration(
                                      labelText: 'Crop',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'All',
                                        child: Text('All Crops'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'Rice',
                                        child: Text('Rice'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'Wheat',
                                        child: Text('Wheat'),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      if (value == null) {
                                        return;
                                      }

                                      setState(() {
                                        cropFilter = value;
                                      });
                                    },
                                  ),
                                ),

                                const SizedBox(width: 12),

                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: typeFilter,
                                    decoration: const InputDecoration(
                                      labelText: 'Type',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'All',
                                        child: Text('All Types'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'IN',
                                        child: Text('Stock IN'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'OUT',
                                        child: Text('Stock OUT'),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      if (value == null) {
                                        return;
                                      }

                                      setState(() {
                                        typeFilter = value;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 15),

                    if (filteredMovements.isEmpty)
                      Card(
                        child: SizedBox(
                          width: double.infinity,
                          height: 220,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 60,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'No stock movements found',
                                style: TextStyle(
                                  fontSize: 17,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...filteredMovements.asMap().entries.map((entry) {
                        final movement = entry.value;

                        final type = movement['type']?.toString() ?? 'IN';

                        final crop = movement['crop']?.toString() ?? '';

                        final quantity = _toDouble(movement['quantity']);

                        final source = movement['source']?.toString() ?? '';

                        final note = movement['note']?.toString() ?? '';

                        final isIn = type == 'IN';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: CircleAvatar(
                              backgroundColor:
                                  (isIn ? Colors.green : Colors.red).withValues(
                                    alpha: 0.12,
                                  ),
                              child: Icon(
                                isIn
                                    ? Icons.arrow_downward
                                    : Icons.arrow_upward,
                                color: isIn ? Colors.green : Colors.red,
                              ),
                            ),
                            title: Text(
                              '$crop — Stock $type',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  '${_formatDate(movement['date']?.toString())}'
                                  '${source.isNotEmpty ? ' • $source' : ''}',
                                ),
                                if (note.isNotEmpty)
                                  Text(
                                    note,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${isIn ? '+' : '-'} '
                                  '${quantity.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isIn ? Colors.green : Colors.red,
                                    fontSize: 16,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Delete',
                                  onPressed: () {
                                    deleteMovement(entry.key);
                                  },
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),

                    const SizedBox(height: 35),

                    Card(
                      color: Colors.green.withValues(alpha: 0.08),
                      child: const Padding(
                        padding: EdgeInsets.all(20),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Color(0xFF1B5E20),
                              size: 30,
                            ),
                            SizedBox(width: 15),
                            Expanded(
                              child: Text(
                                'Main stock is calculated from farm '
                                'production, purchases and sales. '
                                'Manual stock movements are stored '
                                'separately as adjustment/history records.',
                                style: TextStyle(fontSize: 15, height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  static Widget _stockCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(25),
        child: Row(
          children: [
            Container(
              width: 65,
              height: 65,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: color, size: 35),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.grey, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 23,
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

  static Widget _detailCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 12),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 7),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    quantityController.dispose();
    sourceController.dispose();
    noteController.dispose();
    searchController.dispose();

    super.dispose();
  }
}
