class AccountModel {
  final String id;
  final String name;
  final String accountType;
  final double openingBalance;
  final double currentBalance;
  final String? description;
  final bool isActive;

  const AccountModel({
    required this.id,
    required this.name,
    this.accountType = 'cash',
    this.openingBalance = 0,
    this.currentBalance = 0,
    this.description,
    this.isActive = true,
  });

  AccountModel copyWith({
    String? id,
    String? name,
    String? accountType,
    double? openingBalance,
    double? currentBalance,
    String? description,
    bool? isActive,
  }) {
    return AccountModel(
      id: id ?? this.id,
      name: name ?? this.name,
      accountType: accountType ?? this.accountType,
      openingBalance: openingBalance ?? this.openingBalance,
      currentBalance: currentBalance ?? this.currentBalance,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
    );
  }

  factory AccountModel.fromJson(Map<String, dynamic> json) {
    return AccountModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      accountType: json['accountType']?.toString() ?? 'cash',
      openingBalance: (json['openingBalance'] as num?)?.toDouble() ?? 0,
      currentBalance: (json['currentBalance'] as num?)?.toDouble() ?? 0,
      description: json['description']?.toString(),
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'accountType': accountType,
      'openingBalance': openingBalance,
      'currentBalance': currentBalance,
      'description': description,
      'isActive': isActive,
    };
  }
}
