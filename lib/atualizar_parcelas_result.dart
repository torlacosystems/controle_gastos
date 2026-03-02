import 'gasto.dart';

class AtualizarParcelasResult {
  final Gasto gastoAtual;
  final List<MapEntry<int, Gasto>> proximas;

  AtualizarParcelasResult({required this.gastoAtual, required this.proximas});
}
