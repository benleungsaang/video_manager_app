import 'package:hive_flutter/hive_flutter.dart';

part 'temp_factor.g.dart';

@HiveType(typeId: 14)
class TempFactor {
  @HiveField(0)
  final String name;            // 系数名称 (必填，如"利润率", "税率", "预留点数")

  @HiveField(1)
  final double value;           // 系数值 (必填)

  @HiveField(2)
  final int addedCount;         // 被添加次数 (默认0)

  TempFactor({
    required this.name,
    required this.value,
    this.addedCount = 0,
  });

  factory TempFactor.fromJson(Map<String, dynamic> json) {
    return TempFactor(
      name: json['name']?.toString() ?? '',
      value: (json['value'] as num?)?.toDouble() ?? (json['defaultValue'] as num?)?.toDouble() ?? 0.0,
      addedCount: json['addedCount']?.toInt() ?? json['usageCount']?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'value': value,
      'addedCount': addedCount,
    };
  }

  // 用于更新记录的方法
  TempFactor copyWith({
    String? name,
    double? value,
    int? addedCount,
  }) {
    return TempFactor(
      name: name ?? this.name,
      value: value ?? this.value,
      addedCount: addedCount ?? this.addedCount,
    );
  }
}