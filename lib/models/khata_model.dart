class KhataModel {
  final String id;
  final String partyId;
  final DateTime date;
  final String description;
  final double debit;
  final double credit;
  final double balance;
  final String? reference;

  const KhataModel({
    required this.id,
    required this.partyId,
    required this.date,
    required this.description,
    this.debit = 0,
    this.credit = 0,
    this.balance = 0,
    this.reference,
  });

  KhataModel copyWith({
    String? id,
    String? partyId,
    DateTime? date,
    String? description,
    double? debit,
    double? credit,
    double? balance,
    String? reference,
  }) {
    return KhataModel(
      id: id ?? this.id,
      partyId: partyId ?? this.partyId,
      date: date ?? this.date,
      description: description ?? this.description,
      debit: debit ?? this.debit,
      credit: credit ?? this.credit,
      balance: balance ?? this.balance,
      reference: reference ?? this.reference,
    );
  }

  factory KhataModel.fromJson(Map<String, dynamic> json) {
    return KhataModel(
      id: json['id']?.toString() ?? '',
      partyId: json['partyId']?.toString() ?? '',
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      description: json['description']?.toString() ?? '',
      debit: (json['debit'] as num?)?.toDouble() ?? 0,
      credit: (json['credit'] as num?)?.toDouble() ?? 0,
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
      reference: json['reference']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'partyId': partyId,
      'date': date.toIso8601String(),
      'description': description,
      'debit': debit,
      'credit': credit,
      'balance': balance,
      'reference': reference,
    };
  }
}
