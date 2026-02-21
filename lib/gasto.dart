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

  Gasto({
    required this.id,
    required this.descricao,
    required this.valor,
    required this.categoria,
    required this.data,
  });
}
