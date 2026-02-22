// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'receita.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ReceitaAdapter extends TypeAdapter<Receita> {
  @override
  final int typeId = 3;

  @override
  Receita read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Receita(
      id: fields[0] as String,
      descricao: fields[1] as String,
      valor: fields[2] as double,
      categoria: fields[3] as String,
      data: fields[4] as DateTime,
      pessoa: fields[5] as String,
      recorrente: fields[6] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Receita obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.descricao)
      ..writeByte(2)
      ..write(obj.valor)
      ..writeByte(3)
      ..write(obj.categoria)
      ..writeByte(4)
      ..write(obj.data)
      ..writeByte(5)
      ..write(obj.pessoa)
      ..writeByte(6)
      ..write(obj.recorrente);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReceitaAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
