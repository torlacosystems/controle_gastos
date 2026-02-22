import 'package:hive/hive.dart';

part 'receita.g.dart';

@HiveType(typeId: 3)
class Receita extends HiveObject {
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
  final String pessoa;

  @HiveField(6)
  final bool recorrente;

  Receita({
    required this.id,
    required this.descricao,
    required this.valor,
    required this.categoria,
    required this.data,
    required this.pessoa,
    required this.recorrente,
  });
}
