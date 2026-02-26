part of 'button_position.dart';

/// Hive Type Adapter for ButtonPosition
/// Manual implementation since build_runner generation is not available
class ButtonPositionAdapter extends TypeAdapter<ButtonPosition> {
  @override
  final int typeId = 20;

  @override
  ButtonPosition read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++)
        reader.readByte(): reader.read(),
    };
    return ButtonPosition(
      x: fields[0] as double,
      y: fields[1] as double,
      lastUpdated: fields[2] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, ButtonPosition obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.x)
      ..writeByte(1)
      ..write(obj.y)
      ..writeByte(2)
      ..write(obj.lastUpdated);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ButtonPositionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
