import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'gasto.dart';
import 'forma_pagamento.dart';
import 'pessoa.dart';
import 'currency_formatter.dart';
import 'categoria.dart';

class MultiplosGastosScreen extends StatefulWidget {
  const MultiplosGastosScreen({super.key});

  @override
  State<MultiplosGastosScreen> createState() => _MultiplosGastosScreenState();
}

class _MultiplosGastosScreenState extends State<MultiplosGastosScreen> {
  late Box<Gasto> _gastosBox;
  late Box<FormaPagamento> _formasPagamentoBox;
  late Box<Pessoa> _pessoasBox;
  late Box<Categoria> _categoriasBox;

  // Campos compartilhados
  String _categoriaSelecionada = 'Alimentação';
  String _tipoGasto = 'Variável';
  FormaPagamento? _formaPagamento;
  Pessoa? _pessoa;
  DateTime _data = DateTime.now();
  bool _recorrente = true;
  bool _gastoEsperado = true;
  bool _gastoEvitavel = false;

  // Linhas de itens: cada linha tem controllers + estado confirmado + id único
  final List<Map<String, TextEditingController>> _linhas = [];
  final List<bool> _confirmadas = [];
  final List<int> _linhasIds = [];
  int _nextId = 0;

  static const List<String> _categoriasFixas = [
    'Alimentação', 'Mercado', 'Transporte', 'Saúde', 'Lazer',
    'Moradia', 'Educação', 'Assinaturas',
    'Vestuário', 'Cuidados Pessoais', 'Presentes', 'Outros',
  ];

  List<String> get _categorias {
    final fixasSemOutros =
        _categoriasFixas.where((c) => c != 'Outros').toList();
    final custom = _categoriasBox.values.map((c) => c.nome).toList();
    return [...fixasSemOutros, ...custom, 'Outros'];
  }

  @override
  void initState() {
    super.initState();
    _gastosBox = Hive.box<Gasto>('gastos');
    _formasPagamentoBox = Hive.box<FormaPagamento>('formas_pagamento');
    _pessoasBox = Hive.box<Pessoa>('pessoas');
    _categoriasBox = Hive.box<Categoria>('categorias');

    if (_formasPagamentoBox.isNotEmpty) {
      _formaPagamento = _formasPagamentoBox.getAt(0);
    }
    if (_pessoasBox.isNotEmpty) {
      final sorted = _pessoasBox.values.toList()
        ..sort((a, b) {
          if (a.parentesco == 'Eu Mesmo') return -1;
          if (b.parentesco == 'Eu Mesmo') return 1;
          return a.nome.compareTo(b.nome);
        });
      _pessoa = sorted.first;
    }
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
    final v = double.tryParse(_linhas[i]['valor']!.text.replaceAll('.', '').replaceAll(',', '.'));
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

  String _formatarValor(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

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
                'Esses gastos são fixos e recorrentes. Deseja criá-los para os próximos meses?',
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
        const SnackBar(content: Text('Confirme ao menos um item antes de salvar')),
      );
      return;
    }

    // Pergunta replicação se fixo + recorrente
    int meses = 1;
    if (_tipoGasto == 'Fixo' && _recorrente) {
      final resposta = await _perguntarMeses();
      if (resposta == null) return;
      meses = resposta;
    }

    final baseMs = DateTime.now().millisecondsSinceEpoch;
    for (int li = 0; li < _linhas.length; li++) {
      if (!_confirmadas[li]) continue;
      final l = _linhas[li];
      final v = double.tryParse(l['valor']!.text.replaceAll('.', '').replaceAll(',', '.'));
      if (v == null || v <= 0) continue;
      for (int m = 0; m < meses; m++) {
        final g = Gasto(
          id: '${baseMs}_${li}_$m',
          descricao: l['desc']!.text,
          valor: v,
          categoria: _categoriaSelecionada,
          data: DateTime(_data.year, _data.month + m, _data.day),
          formaPagamento: _formaPagamento?.descricao ?? '',
          pessoa: _pessoa?.nome ?? '',
          tipoGasto: _tipoGasto,
          parcelado: false,
          numeroParcelas: 1,
          estabelecimento: '',
          recorrente: _recorrente,
          gastoEsperado: _gastoEsperado,
          gastoEvitavel: _gastoEvitavel,
          detalhado: true,
        );
        await _gastosBox.add(g);
      }
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Widget _switchCompact(String label, bool value, ValueChanged<bool> onChanged) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: Colors.black87),
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
    final formas = _formasPagamentoBox.values.toList();
    final pessoas = _pessoasBox.values.toList()
      ..sort((a, b) {
        if (a.parentesco == 'Eu Mesmo') return -1;
        if (b.parentesco == 'Eu Mesmo') return 1;
        return a.nome.compareTo(b.nome);
      });
    final categorias = _categorias;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        title: const Text('Múltiplos Gastos'),
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
                                    overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _categoriaSelecionada = v!),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: ValueKey(_tipoGasto),
                        initialValue: _tipoGasto,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Tipo de Gasto',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'Variável',
                              child: Text('Valor Variável')),
                          DropdownMenuItem(
                              value: 'Fixo', child: Text('Valor Fixo')),
                        ],
                        onChanged: (v) => setState(() => _tipoGasto = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Forma de pagamento + Pessoa
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<FormaPagamento>(
                        key: ValueKey(_formaPagamento?.descricao),
                        initialValue: _formaPagamento,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Forma de Pagamento',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10),
                        ),
                        items: formas
                            .map((f) => DropdownMenuItem(
                                value: f,
                                child: Text(
                                    [f.descricao, f.tipo, if (f.banco.isNotEmpty) f.banco].join(' - '),
                                    overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: (v) => setState(() => _formaPagamento = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<Pessoa>(
                        key: ValueKey(_pessoa?.nome),
                        initialValue: _pessoa,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Pessoa',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10),
                        ),
                        items: pessoas
                            .map((p) => DropdownMenuItem(
                                value: p,
                                child: Text(p.nome,
                                    overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: (v) => setState(() => _pessoa = v),
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
                // Switches compactos
                Row(
                  children: [
                    _switchCompact('Recorrente', _recorrente,
                        (v) => setState(() => _recorrente = v)),
                    _switchCompact('Esperado', _gastoEsperado,
                        (v) => setState(() => _gastoEsperado = v)),
                    _switchCompact('Evitável', _gastoEvitavel,
                        (v) => setState(() => _gastoEvitavel = v)),
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
                  // ── Item confirmado: exibe como tile com swipe para excluir ──
                  final v = double.tryParse(
                          l['valor']!.text.replaceAll('.', '').replaceAll(',', '.')) ??
                      0;
                  return Dismissible(
                    key: Key('linha_$linhaId'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (_) => showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Excluir item?'),
                        content: Text(
                            'Deseja remover "${l['desc']!.text}" da lista?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancelar'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
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
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'R\$ ${_formatarValor(v)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red),
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

                // ── Item em edição: campos + botão OK ──
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
                            hintText: 'Ex: Netflix',
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
            padding: EdgeInsets.fromLTRB(
                16, 4, 16, MediaQuery.of(context).padding.bottom + 12),
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
