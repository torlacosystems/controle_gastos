import 'package:hive/hive.dart';

part 'gasto.g.dart';

@HiveType(typeId: 0)
class Gasto extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String descricao;

  @HiveField(2)
  late double valor;

  @HiveField(3)
  late String categoria;

  @HiveField(4)
  late DateTime data;

  @HiveField(5)
  late String formaPagamento;

  @HiveField(6)
  late String pessoa;

  @HiveField(7)
  late String tipoGasto;

  @HiveField(8)
  late bool parcelado;

  @HiveField(9)
  late int numeroParcelas;

  @HiveField(10)
  late String estabelecimento;

  @HiveField(11)
  late bool recorrente;

  @HiveField(12)
  late bool gastoEsperado;

  @HiveField(13)
  late String grupoId;

  @HiveField(14)
  late int numeroParcela;

  @HiveField(15)
  bool gastoEvitavel;

  Gasto({
    required this.id,
    required this.descricao,
    required this.valor,
    required this.categoria,
    required this.data,
    required this.formaPagamento,
    required this.pessoa,
    required this.tipoGasto,
    required this.parcelado,
    required this.numeroParcelas,
    required this.estabelecimento,
    required this.recorrente,
    required this.gastoEsperado,
    this.grupoId = '',
    this.numeroParcela = 0,
    this.gastoEvitavel = false,
  });
}
