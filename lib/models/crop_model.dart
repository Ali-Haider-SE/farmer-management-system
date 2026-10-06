class CropModel {
  final String id;
  final String name;
  final String type;
  final String? season;
  final bool isActive;

  const CropModel({
    required this.id,
    required this.name,
    this.type = '',
    this.season,
    this.isActive = true,
  });

  CropModel copyWith({
    String? id,
    String? name,
    String? type,
    String? season,
    bool? isActive,
  }) {
    return CropModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      season: season ?? this.season,
      isActive: isActive ?? this.isActive,
    );
  }

  factory CropModel.fromJson(Map<String, dynamic> json) {
    return CropModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      season: json['season']?.toString(),
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'season': season,
      'isActive': isActive,
    };
  }
}
