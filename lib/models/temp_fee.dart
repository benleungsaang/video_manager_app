import 'package:hive_flutter/hive_flutter.dart';

part 'temp_fee.g.dart';

@HiveType(typeId: 13)
class TempFee {
  @HiveField(0)
  final String name;            // 费用名称 (必填，如"包装费", "海运费", "陆运费")

  @HiveField(1)
  final double value;           // 费用值 (必填)

  @HiveField(2)
  final int addedCount;         // 被添加次数 (默认0)

  TempFee({
    required this.name,
    required this.value,
    this.addedCount = 0,
  });

  factory TempFee.fromJson(Map<String, dynamic> json) {
    return TempFee(
      name: json['name']?.toString() ?? '',
      value: (json['value'] as num?)?.toDouble() ?? (json['defaultAmount'] as num?)?.toDouble() ?? 0.0,
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
  TempFee copyWith({
    String? name,
    double? value,
    int? addedCount,
  }) {
    return TempFee(
      name: name ?? this.name,
      value: value ?? this.value,
      addedCount: addedCount ?? this.addedCount,
    );
  }
}