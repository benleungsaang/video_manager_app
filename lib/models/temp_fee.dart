import 'package:hive_flutter/hive_flutter.dart';

part 'temp_fee.g.dart';

@HiveType(typeId: 13)
class TempFee {
  @HiveField(0)
  final String id;              // 唯一ID (必填)

  @HiveField(1)
  final String name;            // 费用名称 (必填，如"包装费", "海运费", "陆运费")

  @HiveField(2)
  final double defaultAmount;   // 默认金额 (必填)

  @HiveField(3)
  final int usageCount;         // 使用次数 (默认0，用于显示热门费用)

  TempFee({
    required this.id,
    required this.name,
    required this.defaultAmount,
    this.usageCount = 0,
  });

  factory TempFee.fromJson(Map<String, dynamic> json) {
    return TempFee(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      defaultAmount: (json['defaultAmount'] as num?)?.toDouble() ?? 0.0,
      usageCount: json['usageCount']?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'defaultAmount': defaultAmount,
      'usageCount': usageCount,
    };
  }

  // 用于更新记录的方法
  TempFee copyWith({
    String? id,
    String? name,
    double? defaultAmount,
    int? usageCount,
  }) {
    return TempFee(
      id: id ?? this.id,
      name: name ?? this.name,
      defaultAmount: defaultAmount ?? this.defaultAmount,
      usageCount: usageCount ?? this.usageCount,
    );
  }
}