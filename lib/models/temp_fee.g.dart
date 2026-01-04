// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'temp_fee.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TempFeeAdapter extends TypeAdapter<TempFee> {
  @override
  final int typeId = 13;

  @override
  TempFee read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TempFee(
      id: fields[0] as String,
      name: fields[1] as String,
      value: fields[2] as double,
      addedCount: fields[3] as int,
    );
  }

  @override
  void write(BinaryWriter writer, TempFee obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.value)
      ..writeByte(3)
      ..write(obj.addedCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TempFeeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
