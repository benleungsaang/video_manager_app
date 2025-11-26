// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class VideoAdapter extends TypeAdapter<Video> {
  @override
  final int typeId = 0;

  @override
  Video read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Video(
      title: fields[1] as String,
      filePath: fields[2] as String,
      fileSize: fields[3] as int,
      tagIds: (fields[4] as List?)?.cast<String>(),
      remark: fields[5] as String?,
      transcode: fields[9] as String?,
      uploadTime: fields[6] as DateTime?,
      duration: fields[7] as int?,
      thumbnailPath: fields[8] as String?,
      id: fields[0] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Video obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.filePath)
      ..writeByte(3)
      ..write(obj.fileSize)
      ..writeByte(4)
      ..write(obj.tagIds)
      ..writeByte(5)
      ..write(obj.remark)
      ..writeByte(6)
      ..write(obj.uploadTime)
      ..writeByte(7)
      ..write(obj.duration)
      ..writeByte(8)
      ..write(obj.thumbnailPath)
      ..writeByte(9)
      ..write(obj.transcode);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
