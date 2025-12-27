// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'machine_part.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MachinePartAdapter extends TypeAdapter<MachinePart> {
  @override
  final int typeId = 10;

  @override
  MachinePart read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MachinePart(
      model: fields[0] as String,
      originalModel: fields[1] as String,
      originalPrice: fields[2] as double,
      showPrice: fields[3] as double,
      image: fields[4] as String,
      addedCount: fields[5] as int,
      otherProperties: (fields[6] as Map).cast<String, String>(),
      createdAt: fields[7] as DateTime,
      updatedAt: fields[8] as DateTime,
      createdBy: fields[9] as String,
      updatedBy: fields[10] as String,
    );
  }

  @override
  void write(BinaryWriter writer, MachinePart obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.model)
      ..writeByte(1)
      ..write(obj.originalModel)
      ..writeByte(2)
      ..write(obj.originalPrice)
      ..writeByte(3)
      ..write(obj.showPrice)
      ..writeByte(4)
      ..write(obj.image)
      ..writeByte(5)
      ..write(obj.addedCount)
      ..writeByte(6)
      ..write(obj.otherProperties)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.updatedAt)
      ..writeByte(9)
      ..write(obj.createdBy)
      ..writeByte(10)
      ..write(obj.updatedBy);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MachinePartAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
