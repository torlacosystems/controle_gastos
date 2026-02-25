import 'package:hive/hive.dart';

part 'receita.g.dart';

@HiveType(typeId: 3)
class Receita extends HiveObject {
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
  late String pessoa;

  @HiveField(6)
  late bool recorrente;

  @HiveField(7)
  late String tipoReceita;

  Receita({
    required this.id,
    required this.descricao,
    required this.valor,
    required this.categoria,
    required this.data,
    required this.pessoa,
    required this.recorrente,
    required this.tipoReceita,
  });
}
