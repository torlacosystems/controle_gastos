import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'gasto.dart';
import 'receita.dart';
import 'forma_pagamento.dart';
import 'pessoa.dart';
import 'orcamento.dart';
import 'configuracoes_screen.dart';
import 'configuracoes_sistema_screen.dart';
import 'todos_registros_screen.dart';
import 'splash_screen.dart';
import 'relatorios_screen.dart';
import 'insights_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'backup_screen.dart';
import 'atualizar_parcelas_result.dart';
import 'fade_route.dart';
import 'app_settings.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(GastoAdapter());
  Hive.registerAdapter(ReceitaAdapter());
  Hive.registerAdapter(FormaPagamentoAdapter());
  Hive.registerAdapter(PessoaAdapter());
  Hive.registerAdapter(OrcamentoAdapter());
  await Hive.openBox<Gasto>('gastos');
  await Hive.openBox<Receita>('receitas');
  await Hive.openBox<FormaPagamento>('formas_pagamento');
  await Hive.openBox<Pessoa>('pessoas');
  await Hive.openBox<Orcamento>('orcamentos');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'Controle de Gastos',
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('pt', 'BR')],
          locale: const Locale('pt', 'BR'),
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          themeMode: themeMode,
          home: const SplashScreen(),
        );
      },
    );
  }
}
// ── HOME ──────────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Box<Gasto> _gastosBox;
  late Box<Receita> _receitasBox;
  late Box<FormaPagamento> _formasPagamentoBox;
  late Box<Pessoa> _pessoasBox;

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

  @override
  void initState() {
    super.initState();
    _gastosBox = Hive.box<Gasto>('gastos');
    _receitasBox = Hive.box<Receita>('receitas');
    _formasPagamentoBox = Hive.box<FormaPagamento>('formas_pagamento');
    _pessoasBox = Hive.box<Pessoa>('pessoas');
  }

  double get _totalGastosMes {
    final agora = DateTime.now();
    return _gastosBox.values
        .where((g) => g.data.month == agora.month && g.data.year == agora.year)
        .fold(0, (soma, g) => soma + g.valor);
  }

  double get _totalReceitasMes {
    final agora = DateTime.now();
    return _receitasBox.values
        .where((r) => r.data.month == agora.month && r.data.year == agora.year)
        .fold(0, (soma, r) => soma + r.valor);
  }

  double get _saldo => _totalReceitasMes - _totalGastosMes;

  String _formatarValor(double valor) =>
      valor.toStringAsFixed(2).replaceAll('.', ',');

  String _formatarData(DateTime data) =>
      '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';

  IconData _iconeCategoria(String categoria) {
    switch (categoria) {
      case 'Alimentação':
        return Icons.restaurant;
      case 'Mercado':
        return Icons.shopping_cart;
      case 'Transporte':
        return Icons.directions_car;
      case 'Saúde':
        return Icons.health_and_safety;
      case 'Lazer':
        return Icons.movie;
      case 'Moradia':
        return Icons.home;
      case 'Educação':
        return Icons.school;
      case 'Salário':
        return Icons.work;
      case 'Freelance':
        return Icons.computer;
      case 'Investimento':
        return Icons.trending_up;
      case 'Presente':
        return Icons.card_giftcard;
      case 'Benefício':
        return Icons.volunteer_activism;
      default:
        return Icons.category;
    }
  }

  bool get _cadastroCompleto =>
      _formasPagamentoBox.isNotEmpty && _pessoasBox.isNotEmpty;

  void _abrirAdicionarGasto({Gasto? gasto, int? index}) async {
    if (!_cadastroCompleto) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cadastre ao menos uma forma de pagamento e uma pessoa nas Configurações Iniciais',
          ),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    final resultado = await Navigator.push(
      context,
      FadeRoute(page: AdicionarGastoScreen(gasto: gasto)),
    );
    if (resultado != null) {
      if (resultado is List<Gasto>) {
        for (final parcela in resultado) {
          await _gastosBox.add(parcela);
        }
      } else if (resultado is Gasto) {
        if (index != null) {
          await _gastosBox.putAt(index, resultado);
        } else {
          await _gastosBox.add(resultado);
        }
      } else if (resultado is AtualizarParcelasResult) {
        await _gastosBox.putAt(index!, resultado.gastoAtual);
        for (final entry in resultado.proximas) {
          await _gastosBox.putAt(entry.key, entry.value);
        }
      }
      setState(() {});
    }
  }

  void _abrirAdicionarReceita({Receita? receita, int? index}) async {
    if (!_cadastroCompleto) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cadastre ao menos uma forma de pagamento e uma pessoa nas Configurações Iniciais',
          ),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    final resultado = await Navigator.push<dynamic>(
      context,
      FadeRoute(page: AdicionarReceitaScreen(receita: receita)),
    );
    if (resultado != null) {
      if (resultado is List<Receita>) {
        for (final r in resultado) {
          await _receitasBox.add(r);
        }
      } else if (resultado is Receita) {
        if (index != null) {
          await _receitasBox.putAt(index, resultado);
        } else {
          await _receitasBox.add(resultado);
        }
      }
      setState(() {});
    }
  }

  void _abrirConfiguracoes() async {
    await Navigator.push(context, FadeRoute(page: const ConfiguracoesScreen()));
    setState(() {});
  }

  void _abrirConfiguracoesSistema() async {
    await Navigator.push(
      context,
      FadeRoute(page: const ConfiguracoesSistemaScreen()),
    );
    setState(() {});
  }

  void _abrirTodosRegistros() async {
    await Navigator.push(
      context,
      FadeRoute(page: const TodosRegistrosScreen()),
    );
    setState(() {});
  }

  void _abrirRelatorios() async {
    await Navigator.push(context, FadeRoute(page: const RelatoriosScreen()));
  }

  void _abrirInsights() async {
    await Navigator.push(context, FadeRoute(page: const InsightsScreen()));
  }

  void _abrirBackup() async {
    await Navigator.push(context, FadeRoute(page: const BackupScreen()));
    setState(() {});
  }

  List<Map<String, dynamic>> get _itensMisturados {
    final agora = DateTime.now();
    final List<Map<String, dynamic>> itens = [];
    for (int i = 0; i < _gastosBox.length; i++) {
      final g = _gastosBox.getAt(i);
      if (g != null &&
          g.data.month == agora.month &&
          g.data.year == agora.year) {
        itens.add({'tipo': 'gasto', 'item': g, 'index': i});
      }
    }
    for (int i = 0; i < _receitasBox.length; i++) {
      final r = _receitasBox.getAt(i);
      if (r != null &&
          r.data.month == agora.month &&
          r.data.year == agora.year) {
        itens.add({'tipo': 'receita', 'item': r, 'index': i});
      }
    }
    itens.sort((a, b) {
      final DateTime dataA = a['tipo'] == 'gasto'
          ? (a['item'] as Gasto).data
          : (a['item'] as Receita).data;
      final DateTime dataB = b['tipo'] == 'gasto'
          ? (b['item'] as Gasto).data
          : (b['item'] as Receita).data;
      return dataB.compareTo(dataA);
    });
    return itens.take(5).toList();
  }

  Widget _botaoNavegacao(IconData icone, String label, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 9),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final itens = _itensMisturados;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.home, color: Colors.white),
            SizedBox(width: 8),
            Text('Home'),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            tooltip: 'Configurações',
            onPressed: _abrirConfiguracoesSistema,
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _botaoNavegacao(
              Icons.tune,
              'Cadastro Inicial',
              _abrirConfiguracoes,
            ),
            _botaoNavegacao(
              Icons.add_circle,
              'Novo Gasto',
              () => _abrirAdicionarGasto(),
            ),
            _botaoNavegacao(
              Icons.attach_money,
              'Nova Receita',
              () => _abrirAdicionarReceita(),
            ),
            _botaoNavegacao(Icons.list_alt, 'Registros', _abrirTodosRegistros),
            _botaoNavegacao(Icons.bar_chart, 'Relatórios', _abrirRelatorios),
            _botaoNavegacao(Icons.lightbulb, 'Insights', _abrirInsights),
            _botaoNavegacao(Icons.backup, 'Backup', _abrirBackup),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            color: Theme.of(context).colorScheme.primary,
            child: Column(
              children: [
                const Text(
                  'Total de Gastos do Mês',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  'R\$ ${_formatarValor(_totalGastosMes)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        const Text(
                          'Receitas',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        Text(
                          'R\$ ${_formatarValor(_totalReceitasMes)}',
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        const Text(
                          'Saldo',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        Text(
                          'R\$ ${_formatarValor(_saldo)}',
                          style: TextStyle(
                            color: _saldo >= 0
                                ? Colors.greenAccent
                                : Colors.redAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Lançamentos de ${_nomesMeses[DateTime.now().month - 1]}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: _abrirTodosRegistros,
                  child: const Text('Ver todos'),
                ),
              ],
            ),
          ),
          Expanded(
            child: itens.isEmpty
                ? const Center(
                    child: Text(
                      'Nenhum lançamento este mês.\nToque em + para adicionar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    itemCount: itens.length,
                    itemBuilder: (context, index) {
                      final item = itens[index];
                      final isGasto = item['tipo'] == 'gasto';
                      final boxIndex = item['index'] as int;
                      final String categoria = isGasto
                          ? (item['item'] as Gasto).categoria
                          : (item['item'] as Receita).categoria;
                      final double valor = isGasto
                          ? (item['item'] as Gasto).valor
                          : (item['item'] as Receita).valor;
                      final DateTime data = isGasto
                          ? (item['item'] as Gasto).data
                          : (item['item'] as Receita).data;
                      final String descricao = isGasto
                          ? (item['item'] as Gasto).descricao
                          : (item['item'] as Receita).descricao;

                      return Dismissible(
                        key: Key(
                          isGasto
                              ? (item['item'] as Gasto).id
                              : (item['item'] as Receita).id,
                        ),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.red,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (direction) async {
                          return await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(
                                'Excluir ${isGasto ? 'Gasto' : 'Receita'}',
                              ),
                              content: Text(
                                'Tem certeza que deseja excluir este ${isGasto ? 'gasto' : 'receita'}?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancelar'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                  child: const Text('Excluir'),
                                ),
                              ],
                            ),
                          );
                        },
                        onDismissed: (direction) async {
                          if (isGasto) {
                            await _gastosBox.deleteAt(boxIndex);
                          } else {
                            await _receitasBox.deleteAt(boxIndex);
                          }
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${isGasto ? 'Gasto' : 'Receita'} removido',
                              ),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                color: isGasto ? Colors.red : Colors.green,
                                width: 4,
                              ),
                            ),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isGasto
                                  ? Colors.red[50]
                                  : Colors.green[50],
                              child: Icon(
                                _iconeCategoria(categoria),
                                color: isGasto ? Colors.red : Colors.green,
                              ),
                            ),
                            title: Text(
                              categoria,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${isGasto ? 'Gasto' : 'Receita'} • ${_formatarData(data)}${descricao.isNotEmpty ? ' • $descricao' : ''}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${isGasto ? '-' : '+'} R\$ ${_formatarValor(valor)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: isGasto ? Colors.red : Colors.green,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18),
                                  onPressed: () {
                                    if (isGasto) {
                                      _abrirAdicionarGasto(
                                        gasto: item['item'] as Gasto,
                                        index: boxIndex,
                                      );
                                    } else {
                                      _abrirAdicionarReceita(
                                        receita: item['item'] as Receita,
                                        index: boxIndex,
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ── RESULTADO ATUALIZAR PARCELAS ──────────────────────────────────────────────

// ── ADICIONAR GASTO ───────────────────────────────────────────────────────────

class AdicionarGastoScreen extends StatefulWidget {
  final Gasto? gasto;
  const AdicionarGastoScreen({super.key, this.gasto});

  @override
  State<AdicionarGastoScreen> createState() => _AdicionarGastoScreenState();
}

class _AdicionarGastoScreenState extends State<AdicionarGastoScreen> {
  late TextEditingController _valorController;
  late TextEditingController _descricaoController;
  late TextEditingController _estabelecimentoController;
  late String _categoriaSelecionada;
  late DateTime _dataSelecionada;
  FormaPagamento? _formaPagamentoSelecionada;
  Pessoa? _pessoaSelecionada;
  late String _tipoGasto;
  late bool _parcelado;
  late int _numeroParcelas;
  late bool _recorrente;
  late bool _gastoEsperado;

  bool _formaPagamentoOrfa = false;
  bool _pessoaOrfa = false;

  late Box<FormaPagamento> _formasPagamentoBox;
  late Box<Pessoa> _pessoasBox;
  late Box<Gasto> _gastosBox;

  final List<Map<String, dynamic>> _categorias = [
    {'nome': 'Alimentação', 'icone': Icons.restaurant},
    {'nome': 'Mercado', 'icone': Icons.shopping_cart},
    {'nome': 'Transporte', 'icone': Icons.directions_car},
    {'nome': 'Saúde', 'icone': Icons.health_and_safety},
    {'nome': 'Lazer', 'icone': Icons.movie},
    {'nome': 'Moradia', 'icone': Icons.home},
    {'nome': 'Educação', 'icone': Icons.school},
    {'nome': 'Outros', 'icone': Icons.category},
  ];

  @override
  void initState() {
    super.initState();
    _formasPagamentoBox = Hive.box<FormaPagamento>('formas_pagamento');
    _pessoasBox = Hive.box<Pessoa>('pessoas');
    _gastosBox = Hive.box<Gasto>('gastos');

    final g = widget.gasto;
    _valorController = TextEditingController(
      text: g != null ? g.valor.toStringAsFixed(2).replaceAll('.', ',') : '',
    );
    _descricaoController = TextEditingController(text: g?.descricao ?? '');
    _estabelecimentoController = TextEditingController(
      text: g?.estabelecimento ?? '',
    );
    _categoriaSelecionada = g?.categoria ?? 'Alimentação';
    _dataSelecionada = g?.data ?? DateTime.now();
    _tipoGasto = g?.tipoGasto ?? 'Variável';
    _parcelado = g?.parcelado ?? false;
    _numeroParcelas = g?.numeroParcelas ?? 2;
    _recorrente = g?.recorrente ?? false;
    _gastoEsperado = g?.gastoEsperado ?? true;

    final formas = _formasPagamentoBox.values.toList();
    if (g != null) {
      final existe = formas.any((f) => f.descricao == g.formaPagamento);
      if (existe) {
        _formaPagamentoSelecionada = formas.firstWhere(
          (f) => f.descricao == g.formaPagamento,
        );
      } else {
        _formaPagamentoSelecionada = null;
        _formaPagamentoOrfa = true;
      }
    } else {
      _formaPagamentoSelecionada = formas.isNotEmpty ? formas.first : null;
    }

    final pessoas = _pessoasBox.values.toList();
    if (g != null) {
      final existe = pessoas.any((p) => p.nome == g.pessoa);
      if (existe) {
        _pessoaSelecionada = pessoas.firstWhere((p) => p.nome == g.pessoa);
      } else {
        _pessoaSelecionada = null;
        _pessoaOrfa = true;
      }
    } else {
      _pessoaSelecionada = pessoas.isNotEmpty ? pessoas.first : null;
    }
  }

  void _mostrarSnackbarSucesso(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(mensagem),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatarData(DateTime data) =>
      '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';

  Future<void> _selecionarData() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataSelecionada,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _dataSelecionada = picked);
  }

  List<MapEntry<int, Gasto>> _buscarProximasParcelas(
    String grupoId,
    int parcelaAtual,
  ) {
    final List<MapEntry<int, Gasto>> resultado = [];
    for (int i = 0; i < _gastosBox.length; i++) {
      final g = _gastosBox.getAt(i);
      if (g != null &&
          g.grupoId == grupoId &&
          g.grupoId.isNotEmpty &&
          g.numeroParcela > parcelaAtual) {
        resultado.add(MapEntry(i, g));
      }
    }
    resultado.sort(
      (a, b) => a.value.numeroParcela.compareTo(b.value.numeroParcela),
    );
    return resultado;
  }

  Future<void> _salvarGasto() async {
    String textoValor = _valorController.text.replaceAll('.', ',');
    if (!textoValor.contains(',')) textoValor = '$textoValor,00';
    final valor = double.tryParse(textoValor.replaceAll(',', '.'));

    if (valor == null || valor <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Informe um valor válido')));
      return;
    }

    final isEdicao = widget.gasto != null;

    if (_parcelado && !isEdicao) {
      final grupoId = DateTime.now().millisecondsSinceEpoch.toString();
      final valorParcela = valor / _numeroParcelas;
      final List<Gasto> parcelas = [];
      for (int i = 0; i < _numeroParcelas; i++) {
        parcelas.add(
          Gasto(
            id: '${grupoId}_$i',
            descricao:
                '${_descricaoController.text} (${i + 1}/$_numeroParcelas)',
            valor: double.parse(valorParcela.toStringAsFixed(2)),
            categoria: _categoriaSelecionada,
            data: DateTime(
              _dataSelecionada.year,
              _dataSelecionada.month + i,
              _dataSelecionada.day,
            ),
            formaPagamento: _formaPagamentoSelecionada!.descricao,
            pessoa: _pessoaSelecionada!.nome,
            tipoGasto: _tipoGasto,
            parcelado: true,
            numeroParcelas: _numeroParcelas,
            estabelecimento: _estabelecimentoController.text,
            recorrente: _recorrente,
            gastoEsperado: _gastoEsperado,
            grupoId: grupoId,
            numeroParcela: i + 1,
          ),
        );
      }
      _mostrarSnackbarSucesso('Gasto salvo com sucesso!');
      await Future.delayed(const Duration(milliseconds: 300));
      Navigator.pop(context, parcelas);
      return;
    }

    if (isEdicao &&
        widget.gasto!.parcelado &&
        widget.gasto!.grupoId.isNotEmpty) {
      final gastoOriginal = widget.gasto!;
      final proximasParcelas = _buscarProximasParcelas(
        gastoOriginal.grupoId,
        gastoOriginal.numeroParcela,
      );

      final gastoAtualizado = Gasto(
        id: gastoOriginal.id,
        descricao: gastoOriginal.descricao,
        valor: valor,
        categoria: _categoriaSelecionada,
        data: _dataSelecionada,
        formaPagamento: _formaPagamentoSelecionada!.descricao,
        pessoa: _pessoaSelecionada!.nome,
        tipoGasto: _tipoGasto,
        parcelado: true,
        numeroParcelas: gastoOriginal.numeroParcelas,
        estabelecimento: _estabelecimentoController.text,
        recorrente: _recorrente,
        gastoEsperado: _gastoEsperado,
        grupoId: gastoOriginal.grupoId,
        numeroParcela: gastoOriginal.numeroParcela,
      );

      if (proximasParcelas.isNotEmpty) {
        final escolha = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Editar parcelas'),
            content: Text(
              'Esta é a parcela ${gastoOriginal.numeroParcela} de ${gastoOriginal.numeroParcelas}.\n\n'
              'Deseja atualizar só esta parcela ou também as ${proximasParcelas.length} parcela(s) seguinte(s)?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'soEsta'),
                child: const Text('Só esta'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, 'estaEProximas'),
                child: Text('Esta e as próximas (${proximasParcelas.length})'),
              ),
            ],
          ),
        );

        if (escolha == null) return;

        if (escolha == 'estaEProximas') {
          final List<MapEntry<int, Gasto>> proximasAtualizadas = [];
          for (final entry in proximasParcelas) {
            final p = entry.value;
            proximasAtualizadas.add(
              MapEntry(
                entry.key,
                Gasto(
                  id: p.id,
                  descricao: p.descricao,
                  valor: valor,
                  categoria: _categoriaSelecionada,
                  data: p.data,
                  formaPagamento: _formaPagamentoSelecionada!.descricao,
                  pessoa: _pessoaSelecionada!.nome,
                  tipoGasto: _tipoGasto,
                  parcelado: true,
                  numeroParcelas: p.numeroParcelas,
                  estabelecimento: _estabelecimentoController.text,
                  recorrente: _recorrente,
                  gastoEsperado: _gastoEsperado,
                  grupoId: p.grupoId,
                  numeroParcela: p.numeroParcela,
                ),
              ),
            );
          }
          _mostrarSnackbarSucesso('Gasto atualizado com sucesso!');
          await Future.delayed(const Duration(milliseconds: 300));
          Navigator.pop(
            context,
            AtualizarParcelasResult(
              gastoAtual: gastoAtualizado,
              proximas: proximasAtualizadas,
            ),
          );
          return;
        }
      }

      _mostrarSnackbarSucesso('Gasto atualizado com sucesso!');
      await Future.delayed(const Duration(milliseconds: 300));
      Navigator.pop(context, gastoAtualizado);
      return;
    }

    final novoGasto = Gasto(
      id: widget.gasto?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      descricao: _descricaoController.text,
      valor: valor,
      categoria: _categoriaSelecionada,
      data: _dataSelecionada,
      formaPagamento: _formaPagamentoSelecionada!.descricao,
      pessoa: _pessoaSelecionada!.nome,
      tipoGasto: _tipoGasto,
      parcelado: false,
      numeroParcelas: 1,
      estabelecimento: _estabelecimentoController.text,
      recorrente: _recorrente,
      gastoEsperado: _gastoEsperado,
    );

    if (_tipoGasto == 'Fixo' && _recorrente && !isEdicao) {
      int mesesSelecionados = 1;
      final confirmar = await showDialog<int>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            title: const Text('Replicar para próximos meses?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Este gasto é fixo e recorrente. Deseja criá-lo para os próximos meses?',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: mesesSelecionados > 1
                          ? () => setStateDialog(() => mesesSelecionados--)
                          : null,
                    ),
                    Column(
                      children: [
                        Text(
                          '$mesesSelecionados',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'meses',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: mesesSelecionados < 24
                          ? () => setStateDialog(() => mesesSelecionados++)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, 1),
                child: const Text('Só este mês'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, mesesSelecionados),
                child: Text(
                  'Replicar $mesesSelecionados ${mesesSelecionados == 1 ? 'mês' : 'meses'}',
                ),
              ),
            ],
          ),
        ),
      );

      if (confirmar != null && confirmar > 1) {
        final List<Gasto> gastosMeses = [];
        for (int i = 0; i < confirmar; i++) {
          gastosMeses.add(
            Gasto(
              id: '${DateTime.now().millisecondsSinceEpoch}_$i',
              descricao: novoGasto.descricao,
              valor: novoGasto.valor,
              categoria: novoGasto.categoria,
              data: DateTime(
                _dataSelecionada.year,
                _dataSelecionada.month + i,
                _dataSelecionada.day,
              ),
              formaPagamento: novoGasto.formaPagamento,
              pessoa: novoGasto.pessoa,
              tipoGasto: novoGasto.tipoGasto,
              parcelado: false,
              numeroParcelas: 1,
              estabelecimento: novoGasto.estabelecimento,
              recorrente: true,
              gastoEsperado: novoGasto.gastoEsperado,
            ),
          );
        }
        _mostrarSnackbarSucesso('Gasto salvo com sucesso!');
        await Future.delayed(const Duration(milliseconds: 300));
        Navigator.pop(context, gastosMeses);
        return;
      }
    }

    _mostrarSnackbarSucesso(
      isEdicao ? 'Gasto atualizado com sucesso!' : 'Gasto salvo com sucesso!',
    );
    await Future.delayed(const Duration(milliseconds: 300));
    Navigator.pop(context, novoGasto);
  }

  Widget _chipOpcao(String label, bool selecionado, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selecionado
              ? Theme.of(context).colorScheme.primary
              : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selecionado ? Colors.white : Colors.grey[700],
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _avisoOrfao(String mensagem) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        border: Border.all(color: Colors.orange),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Colors.orange, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mensagem,
              style: const TextStyle(fontSize: 13, color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formas = _formasPagamentoBox.values.toList();
    final pessoas = _pessoasBox.values.toList();
    final podeSalvar =
        _formaPagamentoSelecionada != null && _pessoaSelecionada != null;

    final isEdicaoParcela = widget.gasto != null && widget.gasto!.parcelado;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(widget.gasto == null ? 'Novo Gasto' : 'Editar Gasto'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Valor (R\$)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _valorController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
                decoration: const InputDecoration(
                  hintText: '0,00',
                  border: OutlineInputBorder(),
                  prefixText: 'R\$ ',
                ),
                autofocus: true,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 24),

              const Text(
                'Categoria',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categorias.map((cat) {
                  final sel = cat['nome'] == _categoriaSelecionada;
                  return GestureDetector(
                    onTap: () =>
                        setState(() => _categoriaSelecionada = cat['nome']),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: sel
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            cat['icone'],
                            size: 18,
                            color: sel ? Colors.white : Colors.grey[700],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            cat['nome'],
                            style: TextStyle(
                              color: sel ? Colors.white : Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

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
                        'Tipo de Gasto',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _chipOpcao(
                            'Fixo',
                            _tipoGasto == 'Fixo',
                            () => setState(() => _tipoGasto = 'Fixo'),
                          ),
                          const SizedBox(width: 8),
                          _chipOpcao(
                            'Variável',
                            _tipoGasto == 'Variável',
                            () => setState(() => _tipoGasto = 'Variável'),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Recorrente',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Repete todo mês',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          Switch(
                            value: _recorrente,
                            onChanged: (v) => setState(() => _recorrente = v),
                          ),
                        ],
                      ),
                      const Divider(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Gasto Esperado',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Já estava previsto',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          Switch(
                            value: _gastoEsperado,
                            onChanged: (v) =>
                                setState(() => _gastoEsperado = v),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Forma de Pagamento',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (_formaPagamentoOrfa && _formaPagamentoSelecionada == null)
                _avisoOrfao(
                  'A forma de pagamento "${widget.gasto?.formaPagamento}" foi removida. Selecione uma nova.',
                ),
              DropdownButtonFormField<FormaPagamento>(
                value: _formaPagamentoSelecionada,
                hint: const Text('Selecione a forma de pagamento'),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  enabledBorder:
                      _formaPagamentoOrfa && _formaPagamentoSelecionada == null
                      ? const OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.orange,
                            width: 2,
                          ),
                        )
                      : const OutlineInputBorder(),
                ),
                items: formas.map((forma) {
                  return DropdownMenuItem(
                    value: forma,
                    child: Text(
                      '${forma.descricao} • ${forma.tipo} • ${forma.banco}',
                    ),
                  );
                }).toList(),
                onChanged: (value) => setState(() {
                  _formaPagamentoSelecionada = value;
                  _formaPagamentoOrfa = false;
                }),
              ),
              const SizedBox(height: 24),

              if (!isEdicaoParcela) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Parcelado',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Switch(
                      value: _parcelado,
                      onChanged: (v) => setState(() => _parcelado = v),
                    ),
                  ],
                ),
                if (_parcelado) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text(
                        'Número de parcelas: ',
                        style: TextStyle(fontSize: 16),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: _numeroParcelas > 2
                            ? () => setState(() => _numeroParcelas--)
                            : null,
                      ),
                      Text(
                        '$_numeroParcelas',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: _numeroParcelas < 48
                            ? () => setState(() => _numeroParcelas++)
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _valorController.text.isNotEmpty
                        ? 'Valor por parcela: R\$ ${(() {
                            final v = double.tryParse(_valorController.text.replaceAll('.', '').replaceAll(',', '.'));
                            if (v == null) return '0,00';
                            return (v / _numeroParcelas).toStringAsFixed(2).replaceAll('.', ',');
                          })()}'
                        : 'Informe o valor para calcular a parcela',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 24),
              ],

              if (isEdicaoParcela) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    border: Border.all(color: Colors.blue),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.blue,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Parcela ${widget.gasto!.numeroParcela} de ${widget.gasto!.numeroParcelas}. '
                          'Você poderá atualizar só esta ou esta e as próximas ao salvar.',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Text(
                'Pessoa',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (_pessoaOrfa && _pessoaSelecionada == null)
                _avisoOrfao(
                  'A pessoa "${widget.gasto?.pessoa}" foi removida. Selecione uma nova.',
                ),
              DropdownButtonFormField<Pessoa>(
                value: _pessoaSelecionada,
                hint: const Text('Selecione a pessoa'),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  enabledBorder: _pessoaOrfa && _pessoaSelecionada == null
                      ? const OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.orange,
                            width: 2,
                          ),
                        )
                      : const OutlineInputBorder(),
                ),
                items: pessoas.map((pessoa) {
                  return DropdownMenuItem(
                    value: pessoa,
                    child: Text('${pessoa.nome} • ${pessoa.parentesco}'),
                  );
                }).toList(),
                onChanged: (value) => setState(() {
                  _pessoaSelecionada = value;
                  _pessoaOrfa = false;
                }),
              ),
              const SizedBox(height: 24),

              const Text(
                'Estabelecimento (opcional)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _estabelecimentoController,
                decoration: const InputDecoration(
                  hintText: 'Ex: Supermercado Extra',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Data',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _selecionarData,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _formatarData(_dataSelecionada),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Descrição (opcional)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descricaoController,
                decoration: const InputDecoration(
                  hintText: 'Ex: almoço no trabalho',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: podeSalvar ? _salvarGasto : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    widget.gasto == null ? 'Salvar Gasto' : 'Atualizar Gasto',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── ADICIONAR RECEITA ─────────────────────────────────────────────────────────

class AdicionarReceitaScreen extends StatefulWidget {
  final Receita? receita;
  const AdicionarReceitaScreen({super.key, this.receita});

  @override
  State<AdicionarReceitaScreen> createState() => _AdicionarReceitaScreenState();
}

class _AdicionarReceitaScreenState extends State<AdicionarReceitaScreen> {
  late TextEditingController _valorController;
  late TextEditingController _descricaoController;
  late String _categoriaSelecionada;
  late DateTime _dataSelecionada;
  Pessoa? _pessoaSelecionada;
  late bool _recorrente;
  late String _tipoReceita;

  bool _pessoaOrfa = false;

  late Box<Pessoa> _pessoasBox;

  final List<Map<String, dynamic>> _categorias = [
    {'nome': 'Salário', 'icone': Icons.work},
    {'nome': 'Freelance', 'icone': Icons.computer},
    {'nome': 'Investimento', 'icone': Icons.trending_up},
    {'nome': 'Aluguel', 'icone': Icons.home},
    {'nome': 'Presente', 'icone': Icons.card_giftcard},
    {'nome': 'Benefício', 'icone': Icons.volunteer_activism},
    {'nome': 'Outros', 'icone': Icons.category},
  ];

  @override
  void initState() {
    super.initState();
    _pessoasBox = Hive.box<Pessoa>('pessoas');

    final r = widget.receita;
    _valorController = TextEditingController(
      text: r != null ? r.valor.toStringAsFixed(2).replaceAll('.', ',') : '',
    );
    _descricaoController = TextEditingController(text: r?.descricao ?? '');
    _categoriaSelecionada = r?.categoria ?? 'Salário';
    _dataSelecionada = r?.data ?? DateTime.now();
    _recorrente = r?.recorrente ?? false;
    _tipoReceita = r?.tipoReceita ?? 'Fixo';

    final pessoas = _pessoasBox.values.toList();
    if (r != null) {
      final existe = pessoas.any((p) => p.nome == r.pessoa);
      if (existe) {
        _pessoaSelecionada = pessoas.firstWhere((p) => p.nome == r.pessoa);
      } else {
        _pessoaSelecionada = null;
        _pessoaOrfa = true;
      }
    } else {
      _pessoaSelecionada = pessoas.isNotEmpty ? pessoas.first : null;
    }
  }

  void _mostrarSnackbarSucesso(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(mensagem),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatarData(DateTime data) =>
      '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';

  Future<void> _selecionarData() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataSelecionada,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _dataSelecionada = picked);
  }

  Widget _chipOpcao(String label, bool selecionado, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selecionado
              ? Theme.of(context).colorScheme.primary
              : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selecionado ? Colors.white : Colors.grey[700],
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _avisoOrfao(String mensagem) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        border: Border.all(color: Colors.orange),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Colors.orange, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mensagem,
              style: const TextStyle(fontSize: 13, color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _salvarReceita() async {
    String textoValor = _valorController.text.replaceAll('.', ',');
    if (!textoValor.contains(',')) textoValor = '$textoValor,00';
    final valor = double.tryParse(textoValor.replaceAll(',', '.'));

    if (valor == null || valor <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Informe um valor válido')));
      return;
    }

    final isEdicao = widget.receita != null;

    final novaReceita = Receita(
      id:
          widget.receita?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      descricao: _descricaoController.text,
      valor: valor,
      categoria: _categoriaSelecionada,
      data: _dataSelecionada,
      pessoa: _pessoaSelecionada!.nome,
      recorrente: _recorrente,
      tipoReceita: _tipoReceita,
    );

    if (_tipoReceita == 'Fixo' && _recorrente && !isEdicao) {
      int mesesSelecionados = 1;
      final confirmar = await showDialog<int>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            title: const Text('Replicar para próximos meses?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Esta receita é fixa e recorrente. Deseja criá-la para os próximos meses?',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: mesesSelecionados > 1
                          ? () => setStateDialog(() => mesesSelecionados--)
                          : null,
                    ),
                    Column(
                      children: [
                        Text(
                          '$mesesSelecionados',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'meses',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: mesesSelecionados < 24
                          ? () => setStateDialog(() => mesesSelecionados++)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, 1),
                child: const Text('Só este mês'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, mesesSelecionados),
                child: Text(
                  'Replicar $mesesSelecionados ${mesesSelecionados == 1 ? 'mês' : 'meses'}',
                ),
              ),
            ],
          ),
        ),
      );

      if (confirmar != null && confirmar > 1) {
        final List<Receita> receitasMeses = [];
        for (int i = 0; i < confirmar; i++) {
          receitasMeses.add(
            Receita(
              id: '${DateTime.now().millisecondsSinceEpoch}_$i',
              descricao: novaReceita.descricao,
              valor: novaReceita.valor,
              categoria: novaReceita.categoria,
              data: DateTime(
                _dataSelecionada.year,
                _dataSelecionada.month + i,
                _dataSelecionada.day,
              ),
              pessoa: novaReceita.pessoa,
              recorrente: true,
              tipoReceita: novaReceita.tipoReceita,
            ),
          );
        }
        _mostrarSnackbarSucesso('Receita salva com sucesso!');
        await Future.delayed(const Duration(milliseconds: 300));
        Navigator.pop(context, receitasMeses);
        return;
      }
    }

    _mostrarSnackbarSucesso(
      isEdicao
          ? 'Receita atualizada com sucesso!'
          : 'Receita salva com sucesso!',
    );
    await Future.delayed(const Duration(milliseconds: 300));
    Navigator.pop(context, novaReceita);
  }

  @override
  Widget build(BuildContext context) {
    final pessoas = _pessoasBox.values.toList();
    final podeSalvar = _pessoaSelecionada != null;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(widget.receita == null ? 'Nova Receita' : 'Editar Receita'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Valor (R\$)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _valorController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
                decoration: const InputDecoration(
                  hintText: '0,00',
                  border: OutlineInputBorder(),
                  prefixText: 'R\$ ',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 24),

              const Text(
                'Categoria',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categorias.map((cat) {
                  final sel = cat['nome'] == _categoriaSelecionada;
                  return GestureDetector(
                    onTap: () =>
                        setState(() => _categoriaSelecionada = cat['nome']),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: sel
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            cat['icone'],
                            size: 18,
                            color: sel ? Colors.white : Colors.grey[700],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            cat['nome'],
                            style: TextStyle(
                              color: sel ? Colors.white : Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

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
                        'Tipo de Receita',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _chipOpcao(
                            'Fixa',
                            _tipoReceita == 'Fixo',
                            () => setState(() => _tipoReceita = 'Fixo'),
                          ),
                          const SizedBox(width: 8),
                          _chipOpcao(
                            'Variável',
                            _tipoReceita == 'Variável',
                            () => setState(() => _tipoReceita = 'Variável'),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Recorrente',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Repete todo mês',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          Switch(
                            value: _recorrente,
                            onChanged: (v) => setState(() => _recorrente = v),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Pessoa',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (_pessoaOrfa && _pessoaSelecionada == null)
                _avisoOrfao(
                  'A pessoa "${widget.receita?.pessoa}" foi removida. Selecione uma nova.',
                ),
              DropdownButtonFormField<Pessoa>(
                value: _pessoaSelecionada,
                hint: const Text('Selecione a pessoa'),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  enabledBorder: _pessoaOrfa && _pessoaSelecionada == null
                      ? const OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.orange,
                            width: 2,
                          ),
                        )
                      : const OutlineInputBorder(),
                ),
                items: pessoas.map((pessoa) {
                  return DropdownMenuItem(
                    value: pessoa,
                    child: Text('${pessoa.nome} • ${pessoa.parentesco}'),
                  );
                }).toList(),
                onChanged: (value) => setState(() {
                  _pessoaSelecionada = value;
                  _pessoaOrfa = false;
                }),
              ),
              const SizedBox(height: 24),

              const Text(
                'Data',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _selecionarData,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _formatarData(_dataSelecionada),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Descrição (opcional)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descricaoController,
                decoration: const InputDecoration(
                  hintText: 'Ex: salário mensal',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: podeSalvar ? _salvarReceita : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    widget.receita == null
                        ? 'Salvar Receita'
                        : 'Atualizar Receita',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
