// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'temp_factor.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TempFactorAdapter extends TypeAdapter<TempFactor> {
  @override
  final int typeId = 14;

  @override
  TempFactor read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TempFactor(
      name: fields[0] as String,
      value: fields[1] as double,
      addedCount: fields[2] as int,
    );
  }

  @override
  void write(BinaryWriter writer, TempFactor obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.value)
      ..writeByte(2)
      ..write(obj.addedCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TempFactorAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
