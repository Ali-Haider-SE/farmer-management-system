class FarmModel {
  final String id;
  final String farmerId;
  final String farmName;
  final String location;
  final double area;
  final String areaUnit;
  final String? cropType;
  final bool isActive;

  const FarmModel({
    required this.id,
    required this.farmerId,
    required this.farmName,
    this.location = '',
    this.area = 0,
    this.areaUnit = 'Acre',
    this.cropType,
    this.isActive = true,
  });

  FarmModel copyWith({
    String? id,
    String? farmerId,
    String? farmName,
    String? location,
    double? area,
    String? areaUnit,
    String? cropType,
    bool? isActive,
  }) {
    return FarmModel(
      id: id ?? this.id,
      farmerId: farmerId ?? this.farmerId,
      farmName: farmName ?? this.farmName,
      location: location ?? this.location,
      area: area ?? this.area,
      areaUnit: areaUnit ?? this.areaUnit,
      cropType: cropType ?? this.cropType,
      isActive: isActive ?? this.isActive,
    );
  }

  factory FarmModel.fromJson(Map<String, dynamic> json) {
    return FarmModel(
      id: json['id']?.toString() ?? '',
      farmerId: json['farmerId']?.toString() ?? '',
      farmName: json['farmName']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      area: (json['area'] as num?)?.toDouble() ?? 0,
      areaUnit: json['areaUnit']?.toString() ?? 'Acre',
      cropType: json['cropType']?.toString(),
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'farmerId': farmerId,
      'farmName': farmName,
      'location': location,
      'area': area,
      'areaUnit': areaUnit,
      'cropType': cropType,
      'isActive': isActive,
    };
  }
}
