import 'package:hive_flutter/hive_flutter.dart';

part 'machine_part.g.dart';

@HiveType(typeId: 10)
class MachinePart {
  @HiveField(0)
  final String model;             // 型号 (必填) - 对应JSON中的"Model"

  @HiveField(1)
  final String originalModel;     // 原型号 (必填) - 对应JSON中的"OriginalModel" 

  @HiveField(2)
  final double originalPrice;     // 原价格 (必填) - 对应JSON中的"OriginalPrice"

  @HiveField(3)
  final double showPrice;         // 显示价格 (必填) - 对应JSON中的"ShowPrice"

  @HiveField(4)
  final String image;             // 图片URL (必填) - 对应JSON中的"image"

  @HiveField(5)
  final int addedCount;           // 被添加次数 (默认0) - 对应JSON中的"addedCount"

  @HiveField(6)
  final Map<String, String> otherProperties; // 其他属性，以字符串形式保存

  @HiveField(7)
  final DateTime createdAt;       // 创建时间 (必填)

  @HiveField(8)
  final DateTime updatedAt;       // 最后修改时间 (必填)

  @HiveField(9)
  final String createdBy;         // 创建人 (必填)

  @HiveField(10)
  final String updatedBy;         // 最后修改人 (必填)
  
  MachinePart({
    required this.model,
    required this.originalModel,
    required this.originalPrice,
    required this.showPrice,
    required this.image,
    this.addedCount = 0,
    required this.otherProperties,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.updatedBy,
  });
  
  factory MachinePart.fromJson(Map<String, dynamic> json) {
    // 提取通用属性
    String model = json['Model']?.toString() ?? '';
    String originalModel = json['OriginalModel']?.toString() ?? '';
    double originalPrice = (json['OriginalPrice'] as num?)?.toDouble() ?? 0.0;
    double showPrice = (json['ShowPrice'] as num?)?.toDouble() ?? 0.0;
    String image = json['image']?.toString() ?? '';
    int addedCount = json['addedCount']?.toInt() ?? 0;
    
    // 提取审计字段
    DateTime createdAt = DateTime.parse(json['createdAt']?.toString() ?? DateTime.now().toIso8601String());
    DateTime updatedAt = DateTime.parse(json['updatedAt']?.toString() ?? DateTime.now().toIso8601String());
    String createdBy = json['createdBy']?.toString() ?? 'system';
    String updatedBy = json['updatedBy']?.toString() ?? 'system';
    
    // 提取其他所有属性并转换为字符串
    Map<String, String> otherProperties = {};
    json.forEach((key, value) {
      if (key != 'Model' && 
          key != 'OriginalModel' && 
          key != 'OriginalPrice' && 
          key != 'ShowPrice' && 
          key != 'image' && 
          key != 'addedCount' &&
          key != 'createdAt' &&
          key != 'updatedAt' &&
          key != 'createdBy' &&
          key != 'updatedBy') {
        otherProperties[key] = value?.toString() ?? '';
      }
    });
    
    return MachinePart(
      model: model,
      originalModel: originalModel,
      originalPrice: originalPrice,
      showPrice: showPrice,
      image: image,
      addedCount: addedCount,
      otherProperties: otherProperties,
      createdAt: createdAt,
      updatedAt: updatedAt,
      createdBy: createdBy,
      updatedBy: updatedBy,
    );
  }
  
  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {
      'Model': model,
      'OriginalModel': originalModel,
      'OriginalPrice': originalPrice,
      'ShowPrice': showPrice,
      'image': image,
      'addedCount': addedCount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'createdBy': createdBy,
      'updatedBy': updatedBy,
    };
    
    // 添加其他属性
    otherProperties.forEach((key, value) {
      json[key] = value;
    });
    
    return json;
  }
  
  // 用于更新记录的方法
  MachinePart copyWith({
    String? model,
    String? originalModel,
    double? originalPrice,
    double? showPrice,
    String? image,
    int? addedCount,
    Map<String, String>? otherProperties,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return MachinePart(
      model: model ?? this.model,
      originalModel: originalModel ?? this.originalModel,
      originalPrice: originalPrice ?? this.originalPrice,
      showPrice: showPrice ?? this.showPrice,
      image: image ?? this.image,
      addedCount: addedCount ?? this.addedCount,
      otherProperties: otherProperties ?? this.otherProperties,
      createdAt: this.createdAt, // 保持创建时间不变
      updatedAt: updatedAt ?? DateTime.now(), // 更新为当前时间
      createdBy: this.createdBy, // 保持创建人不变
      updatedBy: updatedBy ?? this.updatedBy, // 更新修改人
    );
  }
}