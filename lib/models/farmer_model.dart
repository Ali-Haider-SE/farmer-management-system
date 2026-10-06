class FarmerModel {
  final String id;
  final String name;
  final String fatherName;
  final String phone;
  final String address;
  final String? cnic;
  final bool isActive;

  const FarmerModel({
    required this.id,
    required this.name,
    this.fatherName = '',
    this.phone = '',
    this.address = '',
    this.cnic,
    this.isActive = true,
  });

  FarmerModel copyWith({
    String? id,
    String? name,
    String? fatherName,
    String? phone,
    String? address,
    String? cnic,
    bool? isActive,
  }) {
    return FarmerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      fatherName: fatherName ?? this.fatherName,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      cnic: cnic ?? this.cnic,
      isActive: isActive ?? this.isActive,
    );
  }

  factory FarmerModel.fromJson(Map<String, dynamic> json) {
    return FarmerModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      fatherName: json['fatherName']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      cnic: json['cnic']?.toString(),
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'fatherName': fatherName,
      'phone': phone,
      'address': address,
      'cnic': cnic,
      'isActive': isActive,
    };
  }
}
