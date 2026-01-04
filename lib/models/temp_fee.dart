import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

part 'temp_fee.g.dart';

@HiveType(typeId: 13)
class TempFee {
  @HiveField(0)
  final String id;              // 唯一ID (必填)

  @HiveField(1)
  final String name;            // 费用名称 (必填，如"包装费", "海运费", "陆运费")

  @HiveField(2)
  final double value;           // 费用值 (必填)

  @HiveField(3)
  final int addedCount;         // 被添加次数 (默认0)

  TempFee({
    required this.id,
    required this.name,
    required this.value,
    this.addedCount = 0,
  });

  factory TempFee.fromJson(Map<String, dynamic> json) {
    String id = json['id']?.toString() ?? '';
    if (id.isEmpty) {
      id = Uuid().v4(); // 生成新的UUID
    }
    return TempFee(
      id: id,
      name: json['name']?.toString() ?? '',
      value: (json['value'] as num?)?.toDouble() ?? (json['defaultAmount'] as num?)?.toDouble() ?? 0.0,
      addedCount: json['addedCount']?.toInt() ?? json['usageCount']?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'value': value,
      'addedCount': addedCount,
    };
  }

  // 用于更新记录的方法
  TempFee copyWith({
    String? id,
    String? name,
    double? value,
    int? addedCount,
  }) {
    return TempFee(
      id: id ?? this.id,
      name: name ?? this.name,
      value: value ?? this.value,
      addedCount: addedCount ?? this.addedCount,
    );
  }
}