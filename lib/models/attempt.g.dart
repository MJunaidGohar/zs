// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attempt.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AttemptAdapter extends TypeAdapter<Attempt> {
  @override
  final int typeId = 0;

  @override
  Attempt read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Attempt(
      selectedClass: fields[0] as String,
      subject: fields[1] as String,
      selectedUnit: fields[2] as String,
      selectedCategory: fields[3] as String,
      questionType: fields[4] as String,
      score: fields[5] as int,
      total: fields[6] as int,
      timestamp: fields[7] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Attempt obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.selectedClass)
      ..writeByte(1)
      ..write(obj.subject)
      ..writeByte(2)
      ..write(obj.selectedUnit)
      ..writeByte(3)
      ..write(obj.selectedCategory)
      ..writeByte(4)
      ..write(obj.questionType)
      ..writeByte(5)
      ..write(obj.score)
      ..writeByte(6)
      ..write(obj.total)
      ..writeByte(7)
      ..write(obj.timestamp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttemptAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
