import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'gasto.dart';
import 'receita.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  late Box<Gasto> _gastosBox;
  late Box<Receita> _receitasBox;
  double _metaEconomia = 0;
  final TextEditingController _metaController = TextEditingController();

  final List<String> _nomesMeses = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];

  final List<String> _diasSemana = [
    'Segunda',
    'Terça',
    'Quarta',
    'Quinta',
    'Sexta',
    'Sábado',
    'Domingo',
  ];

  final Map<String, String> _dicasPorCategoria = {
    'Alimentação':
        'Tente cozinhar mais em casa. Pode economizar até 40% comparado a comer fora.',
    'Transporte':
        'Considere caronas compartilhadas ou transporte público para reduzir custos.',
    'Lazer':
        'Busque opções gratuitas de lazer como parques, eventos culturais e afins.',
    'Saúde':
        'Mantenha hábitos preventivos para evitar gastos maiores no futuro.',
    'Moradia':
        'Revise contratos de serviços como internet e energia para encontrar planos melhores.',
    'Educação': 'Explore cursos gratuitos online como complemento aos pagos.',
    'Outros': 'Revise esses gastos — muitos podem ser evitados ou reduzidos.',
  };

  @override
  void initState() {
    super.initState();
    _gastosBox = Hive.box<Gasto>('gastos');
    _receitasBox = Hive.box<Receita>('receitas');
  }

  @override
  void dispose() {
    _metaController.dispose();
    super.dispose();
  }

  DateTime get _agora => DateTime.now();

  List<Gasto> get _gastosMesAtual => _gastosBox.values
      .where((g) => g.data.month == _agora.month && g.data.year == _agora.year)
      .toList();

  List<Gasto> get _gastosMesAnterior {
    final mesAnterior = DateTime(_agora.year, _agora.month - 1);
    return _gastosBox.values
        .where(
          (g) =>
              g.data.month == mesAnterior.month &&
              g.data.year == mesAnterior.year,
        )
        .toList();
  }

  double get _totalMesAtual => _gastosMesAtual.fold(0, (s, g) => s + g.valor);

  double get _totalMesAnterior =>
      _gastosMesAnterior.fold(0, (s, g) => s + g.valor);

  double get _totalReceitas {
    return _receitasBox.values
        .where(
          (r) => r.data.month == _agora.month && r.data.year == _agora.year,
        )
        .fold(0, (s, r) => s + r.valor);
  }

  double get _totalFixos => _gastosMesAtual
      .where((g) => g.tipoGasto == 'Fixo')
      .fold(0, (s, g) => s + g.valor);

  double get _totalInesperados => _gastosMesAtual
      .where((g) => !g.gastoEsperado)
      .fold(0, (s, g) => s + g.valor);

  String get _categoriaMaisGasta {
    if (_gastosMesAtual.isEmpty) return 'Nenhum gasto';
    final mapa = <String, double>{};
    for (final g in _gastosMesAtual) {
      mapa[g.categoria] = (mapa[g.categoria] ?? 0) + g.valor;
    }
    return mapa.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  double get _valorCategoriaMaisGasta {
    if (_gastosMesAtual.isEmpty) return 0;
    final mapa = <String, double>{};
    for (final g in _gastosMesAtual) {
      mapa[g.categoria] = (mapa[g.categoria] ?? 0) + g.valor;
    }
    return mapa.entries.reduce((a, b) => a.value > b.value ? a : b).value;
  }

  String get _diaMaisGasta {
    if (_gastosMesAtual.isEmpty) return 'Nenhum dado';
    final mapa = <int, double>{};
    for (final g in _gastosMesAtual) {
      final dia = g.data.weekday; // 1=seg, 7=dom
      mapa[dia] = (mapa[dia] ?? 0) + g.valor;
    }
    final diaMaior = mapa.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
    return _diasSemana[diaMaior - 1];
  }

  double get _mediaGastosDiarios {
    if (_gastosMesAtual.isEmpty) return 0;
    final diasNoMes = DateTime(_agora.year, _agora.month + 1, 0).day;
    return _totalMesAtual / diasNoMes;
  }

  String _formatarValor(double valor) =>
      'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';

  double get _percentualFixos =>
      _totalReceitas > 0 ? (_totalFixos / _totalReceitas) * 100 : 0;

  double get _percentualVariacaoMes {
    if (_totalMesAnterior == 0) return 0;
    return ((_totalMesAtual - _totalMesAnterior) / _totalMesAnterior) * 100;
  }

  double get _economiaAtual => _totalReceitas - _totalMesAtual;

  @override
  Widget build(BuildContext context) {
    final variacao = _percentualVariacaoMes;
    final aumentou = variacao > 0;
    final mesAnteriorNome =
        _nomesMeses[DateTime(_agora.year, _agora.month - 1).month - 1];
    final mesAtualNome = _nomesMeses[_agora.month - 1];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // CABEÇALHO DO MÊS
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    'Insights de $mesAtualNome',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatarValor(_totalMesAtual),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'total gasto no mês',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // SEÇÃO: DESTAQUES
            _secaoTitulo('📊 Destaques do Mês'),
            const SizedBox(height: 12),

            // Categoria que mais gastou
            _cardInsight(
              icone: Icons.pie_chart,
              cor: Colors.orange,
              titulo: 'Maior categoria de gasto',
              conteudo: _gastosMesAtual.isEmpty
                  ? 'Nenhum gasto registrado ainda.'
                  : 'Você mais gastou em $_categoriaMaisGasta este mês (${_formatarValor(_valorCategoriaMaisGasta)}).',
            ),
            const SizedBox(height: 12),

            // Dia da semana que mais gasta
            _cardInsight(
              icone: Icons.calendar_today,
              cor: Colors.purple,
              titulo: 'Dia que você mais gasta',
              conteudo: _gastosMesAtual.isEmpty
                  ? 'Nenhum gasto registrado ainda.'
                  : '$_diaMaisGasta é o dia da semana em que você mais costuma gastar.',
            ),
            const SizedBox(height: 12),

            // Comparação com mês anterior
            _cardInsight(
              icone: aumentou ? Icons.trending_up : Icons.trending_down,
              cor: aumentou ? Colors.red : Colors.green,
              titulo: 'Comparação com $mesAnteriorNome',
              conteudo: _totalMesAnterior == 0
                  ? 'Sem dados do mês anterior para comparar.'
                  : aumentou
                  ? 'Seus gastos aumentaram ${variacao.abs().toStringAsFixed(1)}% em relação a $mesAnteriorNome (${_formatarValor(_totalMesAnterior)}).'
                  : 'Parabéns! Seus gastos diminuíram ${variacao.abs().toStringAsFixed(1)}% em relação a $mesAnteriorNome (${_formatarValor(_totalMesAnterior)}).',
            ),
            const SizedBox(height: 12),

            // % comprometido com fixos
            _cardInsightComBarra(
              icone: Icons.lock_clock,
              cor: Colors.blue,
              titulo: '% comprometido com gastos fixos',
              conteudo: _totalReceitas == 0
                  ? 'Cadastre suas receitas para calcular.'
                  : '${_percentualFixos.toStringAsFixed(1)}% da sua renda (${_formatarValor(_totalReceitas)}) está comprometida com gastos fixos (${_formatarValor(_totalFixos)}).',
              percentual: _percentualFixos.clamp(0, 100) / 100,
              corBarra: _percentualFixos > 70
                  ? Colors.red
                  : _percentualFixos > 50
                  ? Colors.orange
                  : Colors.green,
            ),
            const SizedBox(height: 20),

            // SEÇÃO: ALERTAS
            _secaoTitulo('⚠️ Alertas'),
            const SizedBox(height: 12),

            // Gasto acima da média
            _cardAlerta(
              icone: Icons.warning_amber,
              cor: Colors.orange,
              titulo: 'Média diária de gastos',
              conteudo:
                  'Sua média diária este mês é ${_formatarValor(_mediaGastosDiarios)}.',
              subtexto: _mediaGastosDiarios > 50
                  ? 'Atenção: média acima de R\$ 50,00 por dia.'
                  : 'Sua média diária está controlada.',
              destaque: _mediaGastosDiarios > 50,
            ),
            const SizedBox(height: 12),

            // Gastos inesperados
            _cardAlerta(
              icone: Icons.error_outline,
              cor: Colors.red,
              titulo: 'Gastos inesperados',
              conteudo: _totalInesperados == 0
                  ? 'Nenhum gasto inesperado este mês. Ótimo!'
                  : 'Você teve ${_formatarValor(_totalInesperados)} em gastos inesperados este mês.',
              subtexto: _totalInesperados > 0 && _totalMesAtual > 0
                  ? '${(_totalInesperados / _totalMesAtual * 100).toStringAsFixed(1)}% dos seus gastos não estavam previstos.'
                  : '',
              destaque: _totalInesperados > 0,
            ),
            const SizedBox(height: 20),

            // SEÇÃO: META DE ECONOMIA
            _secaoTitulo('🎯 Meta de Economia'),
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Defina sua meta mensal de economia',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _metaController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Ex: 500,00',
                              prefixText: 'R\$ ',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () {
                            final valor = double.tryParse(
                              _metaController.text.replaceAll(',', '.'),
                            );
                            if (valor != null && valor > 0) {
                              setState(() => _metaEconomia = valor);
                            }
                          },
                          child: const Text('Definir'),
                        ),
                      ],
                    ),
                    if (_metaEconomia > 0) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Economia atual: ${_formatarValor(_economiaAtual)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _economiaAtual >= _metaEconomia
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: (_economiaAtual / _metaEconomia).clamp(0, 1),
                        backgroundColor: Colors.grey[200],
                        color: _economiaAtual >= _metaEconomia
                            ? Colors.green
                            : Colors.blue,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _economiaAtual >= _metaEconomia
                            ? '🎉 Meta atingida! Você economizou ${_formatarValor(_economiaAtual)}.'
                            : 'Faltam ${_formatarValor(_metaEconomia - _economiaAtual)} para atingir sua meta.',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // SEÇÃO: DICA DE ECONOMIA
            _secaoTitulo('💡 Dica do Mês'),
            const SizedBox(height: 12),
            Card(
              color: Colors.blue[50],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb, color: Colors.blue[700], size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Baseado em: $_categoriaMaisGasta',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _dicasPorCategoria[_categoriaMaisGasta] ??
                                'Continue monitorando seus gastos para identificar oportunidades de economia.',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _secaoTitulo(String titulo) {
    return Text(
      titulo,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }

  Widget _cardInsight({
    required IconData icone,
    required Color cor,
    required String titulo,
    required String conteudo,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: cor.withOpacity(0.15),
              child: Icon(icone, color: cor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    conteudo,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardInsightComBarra({
    required IconData icone,
    required Color cor,
    required String titulo,
    required String conteudo,
    required double percentual,
    required Color corBarra,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: cor.withOpacity(0.15),
                  child: Icon(icone, color: cor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        conteudo,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: percentual,
              backgroundColor: Colors.grey[200],
              color: corBarra,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardAlerta({
    required IconData icone,
    required Color cor,
    required String titulo,
    required String conteudo,
    required String subtexto,
    required bool destaque,
  }) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: destaque
            ? BorderSide(color: cor.withOpacity(0.5), width: 1.5)
            : BorderSide.none,
      ),
      color: destaque ? cor.withOpacity(0.05) : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: cor.withOpacity(0.15),
              child: Icon(icone, color: cor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    conteudo,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  if (subtexto.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtexto,
                      style: TextStyle(
                        fontSize: 12,
                        color: destaque ? cor : Colors.grey,
                        fontWeight: destaque
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
