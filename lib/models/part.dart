import 'package:hive_flutter/hive_flutter.dart';

part 'part.g.dart';

@HiveType(typeId: 12)
class Part {
  @HiveField(0)
  final String id;              // 唯一ID (必填)

  @HiveField(1)
  final String model;           // 部件型号 (必填)

  @HiveField(2)
  final double price;           // 价格 (必填)

  @HiveField(3)
  final String remark;          // 部件详细描述 (可选)

  @HiveField(4)
  final int addedCount;         // 被添加次数 (可选)

  Part({
    required this.id,
    required this.model,
    required this.price,
    this.remark = '',
    this.addedCount = 0,
  });

  factory Part.fromJson(Map<String, dynamic> json) {
    return Part(
      id: json['id']?.toString() ?? '',
      model: json['model']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      remark: json['remark']?.toString() ?? '',
      addedCount: json['addedCount']?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'model': model,
      'price': price,
      'remark': remark,
      'addedCount': addedCount,
    };
  }

  // 用于更新记录的方法
  Part copyWith({
    String? id,
    String? model,
    double? price,
    String? remark,
    int? addedCount,
  }) {
    return Part(
      id: id ?? this.id,
      model: model ?? this.model,
      price: price ?? this.price,
      remark: remark ?? this.remark,
      addedCount: addedCount ?? this.addedCount,
    );
  }
}