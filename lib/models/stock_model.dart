class StockModel {
  final String id;
  final String productName;
  final String productType;
  final double quantity;
  final String unit;
  final double averageRate;
  final double totalValue;
  final String? warehouse;
  final bool isActive;

  const StockModel({
    required this.id,
    required this.productName,
    this.productType = '',
    this.quantity = 0,
    this.unit = 'kg',
    this.averageRate = 0,
    this.totalValue = 0,
    this.warehouse,
    this.isActive = true,
  });

  StockModel copyWith({
    String? id,
    String? productName,
    String? productType,
    double? quantity,
    String? unit,
    double? averageRate,
    double? totalValue,
    String? warehouse,
    bool? isActive,
  }) {
    return StockModel(
      id: id ?? this.id,
      productName: productName ?? this.productName,
      productType: productType ?? this.productType,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      averageRate: averageRate ?? this.averageRate,
      totalValue: totalValue ?? this.totalValue,
      warehouse: warehouse ?? this.warehouse,
      isActive: isActive ?? this.isActive,
    );
  }

  factory StockModel.fromJson(Map<String, dynamic> json) {
    return StockModel(
      id: json['id']?.toString() ?? '',
      productName: json['productName']?.toString() ?? '',
      productType: json['productType']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      unit: json['unit']?.toString() ?? 'kg',
      averageRate: (json['averageRate'] as num?)?.toDouble() ?? 0,
      totalValue: (json['totalValue'] as num?)?.toDouble() ?? 0,
      warehouse: json['warehouse']?.toString(),
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productName': productName,
      'productType': productType,
      'quantity': quantity,
      'unit': unit,
      'averageRate': averageRate,
      'totalValue': totalValue,
      'warehouse': warehouse,
      'isActive': isActive,
    };
  }
}
