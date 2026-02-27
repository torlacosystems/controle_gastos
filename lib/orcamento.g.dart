// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'orcamento.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class OrcamentoAdapter extends TypeAdapter<Orcamento> {
  @override
  final int typeId = 4;

  @override
  Orcamento read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Orcamento(
      id: fields[0] as String,
      categoria: fields[1] as String,
      limite: fields[2] as double,
    );
  }

  @override
  void write(BinaryWriter writer, Orcamento obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.categoria)
      ..writeByte(2)
      ..write(obj.limite);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrcamentoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
