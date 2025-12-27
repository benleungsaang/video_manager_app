import 'package:hive_flutter/hive_flutter.dart';

part 'temp_factor.g.dart';

@HiveType(typeId: 14)
class TempFactor {
  @HiveField(0)
  final String id;              // 唯一ID (必填)

  @HiveField(1)
  final String name;            // 系数名称 (必填，如"利润率", "税率", "预留点数")

  @HiveField(2)
  final double defaultValue;    // 默认系数值 (必填)

  @HiveField(3)
  final int usageCount;         // 使用次数 (默认0，用于显示热门系数)

  TempFactor({
    required this.id,
    required this.name,
    required this.defaultValue,
    this.usageCount = 0,
  });

  factory TempFactor.fromJson(Map<String, dynamic> json) {
    return TempFactor(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      defaultValue: (json['defaultValue'] as num?)?.toDouble() ?? 0.0,
      usageCount: json['usageCount']?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'defaultValue': defaultValue,
      'usageCount': usageCount,
    };
  }

  // 用于更新记录的方法
  TempFactor copyWith({
    String? id,
    String? name,
    double? defaultValue,
    int? usageCount,
  }) {
    return TempFactor(
      id: id ?? this.id,
      name: name ?? this.name,
      defaultValue: defaultValue ?? this.defaultValue,
      usageCount: usageCount ?? this.usageCount,
    );
  }
}