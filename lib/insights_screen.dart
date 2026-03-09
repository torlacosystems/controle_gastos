import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'gasto.dart';
import 'receita.dart';
import 'forma_pagamento.dart';
import 'app_settings.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  late Box<Gasto> _gastosBox;
  late Box<Receita> _receitasBox;
  late Box<FormaPagamento> _formasPagamentoBox;
  double _metaEconomia = 0;
  double? _rendaMensal;
  final TextEditingController _metaController = TextEditingController();

  // Filtro de período
  String _periodoSelecionado = '30d';
  late DateTime _dataInicio;
  late DateTime _dataFim;

  final List<Map<String, String>> _periodos = [
    {'label': 'Hoje', 'key': 'hoje'},
    {'label': '7 dias', 'key': '7d'},
    {'label': '15 dias', 'key': '15d'},
    {'label': '30 dias', 'key': '30d'},
    {'label': '3 meses', 'key': '3m'},
    {'label': '6 meses', 'key': '6m'},
    {'label': '12 meses', 'key': '12m'},
    {'label': 'Todos', 'key': 'todos'},
    {'label': 'Personalizado', 'key': 'Personalizado'},
  ];

  final List<String> _diasSemana = [
    'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo',
  ];

  final Map<String, String> _dicasPorCategoria = {
    'Alimentação': 'Tente cozinhar mais em casa. Pode economizar até 40% comparado a comer fora.',
    'Transporte': 'Considere caronas compartilhadas ou transporte público para reduzir custos.',
    'Lazer': 'Busque opções gratuitas de lazer como parques, eventos culturais e afins.',
    'Saúde': 'Mantenha hábitos preventivos para evitar gastos maiores no futuro.',
    'Moradia': 'Revise contratos de serviços como internet e energia para encontrar planos melhores.',
    'Educação': 'Explore cursos gratuitos online como complemento aos pagos.',
    'Assinaturas': 'Revise suas assinaturas ativas. Cancele as que não usa — pequenos valores mensais somam muito ao longo do ano.',
    'Outros': 'Revise esses gastos — muitos podem ser evitados ou reduzidos.',
  };

  @override
  void initState() {
    super.initState();
    _gastosBox = Hive.box<Gasto>('gastos');
    _receitasBox = Hive.box<Receita>('receitas');
    _formasPagamentoBox = Hive.box<FormaPagamento>('formas_pagamento');
    _aplicarPeriodo('30d');
    _carregarMeta();
    carregarRendaMensal().then((v) {
      if (mounted && v != null) setState(() => _rendaMensal = v);
    });
  }

  void _aplicarPeriodo(String key) {
    final agora = DateTime.now();
    setState(() {
      _periodoSelecionado = key;
      switch (key) {
        case 'hoje':
          _dataInicio = DateTime(agora.year, agora.month, agora.day);
          _dataFim = agora;
        case '7d':
          _dataInicio = agora.subtract(const Duration(days: 7));
          _dataFim = agora;
        case '15d':
          _dataInicio = agora.subtract(const Duration(days: 15));
          _dataFim = agora;
        case '30d':
          _dataInicio = agora.subtract(const Duration(days: 30));
          _dataFim = agora;
        case '3m':
          _dataInicio = agora.subtract(const Duration(days: 90));
          _dataFim = agora;
        case '6m':
          _dataInicio = agora.subtract(const Duration(days: 180));
          _dataFim = agora;
        case '12m':
          _dataInicio = agora.subtract(const Duration(days: 365));
          _dataFim = agora;
        case 'todos':
          _dataInicio = DateTime(2000);
          _dataFim = DateTime(2100);
        default:
          _dataInicio = agora.subtract(const Duration(days: 30));
          _dataFim = agora;
      }
    });
  }

  Future<void> _selecionarData({required bool inicio}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: inicio ? _dataInicio : _dataFim,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (inicio) {
          _dataInicio = picked;
        } else {
          _dataFim = picked;
        }
      });
    }
  }

  Future<void> _carregarMeta() async {
    final prefs = await SharedPreferences.getInstance();
    final valor = prefs.getDouble('meta_economia');
    if (valor != null && valor > 0) {
      setState(() {
        _metaEconomia = valor;
        _metaController.text = valor.toStringAsFixed(2).replaceAll('.', ',');
      });
    }
  }

  Future<void> _salvarMeta(double valor) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('meta_economia', valor);
  }

  @override
  void dispose() {
    _metaController.dispose();
    super.dispose();
  }

  // ── Dados filtrados pelo período ─────────────────────────────────────────

  bool _noperiodo(DateTime data) {
    if (data.isBefore(_dataInicio.subtract(const Duration(days: 1)))) return false;
    if (data.isAfter(_dataFim.add(const Duration(days: 1)))) return false;
    return true;
  }

  List<Gasto> get _gastosPeriodo =>
      _gastosBox.values.where((g) => _noperiodo(g.data)).toList();

  // Número de meses efetivos do período.
  // Quando "todos": conta do primeiro ao último lançamento (igual ao orçamento por categoria).
  // Nos demais: dias / 30 arredondado, mínimo 1.
  int get _mesesEfetivos {
    if (_periodoSelecionado == 'todos' && _gastosPeriodo.isNotEmpty) {
      final primeiro = _gastosPeriodo.map((g) => g.data).reduce((a, b) => a.isBefore(b) ? a : b);
      final ultimo  = _gastosPeriodo.map((g) => g.data).reduce((a, b) => a.isAfter(b)  ? a : b);
      final m = (ultimo.year - primeiro.year) * 12 + (ultimo.month - primeiro.month) + 1;
      return m < 1 ? 1 : m;
    }
    final dias = _dataFim.difference(_dataInicio).inDays + 1;
    final m = (dias / 30.0).round();
    return m < 1 ? 1 : m;
  }

  List<Gasto> get _gastosPeriodoAnterior {
    // "Todos" não tem período anterior comparável.
    if (_periodoSelecionado == 'todos') return [];
    final dias = _dataFim.difference(_dataInicio).inDays + 1;
    final antFim = _dataInicio.subtract(const Duration(days: 1));
    final antInicio = antFim.subtract(Duration(days: dias - 1));
    return _gastosBox.values
        .where((g) =>
            !g.data.isBefore(antInicio.subtract(const Duration(days: 1))) &&
            !g.data.isAfter(antFim.add(const Duration(days: 1))))
        .toList();
  }

  double get _totalPeriodo => _gastosPeriodo.fold(0, (s, g) => s + g.valor);

  double get _totalPeriodoAnterior =>
      _gastosPeriodoAnterior.fold(0, (s, g) => s + g.valor);

  double get _totalReceitas =>
      _receitasBox.values.where((r) => _noperiodo(r.data)).fold(0, (s, r) => s + r.valor);

  double get _totalFixos =>
      _gastosPeriodo.where((g) => g.tipoGasto == 'Fixo').fold(0, (s, g) => s + g.valor);

  double get _totalInesperados =>
      _gastosPeriodo.where((g) => !g.gastoEsperado).fold(0, (s, g) => s + g.valor);

  double get _totalEvitaveis =>
      _gastosPeriodo.where((g) => g.gastoEvitavel).fold(0, (s, g) => s + g.valor);

  Set<String> get _descricoesCredito {
    return _formasPagamentoBox.values
        .where((f) => f.tipo == 'Crédito')
        .map((f) => f.descricao)
        .toSet();
  }

  List<Gasto> get _gastosCartaoCredito =>
      _gastosPeriodo.where((g) => _descricoesCredito.contains(g.formaPagamento)).toList();

  double get _totalCartaoCredito =>
      _gastosCartaoCredito.fold(0, (s, g) => s + g.valor);

  double get _totalEvitaveisCartao =>
      _gastosCartaoCredito.where((g) => g.gastoEvitavel).fold(0, (s, g) => s + g.valor);

  String get _categoriaMaisGasta {
    if (_gastosPeriodo.isEmpty) return 'Nenhum gasto';
    final mapa = <String, double>{};
    for (final g in _gastosPeriodo) {
      mapa[g.categoria] = (mapa[g.categoria] ?? 0) + g.valor;
    }
    return mapa.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  double get _valorCategoriaMaisGasta {
    if (_gastosPeriodo.isEmpty) return 0;
    final mapa = <String, double>{};
    for (final g in _gastosPeriodo) {
      mapa[g.categoria] = (mapa[g.categoria] ?? 0) + g.valor;
    }
    return mapa.entries.reduce((a, b) => a.value > b.value ? a : b).value;
  }

  String get _diaMaisGasta {
    if (_gastosPeriodo.isEmpty) return 'Nenhum dado';
    final mapa = <int, double>{};
    for (final g in _gastosPeriodo) {
      final dia = g.data.weekday;
      mapa[dia] = (mapa[dia] ?? 0) + g.valor;
    }
    final diaMaior = mapa.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    return _diasSemana[diaMaior - 1];
  }

  // Quando "todos" ou período >= 30 dias: média mensal. Caso contrário: média diária.
  bool get _usarMediaMensal =>
      _periodoSelecionado == 'todos' || _dataFim.difference(_dataInicio).inDays >= 30;

  double get _mediaGastos {
    if (_gastosPeriodo.isEmpty) return 0;
    if (_usarMediaMensal) return _totalPeriodo / _mesesEfetivos;
    final dias = _dataFim.difference(_dataInicio).inDays + 1;
    return _totalPeriodo / dias;
  }

  double get _percentualFixos =>
      _totalReceitas > 0 ? (_totalFixos / _totalReceitas) * 100 : 0;

  double get _percentualVariacao {
    if (_totalPeriodoAnterior == 0) return 0;
    return ((_totalPeriodo - _totalPeriodoAnterior) / _totalPeriodoAnterior) * 100;
  }

  double get _economiaAtual => _totalReceitas - _totalPeriodo;

  String _formatarValor(double valor) =>
      'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';

  String _formatarData(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String get _labelPeriodo {
    switch (_periodoSelecionado) {
      case 'hoje':
        return 'Hoje';
      case '7d':
        return 'Últimos 7 dias';
      case '15d':
        return 'Últimos 15 dias';
      case '30d':
        return 'Últimos 30 dias';
      case '3m':
        return 'Últimos 3 meses';
      case '6m':
        return 'Últimos 6 meses';
      case '12m':
        return 'Últimos 12 meses';
      case 'todos':
        if (_gastosBox.isEmpty) return 'Sem registros';
        final datas = _gastosBox.values.map((g) => g.data).toList();
        final primeiro = datas.reduce((a, b) => a.isBefore(b) ? a : b);
        final ultimo = datas.reduce((a, b) => a.isAfter(b) ? a : b);
        return '${_formatarData(primeiro)} – ${_formatarData(ultimo)}';
      default:
        return '${_formatarData(_dataInicio)} – ${_formatarData(_dataFim)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final variacao = _percentualVariacao;
    final aumentou = variacao > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).padding.bottom + 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── FILTRO DE PERÍODO ────────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _periodoSelecionado,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Período',
                        labelStyle: TextStyle(fontSize: 12),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        isDense: true,
                      ),
                      items: _periodos.map((p) => DropdownMenuItem(
                        value: p['key']!,
                        child: Text(p['label']!, style: const TextStyle(fontSize: 13)),
                      )).toList(),
                      onChanged: (v) {
                        if (v == 'Personalizado') setState(() => _periodoSelecionado = 'Personalizado');
                        else if (v != null) _aplicarPeriodo(v);
                      },
                    ),
                    if (_periodoSelecionado == 'Personalizado') ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _selecionarData(inicio: true),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'De',
                                  labelStyle: TextStyle(fontSize: 12),
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  isDense: true,
                                ),
                                child: Text(_formatarData(_dataInicio), style: const TextStyle(fontSize: 13)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _selecionarData(inicio: false),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Até',
                                  labelStyle: TextStyle(fontSize: 12),
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  isDense: true,
                                ),
                                child: Text(_formatarData(_dataFim), style: const TextStyle(fontSize: 13)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else if (_periodoSelecionado != 'todos') ...[
                      const SizedBox(height: 4),
                      Text(
                        '${_formatarData(_dataInicio)} até ${_formatarData(_dataFim)}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── CABEÇALHO DO PERÍODO ─────────────────────────────────────
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
                    _periodoSelecionado == 'todos' ? 'Insights' : 'Insights — $_labelPeriodo',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatarValor(_totalPeriodo),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'total gasto no período',
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── DESTAQUES ────────────────────────────────────────────────
            _secaoTitulo('📊 Destaques do Período'),
            const SizedBox(height: 12),

            _cardInsight(
              icone: Icons.pie_chart,
              cor: Colors.orange,
              titulo: 'Maior categoria de gasto',
              conteudo: _gastosPeriodo.isEmpty
                  ? 'Nenhum gasto registrado no período.'
                  : 'Você mais gastou em $_categoriaMaisGasta (${_formatarValor(_valorCategoriaMaisGasta)}).',
            ),
            const SizedBox(height: 12),

            _cardInsight(
              icone: Icons.calendar_today,
              cor: Colors.purple,
              titulo: 'Dia que você mais gasta',
              conteudo: _gastosPeriodo.isEmpty
                  ? 'Nenhum gasto registrado no período.'
                  : '$_diaMaisGasta é o dia da semana em que você mais costuma gastar.',
            ),
            const SizedBox(height: 12),

            _cardInsight(
              icone: aumentou ? Icons.trending_up : Icons.trending_down,
              cor: aumentou ? Colors.red : Colors.green,
              titulo: 'Comparação com período anterior',
              conteudo: _totalPeriodoAnterior == 0
                  ? 'Sem dados do período anterior para comparar.'
                  : aumentou
                  ? 'Seus gastos aumentaram ${variacao.abs().toStringAsFixed(1)}% em relação ao período anterior (${_formatarValor(_totalPeriodoAnterior)}).'
                  : 'Parabéns! Seus gastos diminuíram ${variacao.abs().toStringAsFixed(1)}% em relação ao período anterior (${_formatarValor(_totalPeriodoAnterior)}).',
            ),
            const SizedBox(height: 12),

            _cardInsightComBarra(
              icone: Icons.lock_clock,
              cor: Colors.blue,
              titulo: '% comprometido com gastos fixos',
              conteudo: _totalReceitas == 0
                  ? 'Cadastre suas receitas para calcular.'
                  : '${_percentualFixos.toStringAsFixed(1)}% da renda (${_formatarValor(_totalReceitas)}) está comprometida com gastos fixos (${_formatarValor(_totalFixos)}).',
              percentual: _percentualFixos.clamp(0, 100) / 100,
              corBarra: _percentualFixos > 70
                  ? Colors.red
                  : _percentualFixos > 50
                  ? Colors.orange
                  : Colors.green,
            ),
            const SizedBox(height: 20),

            // ── ALERTAS ──────────────────────────────────────────────────
            _secaoTitulo('⚠️ Alertas'),
            const SizedBox(height: 12),

            _cardAlerta(
              icone: Icons.warning_amber,
              cor: Colors.orange,
              titulo: _usarMediaMensal ? 'Média mensal de gastos' : 'Média diária de gastos',
              conteudo: 'Sua média ${_usarMediaMensal ? 'mensal' : 'diária'} no período é ${_formatarValor(_mediaGastos)}.',
              subtexto: _usarMediaMensal
                  ? (_mediaGastos > 1500 ? 'Atenção: média acima de R\$ 1.500,00 por mês.' : 'Sua média mensal está controlada.')
                  : (_mediaGastos > 50 ? 'Atenção: média acima de R\$ 50,00 por dia.' : 'Sua média diária está controlada.'),
              destaque: _usarMediaMensal ? _mediaGastos > 1500 : _mediaGastos > 50,
            ),
            if (_rendaMensal != null && _rendaMensal! > 0) ...[
              const SizedBox(height: 12),
              Builder(builder: (context) {
                final rendaDiaria = _rendaMensal! / 30;
                final gastoDiario = _usarMediaMensal
                    ? _mediaGastos / 30
                    : _mediaGastos;
                final pct = rendaDiaria > 0 ? (gastoDiario / rendaDiaria * 100) : 0.0;
                final ok = gastoDiario <= rendaDiaria;
                return _cardAlerta(
                  icone: ok ? Icons.trending_down : Icons.trending_up,
                  cor: ok ? Colors.green : Colors.red,
                  titulo: 'Gasto diário vs renda diária',
                  conteudo:
                      'Gasto médio diário: R\$ ${_formatarValor(gastoDiario)}  •  '
                      'Renda diária: R\$ ${_formatarValor(rendaDiaria)}',
                  subtexto: ok
                      ? 'Você está gastando ${pct.toStringAsFixed(1)}% da sua renda diária. Parabéns!'
                      : 'Você está gastando ${pct.toStringAsFixed(1)}% da sua renda diária — acima do ideal.',
                  destaque: !ok,
                );
              }),
            ],
            const SizedBox(height: 12),

            _cardAlerta(
              icone: Icons.error_outline,
              cor: Colors.red,
              titulo: 'Gastos inesperados',
              conteudo: _totalInesperados == 0
                  ? 'Nenhum gasto inesperado no período. Ótimo!'
                  : 'Você teve ${_formatarValor(_totalInesperados)} em gastos inesperados.',
              subtexto: _totalInesperados > 0 && _totalPeriodo > 0
                  ? '${(_totalInesperados / _totalPeriodo * 100).toStringAsFixed(1)}% dos seus gastos não estavam previstos.'
                  : '',
              destaque: _totalInesperados > 0,
            ),
            const SizedBox(height: 12),

            _cardAlerta(
              icone: Icons.block,
              cor: Colors.deepOrange,
              titulo: 'Gastos evitáveis',
              conteudo: _totalEvitaveis == 0
                  ? 'Nenhum gasto evitável registrado no período. Ótimo!'
                  : 'Você teve ${_formatarValor(_totalEvitaveis)} em gastos que poderiam ter sido evitados.',
              subtexto: _totalEvitaveis > 0 && _totalPeriodo > 0
                  ? '${(_totalEvitaveis / _totalPeriodo * 100).toStringAsFixed(1)}% dos seus gastos eram evitáveis.'
                  : '',
              destaque: _totalEvitaveis > 0,
            ),
            const SizedBox(height: 20),

            // ── CARTÃO DE CRÉDITO ─────────────────────────────────────────
            _secaoTitulo('💳 Cartão de Crédito'),
            const SizedBox(height: 12),

            Builder(builder: (context) {
              final totalCredito = _totalCartaoCredito;
              final pct = _totalPeriodo > 0 ? totalCredito / _totalPeriodo * 100 : 0.0;
              final alerta = pct > 60;
              return _cardInsightComBarra(
                icone: Icons.credit_card,
                cor: Colors.indigo,
                titulo: 'Compras no cartão de crédito',
                conteudo: _gastosCartaoCredito.isEmpty
                    ? 'Nenhuma compra no crédito no período.'
                    : '${_formatarValor(totalCredito)} (${pct.toStringAsFixed(1)}% do total gasto).',
                percentual: pct.clamp(0, 100) / 100,
                corBarra: alerta ? Colors.red : pct > 40 ? Colors.orange : Colors.indigo,
              );
            }),
            const SizedBox(height: 12),

            Builder(builder: (context) {
              final evitaveisCredito = _totalEvitaveisCartao;
              final totalCredito = _totalCartaoCredito;
              final pct = totalCredito > 0 ? evitaveisCredito / totalCredito * 100 : 0.0;
              return _cardAlerta(
                icone: Icons.credit_card_off,
                cor: Colors.red,
                titulo: 'Gastos evitáveis no cartão',
                conteudo: evitaveisCredito == 0
                    ? 'Nenhum gasto evitável no crédito. Ótimo!'
                    : '${_formatarValor(evitaveisCredito)} em gastos evitáveis foram cobrados no cartão de crédito.',
                subtexto: evitaveisCredito > 0
                    ? '${pct.toStringAsFixed(1)}% das compras no crédito eram evitáveis — considere pagar à vista ou evitar esses gastos.'
                    : '',
                destaque: evitaveisCredito > 0,
              );
            }),
            const SizedBox(height: 20),

            // ── META DE ECONOMIA ─────────────────────────────────────────
            _secaoTitulo('🎯 Meta de Economia'),
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Defina sua meta de economia para o período',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _metaController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                              _salvarMeta(valor);
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
                          color: _economiaAtual >= _metaEconomia ? Colors.green : Colors.red,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: (_economiaAtual / _metaEconomia).clamp(0, 1),
                        backgroundColor: Colors.grey[200],
                        color: _economiaAtual >= _metaEconomia ? Colors.green : Colors.blue,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _economiaAtual >= _metaEconomia
                            ? '🎉 Meta atingida! Você economizou ${_formatarValor(_economiaAtual)}.'
                            : 'Faltam ${_formatarValor(_metaEconomia - _economiaAtual)} para atingir sua meta.',
                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── DICA ─────────────────────────────────────────────────────
            _secaoTitulo('💡 Dica do Período'),
            const SizedBox(height: 12),
            Card(
              color: Colors.blue[50],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Widget _secaoTitulo(String titulo) => Text(
        titulo,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      );

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
              backgroundColor: cor.withValues(alpha: 0.15),
              child: Icon(icone, color: cor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(conteudo,
                      style: const TextStyle(fontSize: 13, color: Colors.grey)),
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
                  backgroundColor: cor.withValues(alpha: 0.15),
                  child: Icon(icone, color: cor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(conteudo,
                          style: const TextStyle(fontSize: 13, color: Colors.grey)),
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
        side: destaque ? BorderSide(color: cor.withValues(alpha: 0.5), width: 1.5) : BorderSide.none,
      ),
      color: destaque ? cor.withValues(alpha: 0.05) : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: cor.withValues(alpha: 0.15),
              child: Icon(icone, color: cor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(conteudo,
                      style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  if (subtexto.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtexto,
                      style: TextStyle(
                        fontSize: 12,
                        color: destaque ? cor : Colors.grey,
                        fontWeight: destaque ? FontWeight.bold : FontWeight.normal,
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
