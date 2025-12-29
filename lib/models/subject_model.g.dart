// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subject_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SubjectAdapter extends TypeAdapter<Subject> {
  @override
  final int typeId = 0;

  @override
  Subject read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Subject(
      id: (fields[0] as String?) ?? '',
      name: (fields[1] as String?) ?? '',
      description: (fields[2] as String?) ?? '',
      type: (fields[3] as String?) ?? '',
      deadline: fields[4] as DateTime?,
      hourGoal: (fields[5] as int?) ?? 0,
      createdAt: (fields[6] as DateTime?) ?? DateTime.now(),
      updatedAt: (fields[7] as DateTime?) ?? DateTime.now(),
      isSynced: (fields[8] as bool?) ?? false,
      isDeleted: (fields[9] as bool?) ?? false,
      status: (fields[10] as String?) ?? 'in progress',
      hoursCompleted: (fields[11] is int) ? (fields[11] as int).toDouble() : (fields[11] as double?) ?? 0.0,
    );
  }

  @override
  void write(BinaryWriter writer, Subject obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.deadline)
      ..writeByte(5)
      ..write(obj.hourGoal)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.updatedAt)
      ..writeByte(8)
      ..write(obj.isSynced)
      ..writeByte(9)
      ..write(obj.isDeleted)
      ..writeByte(10)
      ..write(obj.status)
      ..writeByte(11)
      ..write(obj.hoursCompleted);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubjectAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
