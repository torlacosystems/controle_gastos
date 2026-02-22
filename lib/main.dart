import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'gasto.dart';
import 'forma_pagamento.dart';
import 'pessoa.dart';
import 'configuracoes_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(GastoAdapter());
  Hive.registerAdapter(FormaPagamentoAdapter());
  Hive.registerAdapter(PessoaAdapter());
  await Hive.openBox<Gasto>('gastos');
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
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
  late Box<FormaPagamento> _formasPagamentoBox;
  late Box<Pessoa> _pessoasBox;

  @override
  void initState() {
    super.initState();
    _gastosBox = Hive.box<Gasto>('gastos');
    _formasPagamentoBox = Hive.box<FormaPagamento>('formas_pagamento');
    _pessoasBox = Hive.box<Pessoa>('pessoas');
  }

  double get _totalMes {
    return _gastosBox.values.fold(0, (soma, gasto) => soma + gasto.valor);
  }

  String _formatarValor(double valor) {
    return valor.toStringAsFixed(2).replaceAll('.', ',');
  }

  String _formatarData(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
  }

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
      default:
        return Icons.category;
    }
  }

  bool get _cadastroCompleto {
    return _formasPagamentoBox.isNotEmpty && _pessoasBox.isNotEmpty;
  }

  void _abrirAdicionarGasto() async {
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

    final novoGasto = await Navigator.push<Gasto>(
      context,
      MaterialPageRoute(builder: (context) => const AdicionarGastoScreen()),
    );

    if (novoGasto != null) {
      await _gastosBox.add(novoGasto);
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

  void _deletarGasto(int index) async {
    await _gastosBox.deleteAt(index);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final gastos = _gastosBox.values.toList().reversed.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus Gastos'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
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
                  'Total do mês',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  'R\$ ${_formatarValor(_totalMes)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: gastos.isEmpty
                ? const Center(
                    child: Text(
                      'Nenhum gasto ainda.\nToque em + para adicionar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    itemCount: gastos.length,
                    itemBuilder: (context, index) {
                      final gasto = gastos[index];
                      final boxIndex = _gastosBox.values.toList().indexOf(
                        gasto,
                      );
                      return Dismissible(
                        key: Key(gasto.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.red,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (direction) {
                          _deletarGasto(boxIndex);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Gasto removido')),
                          );
                        },
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            child: Icon(
                              _iconeCategoria(gasto.categoria),
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          title: Text(
                            gasto.categoria,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${_formatarData(gasto.data)}${gasto.estabelecimento.isNotEmpty ? ' • ${gasto.estabelecimento}' : ''}${gasto.descricao.isNotEmpty ? ' • ${gasto.descricao}' : ''}',
                          ),
                          trailing: Text(
                            'R\$ ${_formatarValor(gasto.valor)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: 230,
            child: FloatingActionButton.extended(
              heroTag: 'config',
              onPressed: _abrirConfiguracoes,
              icon: const Icon(Icons.settings),
              label: const Text('Configurações Iniciais'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 230,
            child: FloatingActionButton.extended(
              heroTag: 'novo',
              onPressed: _abrirAdicionarGasto,
              icon: const Icon(Icons.add),
              label: const Text('Inserir Novo Gasto'),
            ),
          ),
        ],
      ),
    );
  }
}

class AdicionarGastoScreen extends StatefulWidget {
  const AdicionarGastoScreen({super.key});

  @override
  State<AdicionarGastoScreen> createState() => _AdicionarGastoScreenState();
}

class _AdicionarGastoScreenState extends State<AdicionarGastoScreen> {
  final _valorController = TextEditingController();
  final _descricaoController = TextEditingController();
  final _estabelecimentoController = TextEditingController();
  String _categoriaSelecionada = 'Alimentação';
  DateTime _dataSelecionada = DateTime.now();
  FormaPagamento? _formaPagamentoSelecionada;
  Pessoa? _pessoaSelecionada;
  String _tipoGasto = 'Variável';
  bool _parcelado = false;
  int _numeroParcelas = 1;
  bool _recorrente = false;

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
    _formaPagamentoSelecionada = _formasPagamentoBox.values.first;
    _pessoaSelecionada = _pessoasBox.values.first;
  }

  String _formatarData(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
  }

  Future<void> _selecionarData() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dataSelecionada,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dataSelecionada = picked;
      });
    }
  }

  void _salvarGasto() {
    String textoValor = _valorController.text.replaceAll('.', ',');

    if (!textoValor.contains(',')) {
      textoValor = '$textoValor,00';
    }

    final valor = double.tryParse(textoValor.replaceAll(',', '.'));

    if (valor == null || valor <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Informe um valor válido')));
      return;
    }

    final novoGasto = Gasto(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      descricao: _descricaoController.text,
      valor: valor,
      categoria: _categoriaSelecionada,
      data: _dataSelecionada,
      formaPagamento: _formaPagamentoSelecionada!.descricao,
      pessoa: _pessoaSelecionada!.nome,
      tipoGasto: _tipoGasto,
      parcelado: _parcelado,
      numeroParcelas: _parcelado ? _numeroParcelas : 1,
      estabelecimento: _estabelecimentoController.text,
      recorrente: _recorrente,
    );

    Navigator.pop(context, novoGasto);
  }

  @override
  Widget build(BuildContext context) {
    final formas = _formasPagamentoBox.values.toList();
    final pessoas = _pessoasBox.values.toList();

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Novo Gasto'),
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
                    onTap: () {
                      setState(() {
                        _categoriaSelecionada = cat['nome'];
                      });
                    },
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
                onChanged: (value) {
                  setState(() {
                    _formaPagamentoSelecionada = value;
                  });
                },
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
                onChanged: (value) {
                  setState(() {
                    _pessoaSelecionada = value;
                  });
                },
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
              const SizedBox(height: 8),
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
                  child: const Text(
                    'Salvar Gasto',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
