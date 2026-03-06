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
      formaPagamento: fields[5] as String,
      pessoa: fields[6] as String,
      tipoGasto: fields[7] as String,
      parcelado: fields[8] as bool,
      numeroParcelas: fields[9] as int,
      estabelecimento: fields[10] as String,
      recorrente: fields[11] as bool,
      gastoEsperado: fields[12] as bool,
      grupoId: fields[13] as String,
      numeroParcela: fields[14] as int,
    );
  }

  @override
  void write(BinaryWriter writer, Gasto obj) {
    writer
      ..writeByte(15)
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
      ..write(obj.formaPagamento)
      ..writeByte(6)
      ..write(obj.pessoa)
      ..writeByte(7)
      ..write(obj.tipoGasto)
      ..writeByte(8)
      ..write(obj.parcelado)
      ..writeByte(9)
      ..write(obj.numeroParcelas)
      ..writeByte(10)
      ..write(obj.estabelecimento)
      ..writeByte(11)
      ..write(obj.recorrente)
      ..writeByte(12)
      ..write(obj.gastoEsperado)
      ..writeByte(13)
      ..write(obj.grupoId)
      ..writeByte(14)
      ..write(obj.numeroParcela);
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
