import 'package:hive/hive.dart';

part 'gasto.g.dart';

@HiveType(typeId: 0)
class Gasto extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String descricao;

  @HiveField(2)
  final double valor;

  @HiveField(3)
  final String categoria;

  @HiveField(4)
  final DateTime data;

  @HiveField(5)
  final String formaPagamento;

  @HiveField(6)
  final String pessoa;

  @HiveField(7)
  final String tipoGasto; // 'Fixo' ou 'Variável'

  @HiveField(8)
  final bool parcelado;

  @HiveField(9)
  final int numeroParcelas;

  @HiveField(10)
  final String estabelecimento;

  @HiveField(11)
  final bool recorrente;

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
  });
}
