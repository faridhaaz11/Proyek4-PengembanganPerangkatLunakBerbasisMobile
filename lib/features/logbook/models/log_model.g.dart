// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'log_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LogModelAdapter extends TypeAdapter<LogModel> {
  @override
  final int typeId = 0;

  @override
  LogModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LogModel(
      id: fields[0] as String?,
      username: fields[1] as String,
      title: fields[2] as String,
      date: fields[3] as DateTime,
      description: fields[4] as String,
      category: fields[5] as String,
      authorId: fields[6] as String,
      teamId: fields[7] as String,
      isPublic: fields[8] as bool,
      syncedAt: fields[9] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, LogModel obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.username)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.date)
      ..writeByte(4)
      ..write(obj.description)
      ..writeByte(5)
      ..write(obj.category)
      ..writeByte(6)
      ..write(obj.authorId)
      ..writeByte(7)
      ..write(obj.teamId)
      ..writeByte(8)
      ..write(obj.isPublic)
      ..writeByte(9)
      ..write(obj.syncedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LogModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
