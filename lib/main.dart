import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'gasto.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(GastoAdapter());
  await Hive.openBox<Gasto>('gastos');
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

  @override
  void initState() {
    super.initState();
    _gastosBox = Hive.box<Gasto>('gastos');
  }

  double get _totalMes {
    return _gastosBox.values.fold(0, (soma, gasto) => soma + gasto.valor);
  }

  String _formatarValor(double valor) {
    return valor.toStringAsFixed(2).replaceAll('.', ',');
  }

  void _abrirAdicionarGasto() async {
    final novoGasto = await Navigator.push<Gasto>(
      context,
      MaterialPageRoute(builder: (context) => const AdicionarGastoScreen()),
    );

    if (novoGasto != null) {
      await _gastosBox.add(novoGasto);
      setState(() {});
    }
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
                            child: const Icon(Icons.attach_money),
                          ),
                          title: Text(
                            gasto.categoria,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            gasto.descricao.isNotEmpty
                                ? gasto.descricao
                                : 'Sem descrição',
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
      floatingActionButton: FloatingActionButton(
        onPressed: _abrirAdicionarGasto,
        child: const Icon(Icons.add),
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
  String _categoriaSelecionada = 'Alimentação';

  final List<Map<String, dynamic>> _categorias = [
    {'nome': 'Alimentação', 'icone': Icons.restaurant},
    {'nome': 'Transporte', 'icone': Icons.directions_car},
    {'nome': 'Saúde', 'icone': Icons.health_and_safety},
    {'nome': 'Lazer', 'icone': Icons.movie},
    {'nome': 'Moradia', 'icone': Icons.home},
    {'nome': 'Outros', 'icone': Icons.category},
  ];

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
      data: DateTime.now(),
    );

    Navigator.pop(context, novoGasto);
  }

  @override
  Widget build(BuildContext context) {
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
