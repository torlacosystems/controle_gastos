import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'receita.dart';
import 'currency_formatter.dart';

class MultiplasReceitasScreen extends StatefulWidget {
  const MultiplasReceitasScreen({super.key});

  @override
  State<MultiplasReceitasScreen> createState() =>
      _MultiplasReceitasScreenState();
}

class _MultiplasReceitasScreenState
    extends State<MultiplasReceitasScreen> {
  late Box<Receita> _receitasBox;

  // Campos compartilhados
  String _categoriaSelecionada = 'Salário';
  String _tipoReceita = 'Fixo';
  DateTime _data = DateTime.now();
  bool _recorrente = false;

  // Linhas de itens
  final List<Map<String, TextEditingController>> _linhas = [];
  final List<bool> _confirmadas = [];
  final List<int> _linhasIds = [];
  int _nextId = 0;

  static const List<String> _categoriasFixas = [
    'Salário', 'Freelance', 'Investimento', 'Aluguel', 'Presente',
    'Benefício', 'Outros',
  ];

  List<String> get _categorias => List.unmodifiable(_categoriasFixas);

  @override
  void initState() {
    super.initState();
    _receitasBox = Hive.box<Receita>('receitas');
    _adicionarLinha();
  }

  @override
  void dispose() {
    for (final l in _linhas) {
      l['desc']!.dispose();
      l['valor']!.dispose();
    }
    super.dispose();
  }

  void _adicionarLinha() {
    setState(() {
      _linhas.add({
        'desc': TextEditingController(),
        'valor': TextEditingController(),
      });
      _confirmadas.add(false);
      _linhasIds.add(_nextId++);
    });
  }

  void _removerLinhaById(int id) {
    final i = _linhasIds.indexOf(id);
    if (i == -1) return;
    _linhas[i]['desc']!.dispose();
    _linhas[i]['valor']!.dispose();
    setState(() {
      _linhas.removeAt(i);
      _confirmadas.removeAt(i);
      _linhasIds.removeAt(i);
    });
  }

  void _confirmarLinha(int i) {
    final desc = _linhas[i]['desc']!.text.trim();
    final v =
        double.tryParse(_linhas[i]['valor']!.text.replaceAll('.', '').replaceAll(',', '.'));
    if (desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe a descrição')),
      );
      return;
    }
    if (v == null || v <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um valor válido')),
      );
      return;
    }
    setState(() => _confirmadas[i] = true);
  }

  void _editarLinha(int i) {
    setState(() => _confirmadas[i] = false);
  }

  String _formatarData(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _formatarValor(double v) =>
      v.toStringAsFixed(2).replaceAll('.', ',');

  Future<void> _selecionarData() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _data = picked);
  }

  Future<int?> _perguntarMeses() async {
    int mesesSelecionados = 1;
    return showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Replicar para próximos meses?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Essas receitas são fixas e recorrentes. Deseja criá-las para os próximos meses?',
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
                            fontSize: 32, fontWeight: FontWeight.bold),
                      ),
                      const Text('meses',
                          style: TextStyle(color: Colors.grey)),
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
  }

  Future<void> _salvar() async {
    final confirmados = _confirmadas.where((c) => c).length;
    if (confirmados == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Confirme ao menos um item antes de salvar')),
      );
      return;
    }

    int meses = 1;
    if (_tipoReceita == 'Fixo' && _recorrente) {
      final resposta = await _perguntarMeses();
      if (resposta == null) return;
      meses = resposta;
    }

    final baseMs = DateTime.now().millisecondsSinceEpoch;
    for (int li = 0; li < _linhas.length; li++) {
      if (!_confirmadas[li]) continue;
      final l = _linhas[li];
      final v =
          double.tryParse(l['valor']!.text.replaceAll('.', '').replaceAll(',', '.'));
      if (v == null || v <= 0) continue;
      for (int m = 0; m < meses; m++) {
        final r = Receita(
          id: '${baseMs}_${li}_$m',
          descricao: l['desc']!.text,
          valor: v,
          categoria: _categoriaSelecionada,
          data: DateTime(_data.year, _data.month + m, _data.day),
          pessoa: '',
          recorrente: _recorrente,
          tipoReceita: _tipoReceita,
          detalhado: true,
        );
        await _receitasBox.add(r);
      }
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Widget _switchCompact(
      String label, bool value, ValueChanged<bool> onChanged) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 11, color: Colors.black87),
              textAlign: TextAlign.center),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final categorias = _categorias;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        title: const Text('Múltiplas Receitas'),
      ),
      body: Column(
        children: [
          // ── Campos compartilhados ──
          Container(
            color: Colors.grey[50],
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                // Categoria + Tipo
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: ValueKey(_categoriaSelecionada),
                        initialValue: _categoriaSelecionada,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Categoria',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10),
                        ),
                        items: categorias
                            .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c,
                                    overflow:
                                        TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: (v) => setState(
                            () => _categoriaSelecionada = v!),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: ValueKey(_tipoReceita),
                        initialValue: _tipoReceita,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Tipo de Receita',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'Fixo',
                              child: Text('Valor Fixo')),
                          DropdownMenuItem(
                              value: 'Variável',
                              child: Text('Valor Variável')),
                        ],
                        onChanged: (v) =>
                            setState(() => _tipoReceita = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Data
                GestureDetector(
                  onTap: _selecionarData,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[400]!),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 18, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text('Data: ${_formatarData(_data)}',
                            style: const TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // Switch Recorrente
                Row(
                  children: [
                    _switchCompact('Recorrente', _recorrente,
                        (v) => setState(() => _recorrente = v)),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // ── Lista de itens ──
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              itemCount: _linhas.length,
              itemBuilder: (context, i) {
                final confirmado = _confirmadas[i];
                final l = _linhas[i];
                final linhaId = _linhasIds[i];

                if (confirmado) {
                  final v = double.tryParse(
                          l['valor']!.text.replaceAll('.', '').replaceAll(',', '.')) ??
                      0;
                  return Dismissible(
                    key: Key('receita_linha_$linhaId'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child:
                          const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (_) => showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Excluir item?'),
                        content: Text(
                            'Deseja remover "${l['desc']!.text}" da lista?'),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(ctx, false),
                            child: const Text('Cancelar'),
                          ),
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(ctx, true),
                            style: TextButton.styleFrom(
                                foregroundColor: Colors.red),
                            child: const Text('Excluir'),
                          ),
                        ],
                      ),
                    ),
                    onDismissed: (_) => _removerLinhaById(linhaId),
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.check_circle,
                            color: Colors.green),
                        title: Text(l['desc']!.text,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'R\$ ${_formatarValor(v)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              onPressed: () => _editarLinha(i),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                // ── Item em edição ──
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: l['desc'],
                          decoration: const InputDecoration(
                            hintText: 'Ex: Salário',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: l['valor'],
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          inputFormatters: [CurrencyInputFormatter()],
                          decoration: const InputDecoration(
                            hintText: '0,00',
                            prefixText: 'R\$ ',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 6, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.check_circle,
                            color: Colors.green, size: 28),
                        onPressed: () => _confirmarLinha(i),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // ── Botão adicionar linha ──
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: OutlinedButton.icon(
              onPressed: _confirmadas.isNotEmpty && !_confirmadas.last
                  ? null
                  : _adicionarLinha,
              icon: const Icon(Icons.add),
              label: const Text('Adicionar item'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
              ),
            ),
          ),
          // ── Botão salvar ──
          Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16,
                MediaQuery.of(context).padding.bottom + 12),
            child: ElevatedButton.icon(
              onPressed: _salvar,
              icon: const Icon(Icons.save),
              label: const Text('Salvar Todos'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(44),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
