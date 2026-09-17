class PaymentModel {
  final String id;
  final String? partyId;
  final String? accountId;
  final DateTime date;
  final double amount;
  final String paymentType;
  final String? description;
  final String? reference;

  const PaymentModel({
    required this.id,
    this.partyId,
    this.accountId,
    required this.date,
    required this.amount,
    this.paymentType = 'cash',
    this.description,
    this.reference,
  });

  PaymentModel copyWith({
    String? id,
    String? partyId,
    String? accountId,
    DateTime? date,
    double? amount,
    String? paymentType,
    String? description,
    String? reference,
  }) {
    return PaymentModel(
      id: id ?? this.id,
      partyId: partyId ?? this.partyId,
      accountId: accountId ?? this.accountId,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      paymentType: paymentType ?? this.paymentType,
      description: description ?? this.description,
      reference: reference ?? this.reference,
    );
  }

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['id']?.toString() ?? '',
      partyId: json['partyId']?.toString(),
      accountId: json['accountId']?.toString(),
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      paymentType: json['paymentType']?.toString() ?? 'cash',
      description: json['description']?.toString(),
      reference: json['reference']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'partyId': partyId,
      'accountId': accountId,
      'date': date.toIso8601String(),
      'amount': amount,
      'paymentType': paymentType,
      'description': description,
      'reference': reference,
    };
  }
}
