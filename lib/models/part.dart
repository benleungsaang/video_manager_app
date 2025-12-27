import 'package:hive_flutter/hive_flutter.dart';

part 'part.g.dart';

@HiveType(typeId: 12)
class Part {
  @HiveField(0)
  final String id;              // 唯一ID (必填)

  @HiveField(1)
  final String model;           // 部件型号 (必填)

  @HiveField(2)
  final String name;            // 部件名称 (必填)

  @HiveField(3)
  final double defaultPrice;    // 默认价格 (必填)

  @HiveField(4)
  final int usageCount;         // 使用次数 (默认0，用于显示热门部件)

  Part({
    required this.id,
    required this.model,
    required this.name,
    required this.defaultPrice,
    this.usageCount = 0,
  });

  factory Part.fromJson(Map<String, dynamic> json) {
    return Part(
      id: json['id']?.toString() ?? '',
      model: json['model']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      defaultPrice: (json['defaultPrice'] as num?)?.toDouble() ?? 0.0,
      usageCount: json['usageCount']?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'model': model,
      'name': name,
      'defaultPrice': defaultPrice,
      'usageCount': usageCount,
    };
  }

  // 用于更新记录的方法
  Part copyWith({
    String? id,
    String? model,
    String? name,
    double? defaultPrice,
    int? usageCount,
  }) {
    return Part(
      id: id ?? this.id,
      model: model ?? this.model,
      name: name ?? this.name,
      defaultPrice: defaultPrice ?? this.defaultPrice,
      usageCount: usageCount ?? this.usageCount,
    );
  }
}