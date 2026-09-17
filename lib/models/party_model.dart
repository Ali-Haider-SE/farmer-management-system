import 'khata_model.dart';

class PartyModel {
  final String id;
  final String name;
  final String phone;
  final String address;

  /// customer / supplier
  final String partyType;

  final double openingBalance;

  /// You Give = Receivable
  /// You Take = Payable
  final String openingBalanceType;

  final bool isActive;

  final DateTime createdAt;

  final List<KhataModel> transactions;

  const PartyModel({
    required this.id,
    required this.name,
    this.phone = '',
    this.address = '',
    this.partyType = 'customer',
    this.openingBalance = 0,
    this.openingBalanceType = 'You Give',
    this.isActive = true,
    required this.createdAt,
    this.transactions = const [],
  });

  PartyModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? address,
    String? partyType,
    double? openingBalance,
    String? openingBalanceType,
    bool? isActive,
    DateTime? createdAt,
    List<KhataModel>? transactions,
  }) {
    return PartyModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      partyType: partyType ?? this.partyType,
      openingBalance: openingBalance ?? this.openingBalance,
      openingBalanceType: openingBalanceType ?? this.openingBalanceType,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      transactions: transactions ?? this.transactions,
    );
  }

  factory PartyModel.fromJson(Map<String, dynamic> json) {
    final rawTransactions = json['transactions'];

    final transactions = <KhataModel>[];

    if (rawTransactions is List) {
      for (final item in rawTransactions) {
        if (item is! Map) {
          continue;
        }

        final map = Map<String, dynamic>.from(item);

        /*
         * Old screen format:
         *
         * type: You Give / You Take
         * amount: 1000
         * note: ...
         * date: ...
         *
         * New KhataModel format:
         *
         * debit / credit / description
         */

        final type = map['type']?.toString();

        final amount = _toDouble(map['amount']);

        double debit = _toDouble(map['debit']);
        double credit = _toDouble(map['credit']);

        if (map['amount'] != null) {
          if (type == 'You Give') {
            debit = amount;
            credit = 0;
          } else if (type == 'You Take') {
            credit = amount;
            debit = 0;
          }
        }

        transactions.add(
          KhataModel(
            id:
                map['id']?.toString() ??
                DateTime.now().microsecondsSinceEpoch.toString(),
            partyId: json['id']?.toString() ?? '',
            date:
                DateTime.tryParse(map['date']?.toString() ?? '') ??
                DateTime.now(),
            description:
                map['description']?.toString() ?? map['note']?.toString() ?? '',
            debit: debit,
            credit: credit,
            balance: _toDouble(map['balance']),
            reference: map['reference']?.toString(),
          ),
        );
      }
    }

    return PartyModel(
      id:
          json['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      partyType: json['partyType']?.toString() ?? 'customer',
      openingBalance: _toDouble(json['openingBalance']),
      openingBalanceType: json['openingBalanceType']?.toString() ?? 'You Give',
      isActive: json['isActive'] as bool? ?? true,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      transactions: transactions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'partyType': partyType,
      'openingBalance': openingBalance,
      'openingBalanceType': openingBalanceType,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'transactions': transactions.map((item) {
        return {
          'id': item.id,
          'partyId': item.partyId,
          'date': item.date.toIso8601String(),
          'description': item.description,
          'debit': item.debit,
          'credit': item.credit,
          'balance': item.balance,
          'reference': item.reference,

          // Keep old-format compatibility.
          'type': item.debit > 0 ? 'You Give' : 'You Take',
          'amount': item.debit > 0 ? item.debit : item.credit,
          'note': item.description,
        };
      }).toList(),
    };
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    if (value == null) {
      return 0;
    }

    return double.tryParse(value.toString()) ?? 0;
  }
}
