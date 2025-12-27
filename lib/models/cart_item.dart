import 'package:hive_flutter/hive_flutter.dart';

part 'cart_item.g.dart';

@HiveType(typeId: 11)
class CartItem {
  @HiveField(0)
  final String id;              // 唯一ID (必填)

  @HiveField(1)
  final String type;            // 类型 ('机器', '部件') (必填)

  @HiveField(2)
  final String model;           // 模型 (必填)

  @HiveField(3)
  final String name;            // 名称 (必填)

  @HiveField(4)
  final double basePrice;       // 基础价格 (必填)

  @HiveField(5)
  final double actualPrice;     // 实际价格 (必填)

  @HiveField(6)
  final int quantity;           // 数量 (默认1)

  @HiveField(7)
  final String image;           // 图片URL (必填)

  CartItem({
    required this.id,
    required this.type,
    required this.model,
    required this.name,
    required this.basePrice,
    required this.actualPrice,
    this.quantity = 1,
    required this.image,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      model: json['model']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      basePrice: (json['basePrice'] as num?)?.toDouble() ?? 0.0,
      actualPrice: (json['actualPrice'] as num?)?.toDouble() ?? 0.0,
      quantity: json['quantity']?.toInt() ?? 1,
      image: json['image']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'model': model,
      'name': name,
      'basePrice': basePrice,
      'actualPrice': actualPrice,
      'quantity': quantity,
      'image': image,
    };
  }

  // 用于更新记录的方法
  CartItem copyWith({
    String? id,
    String? type,
    String? model,
    String? name,
    double? basePrice,
    double? actualPrice,
    int? quantity,
    String? image,
  }) {
    return CartItem(
      id: id ?? this.id,
      type: type ?? this.type,
      model: model ?? this.model,
      name: name ?? this.name,
      basePrice: basePrice ?? this.basePrice,
      actualPrice: actualPrice ?? this.actualPrice,
      quantity: quantity ?? this.quantity,
      image: image ?? this.image,
    );
  }
}