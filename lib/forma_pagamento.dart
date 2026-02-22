import 'package:hive/hive.dart';

part 'forma_pagamento.g.dart';

@HiveType(typeId: 1)
class FormaPagamento extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String descricao;

  @HiveField(2)
  final String tipo;

  @HiveField(3)
  final String banco;

  FormaPagamento({
    required this.id,
    required this.descricao,
    required this.tipo,
    required this.banco,
  });
}
