import 'package:hive/hive.dart';

part 'orcamento.g.dart';

@HiveType(typeId: 4)
class Orcamento extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String categoria;

  @HiveField(2)
  final double limite;

  Orcamento({
    required this.id,
    required this.categoria,
    required this.limite,
  });
}