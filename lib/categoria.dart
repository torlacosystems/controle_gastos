import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'categoria.g.dart';

@HiveType(typeId: 5)
class Categoria extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String nome;

  @HiveField(2)
  final int iconeCodePoint;

  @HiveField(3)
  final String iconeFontFamily;

  @HiveField(4)
  final double limiteMensal;

  Categoria({
    required this.id,
    required this.nome,
    required this.iconeCodePoint,
    required this.iconeFontFamily,
    required this.limiteMensal,
  });

  IconData get icone => IconData(iconeCodePoint, fontFamily: iconeFontFamily);
}
