import 'package:hive/hive.dart';

part 'pessoa.g.dart';

@HiveType(typeId: 2)
class Pessoa extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String nome;

  @HiveField(2)
  final String parentesco;

  Pessoa({required this.id, required this.nome, required this.parentesco});
}
