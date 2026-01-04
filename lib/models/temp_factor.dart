import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

part 'temp_factor.g.dart';

@HiveType(typeId: 14)
class TempFactor {
  @HiveField(0)
  final String id;              // 唯一ID (必填)

  @HiveField(1)
  final String name;            // 系数名称 (必填，如"利润率", "税率", "预留点数")

  @HiveField(2)
  final double value;           // 系数值 (必填)

  @HiveField(3)
  final int addedCount;         // 被添加次数 (默认0)

  TempFactor({
    required this.id,
    required this.name,
    required this.value,
    this.addedCount = 0,
  });

  factory TempFactor.fromJson(Map<String, dynamic> json) {
    String id = json['id']?.toString() ?? '';
    if (id.isEmpty) {
      id = Uuid().v4(); // 生成新的UUID
    }
    return TempFactor(
      id: id,
      name: json['name']?.toString() ?? '',
      value: (json['value'] as num?)?.toDouble() ?? (json['defaultValue'] as num?)?.toDouble() ?? 0.0,
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
  TempFactor copyWith({
    String? id,
    String? name,
    double? value,
    int? addedCount,
  }) {
    return TempFactor(
      id: id ?? this.id,
      name: name ?? this.name,
      value: value ?? this.value,
      addedCount: addedCount ?? this.addedCount,
    );
  }
}