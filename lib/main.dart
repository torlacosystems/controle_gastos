import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'gasto.dart';
import 'receita.dart';
import 'forma_pagamento.dart';
import 'pessoa.dart';
import 'configuracoes_screen.dart';
import 'todos_registros_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(GastoAdapter());
  Hive.registerAdapter(ReceitaAdapter());
  Hive.registerAdapter(FormaPagamentoAdapter());
  Hive.registerAdapter(PessoaAdapter());
  await Hive.openBox<Gasto>('gastos');
  await Hive.openBox<Receita>('receitas');
  await Hive.openBox<FormaPagamento>('formas_pagamento');
  await Hive.openBox<Pessoa>('pessoas');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Controle de Gastos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

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

  @override
  void initState() {
    super.initState();
    _gastosBox = Hive.box<Gasto>('gastos');
    _receitasBox = Hive.box<Receita>('receitas');
    _formasPagamentoBox = Hive.box<FormaPagamento>('formas_pagamento');
    _pessoasBox = Hive.box<Pessoa>('pessoas');
  }

  double get _totalGastosMes =>
      _gastosBox.values.fold(0, (soma, g) => soma + g.valor);

  double get _totalReceitasMes =>
      _receitasBox.values.fold(0, (soma, r) => soma + r.valor);

  double get _saldo => _totalReceitasMes - _totalGastosMes;

  String _formatarValor(double valor) =>
      valor.toStringAsFixed(2).replaceAll('.', ',');

  String _formatarData(DateTime data) =>
      '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';

  IconData _iconeCategoria(String categoria) {
    switch (categoria) {
      case 'Alimentação':
        return Icons.restaurant;
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
      MaterialPageRoute(
        builder: (context) => AdicionarGastoScreen(gasto: gasto),
      ),
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
    final resultado = await Navigator.push<Receita>(
      context,
      MaterialPageRoute(
        builder: (context) => AdicionarReceitaScreen(receita: receita),
      ),
    );
    if (resultado != null) {
      if (index != null) {
        await _receitasBox.putAt(index, resultado);
      } else {
        await _receitasBox.add(resultado);
      }
      setState(() {});
    }
  }

  void _abrirConfiguracoes() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ConfiguracoesScreen()),
    );
    setState(() {});
  }

  void _abrirTodosRegistros() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TodosRegistrosScreen()),
    );
    setState(() {});
  }

  List<Map<String, dynamic>> get _itensMisturados {
    final List<Map<String, dynamic>> itens = [];
    for (int i = 0; i < _gastosBox.length; i++) {
      itens.add({'tipo': 'gasto', 'item': _gastosBox.getAt(i)!, 'index': i});
    }
    for (int i = 0; i < _receitasBox.length; i++) {
      itens.add({
        'tipo': 'receita',
        'item': _receitasBox.getAt(i)!,
        'index': i,
      });
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 10),
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
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _botaoNavegacao(
              Icons.settings,
              'Configurações',
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
                const Text(
                  'Últimos lançamentos',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_gastosBox.length + _receitasBox.length} total',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          ),
          Expanded(
            child: itens.isEmpty
                ? const Center(
                    child: Text(
                      'Nenhum lançamento ainda.\nToque em + para adicionar.',
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

  late Box<FormaPagamento> _formasPagamentoBox;
  late Box<Pessoa> _pessoasBox;

  final List<Map<String, dynamic>> _categorias = [
    {'nome': 'Alimentação', 'icone': Icons.restaurant},
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

    final formas = _formasPagamentoBox.values.toList();
    _formaPagamentoSelecionada = g != null
        ? formas.firstWhere(
            (f) => f.descricao == g.formaPagamento,
            orElse: () => formas.first,
          )
        : formas.first;

    final pessoas = _pessoasBox.values.toList();
    _pessoaSelecionada = g != null
        ? pessoas.firstWhere(
            (p) => p.nome == g.pessoa,
            orElse: () => pessoas.first,
          )
        : pessoas.first;
  }

  String _formatarData(DateTime data) =>
      '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';

  Future<void> _selecionarData() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dataSelecionada,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _dataSelecionada = picked);
  }

  void _salvarGasto() {
    String textoValor = _valorController.text.replaceAll('.', ',');
    if (!textoValor.contains(',')) textoValor = '$textoValor,00';
    final valor = double.tryParse(textoValor.replaceAll(',', '.'));

    if (valor == null || valor <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Informe um valor válido')));
      return;
    }

    if (_parcelado) {
      final valorParcela = valor / _numeroParcelas;
      final List<Gasto> parcelas = [];
      for (int i = 0; i < _numeroParcelas; i++) {
        parcelas.add(
          Gasto(
            id: '${DateTime.now().millisecondsSinceEpoch}_$i',
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
          ),
        );
      }
      Navigator.pop(context, parcelas);
    } else {
      Navigator.pop(
        context,
        Gasto(
          id:
              widget.gasto?.id ??
              DateTime.now().millisecondsSinceEpoch.toString(),
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
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final formas = _formasPagamentoBox.values.toList();
    final pessoas = _pessoasBox.values.toList();

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
                  final selecionada = cat['nome'] == _categoriaSelecionada;
                  return GestureDetector(
                    onTap: () =>
                        setState(() => _categoriaSelecionada = cat['nome']),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: selecionada
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
                            color: selecionada
                                ? Colors.white
                                : Colors.grey[700],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            cat['nome'],
                            style: TextStyle(
                              color: selecionada
                                  ? Colors.white
                                  : Colors.grey[700],
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
              const Text(
                'Tipo de Gasto',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: ['Fixo', 'Variável'].map((tipo) {
                  final selecionado = tipo == _tipoGasto;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _tipoGasto = tipo),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: selecionado
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          tipo,
                          style: TextStyle(
                            color: selecionado
                                ? Colors.white
                                : Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              const Text(
                'Forma de Pagamento',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<FormaPagamento>(
                value: _formaPagamentoSelecionada,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: formas.map((forma) {
                  return DropdownMenuItem(
                    value: forma,
                    child: Text(
                      '${forma.descricao} • ${forma.tipo} • ${forma.banco}',
                    ),
                  );
                }).toList(),
                onChanged: (value) =>
                    setState(() => _formaPagamentoSelecionada = value),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Parcelado',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Switch(
                    value: _parcelado,
                    onChanged: (value) => setState(() => _parcelado = value),
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
              const Text(
                'Pessoa',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<Pessoa>(
                value: _pessoaSelecionada,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: pessoas.map((pessoa) {
                  return DropdownMenuItem(
                    value: pessoa,
                    child: Text('${pessoa.nome} • ${pessoa.parentesco}'),
                  );
                }).toList(),
                onChanged: (value) =>
                    setState(() => _pessoaSelecionada = value),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recorrente',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Switch(
                    value: _recorrente,
                    onChanged: (value) => setState(() => _recorrente = value),
                  ),
                ],
              ),
              const Text(
                'Gasto que se repete todo mês',
                style: TextStyle(color: Colors.grey, fontSize: 13),
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
                  onPressed: _salvarGasto,
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

    final pessoas = _pessoasBox.values.toList();
    _pessoaSelecionada = r != null
        ? pessoas.firstWhere(
            (p) => p.nome == r.pessoa,
            orElse: () => pessoas.first,
          )
        : pessoas.first;
  }

  String _formatarData(DateTime data) =>
      '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';

  Future<void> _selecionarData() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dataSelecionada,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _dataSelecionada = picked);
  }

  void _salvarReceita() {
    String textoValor = _valorController.text.replaceAll('.', ',');
    if (!textoValor.contains(',')) textoValor = '$textoValor,00';
    final valor = double.tryParse(textoValor.replaceAll(',', '.'));

    if (valor == null || valor <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Informe um valor válido')));
      return;
    }

    Navigator.pop(
      context,
      Receita(
        id:
            widget.receita?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        descricao: _descricaoController.text,
        valor: valor,
        categoria: _categoriaSelecionada,
        data: _dataSelecionada,
        pessoa: _pessoaSelecionada!.nome,
        recorrente: _recorrente,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pessoas = _pessoasBox.values.toList();

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
                  final selecionada = cat['nome'] == _categoriaSelecionada;
                  return GestureDetector(
                    onTap: () =>
                        setState(() => _categoriaSelecionada = cat['nome']),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: selecionada
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
                            color: selecionada
                                ? Colors.white
                                : Colors.grey[700],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            cat['nome'],
                            style: TextStyle(
                              color: selecionada
                                  ? Colors.white
                                  : Colors.grey[700],
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
              const Text(
                'Pessoa',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<Pessoa>(
                value: _pessoaSelecionada,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: pessoas.map((pessoa) {
                  return DropdownMenuItem(
                    value: pessoa,
                    child: Text('${pessoa.nome} • ${pessoa.parentesco}'),
                  );
                }).toList(),
                onChanged: (value) =>
                    setState(() => _pessoaSelecionada = value),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recorrente',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Switch(
                    value: _recorrente,
                    onChanged: (value) => setState(() => _recorrente = value),
                  ),
                ],
              ),
              const Text(
                'Receita que se repete todo mês',
                style: TextStyle(color: Colors.grey, fontSize: 13),
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
                  onPressed: _salvarReceita,
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
