// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'forma_pagamento.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FormaPagamentoAdapter extends TypeAdapter<FormaPagamento> {
  @override
  final int typeId = 1;

  @override
  FormaPagamento read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FormaPagamento(
      id: fields[0] as String,
      descricao: fields[1] as String,
      tipo: fields[2] as String,
      banco: fields[3] as String,
      diaFechamento: fields[4] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, FormaPagamento obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.descricao)
      ..writeByte(2)
      ..write(obj.tipo)
      ..writeByte(3)
      ..write(obj.banco)
      ..writeByte(4)
      ..write(obj.diaFechamento);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FormaPagamentoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
