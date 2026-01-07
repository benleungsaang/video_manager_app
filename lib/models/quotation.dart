import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'quotation.g.dart';

@HiveType(typeId: 6)
class Quotation {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final List<Map<String, dynamic>> items;

  @HiveField(3)
  final Map<String, String> remarks;

  @HiveField(4)
  final double subtotal;

  @HiveField(5)
  final double total;

  @HiveField(6)
  final String currency;

  @HiveField(7)
  final DateTime createdAt;

  @HiveField(8)
  final DateTime updatedAt;

  @HiveField(9)
  final String createdBy;

  @HiveField(10)
  final String subtotal_remark;

  @HiveField(11)
  final String total_remark;

  Quotation({
    String? id, // 使ID可选，以便自动生成
    required this.title,
    required this.items,
    required this.remarks,
    required this.subtotal,
    required this.total,
    required this.currency,
    DateTime? createdAt,
    DateTime? updatedAt,
    required this.createdBy,
    String this.subtotal_remark = '',
    String this.total_remark = '',
  })  : id = id ?? const Uuid().v4(), // 自动生成UUID
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory Quotation.fromJson(Map<String, dynamic> json) {
    return Quotation(
      id: json['id'] ?? const Uuid().v4(), // 如果没有ID则生成一个
      title: json['title'] ?? '',
      items: List<Map<String, dynamic>>.from(json['items'] ?? []),
      remarks: Map<String, String>.from(json['remarks'] ?? {}),
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      total: (json['total'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'CNY',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
      createdBy: json['createdBy'] ?? 'user',
      subtotal_remark: json['subtotal_remark'] ?? '',
      total_remark: json['total_remark'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'items': items,
      'remarks': remarks,
      'subtotal': subtotal,
      'total': total,
      'currency': currency,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'createdBy': createdBy,
      'subtotal_remark': subtotal_remark,
      'total_remark': total_remark,
    };
  }

  Quotation copyWith({
    String? id,
    String? title,
    List<Map<String, dynamic>>? items,
    Map<String, String>? remarks,
    double? subtotal,
    double? total,
    String? currency,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? subtotal_remark,
    String? total_remark,
  }) {
    return Quotation(
      id: id ?? this.id,
      title: title ?? this.title,
      items: items ?? this.items,
      remarks: remarks ?? this.remarks,
      subtotal: subtotal ?? this.subtotal,
      total: total ?? this.total,
      currency: currency ?? this.currency,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      subtotal_remark: subtotal_remark ?? this.subtotal_remark,
      total_remark: total_remark ?? this.total_remark,
    );
  }
}
