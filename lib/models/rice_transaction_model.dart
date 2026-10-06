class RiceTransactionModel {
  final String id;
  final String farmerId;
  final String partyId;
  final DateTime date;
  final double quantity;
  final double rate;
  final double totalAmount;
  final String transactionType;

  /// Purchase:
  /// paidAmount = amount already paid to party
  ///
  /// Sale:
  /// receivedAmount = amount already received from party
  final double paidAmount;
  final double receivedAmount;

  /// Automatically calculated:
  ///
  /// Purchase:
  /// remainingAmount = totalAmount - paidAmount
  ///
  /// Sale:
  /// remainingAmount = totalAmount - receivedAmount
  final double remainingAmount;

  final String? variety;
  final String? notes;

  const RiceTransactionModel({
    required this.id,
    required this.farmerId,
    required this.partyId,
    required this.date,
    required this.quantity,
    required this.rate,
    required this.totalAmount,
    required this.transactionType,
    this.paidAmount = 0,
    this.receivedAmount = 0,
    this.remainingAmount = 0,
    this.variety,
    this.notes,
  });

  RiceTransactionModel copyWith({
    String? id,
    String? farmerId,
    String? partyId,
    DateTime? date,
    double? quantity,
    double? rate,
    double? totalAmount,
    String? transactionType,
    double? paidAmount,
    double? receivedAmount,
    double? remainingAmount,
    String? variety,
    String? notes,
  }) {
    return RiceTransactionModel(
      id: id ?? this.id,
      farmerId: farmerId ?? this.farmerId,
      partyId: partyId ?? this.partyId,
      date: date ?? this.date,
      quantity: quantity ?? this.quantity,
      rate: rate ?? this.rate,
      totalAmount: totalAmount ?? this.totalAmount,
      transactionType: transactionType ?? this.transactionType,
      paidAmount: paidAmount ?? this.paidAmount,
      receivedAmount: receivedAmount ?? this.receivedAmount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      variety: variety ?? this.variety,
      notes: notes ?? this.notes,
    );
  }

  factory RiceTransactionModel.fromJson(Map<String, dynamic> json) {
    final totalAmount =
        (json['totalAmount'] as num?)?.toDouble() ??
        (json['total'] as num?)?.toDouble() ??
        0;

    final paidAmount = (json['paidAmount'] as num?)?.toDouble() ?? 0;

    final receivedAmount = (json['receivedAmount'] as num?)?.toDouble() ?? 0;

    final transactionType =
        json['transactionType']?.toString() ??
        json['type']?.toString() ??
        'Purchase';

    double remainingAmount = (json['remainingAmount'] as num?)?.toDouble() ?? 0;

    // ---------------------------------------------------
    // BACKWARD COMPATIBILITY
    // ---------------------------------------------------
    //
    // Old records do not have remainingAmount.
    // Calculate it automatically from existing data.
    //
    if (json['remainingAmount'] == null) {
      if (transactionType == 'Purchase') {
        remainingAmount = totalAmount - paidAmount;
      } else {
        remainingAmount = totalAmount - receivedAmount;
      }
    }

    if (remainingAmount < 0) {
      remainingAmount = 0;
    }

    return RiceTransactionModel(
      id: json['id']?.toString() ?? '',
      farmerId: json['farmerId']?.toString() ?? '',
      partyId: json['partyId']?.toString() ?? '',
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      rate: (json['rate'] as num?)?.toDouble() ?? 0,
      totalAmount: totalAmount,
      transactionType: transactionType,
      paidAmount: paidAmount,
      receivedAmount: receivedAmount,
      remainingAmount: remainingAmount,
      variety: json['variety']?.toString(),
      notes: json['notes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'farmerId': farmerId,
      'partyId': partyId,
      'date': date.toIso8601String(),
      'quantity': quantity,
      'rate': rate,
      'totalAmount': totalAmount,
      'transactionType': transactionType,

      // New accounting fields.
      'paidAmount': paidAmount,
      'receivedAmount': receivedAmount,
      'remainingAmount': remainingAmount,

      'variety': variety,
      'notes': notes,

      // Keep old schema compatibility.
      'type': transactionType,
      'total': totalAmount,
    };
  }
}
