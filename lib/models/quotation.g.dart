// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quotation.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class QuotationAdapter extends TypeAdapter<Quotation> {
  @override
  final int typeId = 6;

  @override
  Quotation read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Quotation(
      id: fields[0] as String?,
      title: fields[1] as String,
      items: (fields[2] as List)
          .map((dynamic e) => (e as Map).cast<String, dynamic>())
          .toList(),
      remarks: (fields[3] as Map).cast<String, String>(),
      subtotal: fields[4] as double,
      total: fields[5] as double,
      currency: fields[6] as String,
      createdAt: fields[7] as DateTime?,
      updatedAt: fields[8] as DateTime?,
      createdBy: fields[9] as String,
      subtotal_remark: fields[10] as String,
      total_remark: fields[11] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Quotation obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.items)
      ..writeByte(3)
      ..write(obj.remarks)
      ..writeByte(4)
      ..write(obj.subtotal)
      ..writeByte(5)
      ..write(obj.total)
      ..writeByte(6)
      ..write(obj.currency)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.updatedAt)
      ..writeByte(9)
      ..write(obj.createdBy)
      ..writeByte(10)
      ..write(obj.subtotal_remark)
      ..writeByte(11)
      ..write(obj.total_remark);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuotationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
