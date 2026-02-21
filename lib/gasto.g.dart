// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gasto.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GastoAdapter extends TypeAdapter<Gasto> {
  @override
  final int typeId = 0;

  @override
  Gasto read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Gasto(
      id: fields[0] as String,
      descricao: fields[1] as String,
      valor: fields[2] as double,
      categoria: fields[3] as String,
      data: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Gasto obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.descricao)
      ..writeByte(2)
      ..write(obj.valor)
      ..writeByte(3)
      ..write(obj.categoria)
      ..writeByte(4)
      ..write(obj.data);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GastoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
