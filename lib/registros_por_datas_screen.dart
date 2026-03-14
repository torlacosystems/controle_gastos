import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'gasto.dart';
import 'receita.dart';
import 'forma_pagamento.dart';
import 'currency_formatter.dart';
import 'pessoa.dart';
import 'categoria.dart';

class RegistrosPorDatasScreen extends StatefulWidget {
  final bool iniciarComoGasto;
  /// Quando true, oculta o toggle Gasto/Receita e fixa o tipo
  final bool fixarTipo;

  const RegistrosPorDatasScreen({super.key, this.iniciarComoGasto = true, this.fixarTipo = false});

  @override
  State<RegistrosPorDatasScreen> createState() =>
      _RegistrosPorDatasScreenState();
}

class _RegistrosPorDatasScreenState extends State<RegistrosPorDatasScreen> {
  late Box<Gasto> _gastosBox;
  late Box<Receita> _receitasBox;
  late Box<FormaPagamento> _formasPagamentoBox;
  late Box<Pessoa> _pessoasBox;
  late Box<Categoria> _categoriasBox;

  late bool _isGasto;

  // Campos comuns
  final _descricaoCtrl = TextEditingController();
  final _valorCtrl = TextEditingController();
  String _categoria = 'Alimentação';
  String _pessoa = '';
  String _tipo = 'Fixo';
  bool _recorrente = true;
  FormaPagamento? _formaPagamento;

  // Campos exclusivos de gasto
  final _estabelecimentoCtrl = TextEditingController();
  bool _gastoEsperado = true;
  bool _gastoEvitavel = false;

  // Datas
  DateTime _dataInicio = DateTime.now();
  DateTime _dataFim = DateTime.now();
  // 1=Seg, 2=Ter, 3=Qua, 4=Qui, 5=Sex, 6=Sáb, 7=Dom
  Set<int> _diasSelecionados = {1, 2, 3, 4, 5};
  String _modoDias = 'uteis'; // 'todos' | 'uteis' | 'personalizado'

  static const _nomesDias = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

  @override
  void initState() {
    super.initState();
    _isGasto = widget.iniciarComoGasto;
    _gastosBox = Hive.box<Gasto>('gastos');
    _receitasBox = Hive.box<Receita>('receitas');
    _formasPagamentoBox = Hive.box<FormaPagamento>('formas_pagamento');
    _pessoasBox = Hive.box<Pessoa>('pessoas');
    _categoriasBox = Hive.box<Categoria>('categorias');

    // Pessoa padrão: usuario principal
    final pessoas = _pessoasBox.values.toList()
      ..sort((a, b) {
        if (a.parentesco == 'Eu Mesmo') return -1;
        if (b.parentesco == 'Eu Mesmo') return 1;
        return a.nome.compareTo(b.nome);
      });
    if (pessoas.isNotEmpty) _pessoa = pessoas.first.nome;

    // Forma de pagamento padrão: primeira cadastrada
    if (_formasPagamentoBox.isNotEmpty) {
      _formaPagamento = _formasPagamentoBox.values.first;
    }

    _categoria = _isGasto ? 'Alimentação' : 'Salário';
  }

  @override
  void dispose() {
    _descricaoCtrl.dispose();
    _valorCtrl.dispose();
    _estabelecimentoCtrl.dispose();
    super.dispose();
  }

  List<String> get _categoriasGasto {
    final fixas = ['Alimentação', 'Transporte', 'Veículo', 'Saúde', 'Lazer', 'Moradia',
        'Educação', 'Mercado', 'Assinaturas',
        'Vestuário', 'Cuidados Pessoais', 'Presentes'];
    final custom = _categoriasBox.values.map((c) => c.nome).toList()..sort();
    return [...fixas, ...custom, 'Outros'];
  }

  List<String> get _categoriasReceita =>
      ['Salário', 'Freelance', 'Investimento', 'Aluguel', 'Presente', 'Benefício', 'Outros'];

  List<Pessoa> get _pessoas {
    return _pessoasBox.values.toList()
      ..sort((a, b) {
        if (a.parentesco == 'Eu Mesmo') return -1;
        if (b.parentesco == 'Eu Mesmo') return 1;
        return a.nome.compareTo(b.nome);
      });
  }

  List<FormaPagamento> get _formas => _formasPagamentoBox.values.toList();

  List<DateTime> get _datasGeradas {
    final datas = <DateTime>[];
    var atual = DateTime(_dataInicio.year, _dataInicio.month, _dataInicio.day);
    final fim = DateTime(_dataFim.year, _dataFim.month, _dataFim.day);
    while (!atual.isAfter(fim)) {
      if (_diasSelecionados.contains(atual.weekday)) {
        datas.add(atual);
      }
      atual = atual.add(const Duration(days: 1));
    }
    return datas;
  }

  void _setModoDias(String modo) {
    setState(() {
      _modoDias = modo;
      switch (modo) {
        case 'todos':
          _diasSelecionados = {1, 2, 3, 4, 5, 6, 7};
        case 'uteis':
          _diasSelecionados = {1, 2, 3, 4, 5};
        case 'personalizado':
          break;
      }
    });
  }

  Future<void> _selecionarData(bool isInicio) async {
    final inicial = isInicio ? _dataInicio : _dataFim;
    final picked = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('pt', 'BR'),
    );
    if (picked == null) return;
    setState(() {
      if (isInicio) {
        _dataInicio = picked;
        if (_dataFim.isBefore(_dataInicio)) _dataFim = _dataInicio;
      } else {
        _dataFim = picked;
        if (_dataFim.isBefore(_dataInicio)) _dataInicio = _dataFim;
      }
    });
  }

  String _formatarData(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _salvar() async {
    if (_descricaoCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe uma descrição.')),
      );
      return;
    }

    final valorStr = _valorCtrl.text.trim().replaceAll('.', '').replaceAll(',', '.');
    final valor = double.tryParse(valorStr);
    if (valor == null || valor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um valor válido.')),
      );
      return;
    }

    final datas = _datasGeradas;
    if (datas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhuma data gerada com os filtros selecionados.')),
      );
      return;
    }

    final descricao = _descricaoCtrl.text.trim();
    final ts = DateTime.now().millisecondsSinceEpoch;

    if (_isGasto) {
      for (int i = 0; i < datas.length; i++) {
        await _gastosBox.add(Gasto(
          id: '${ts}_$i',
          descricao: descricao,
          valor: valor,
          categoria: _categoria,
          data: datas[i],
          formaPagamento: _formaPagamento?.descricao ?? '',
          pessoa: _pessoa,
          tipoGasto: _tipo,
          parcelado: false,
          numeroParcelas: 1,
          estabelecimento: _estabelecimentoCtrl.text.trim(),
          recorrente: _recorrente,
          gastoEsperado: _gastoEsperado,
          gastoEvitavel: _gastoEvitavel,
          detalhado: true,
        ));
      }
    } else {
      for (int i = 0; i < datas.length; i++) {
        await _receitasBox.add(Receita(
          id: '${ts}_$i',
          descricao: descricao,
          valor: valor,
          categoria: _categoria,
          data: datas[i],
          pessoa: _pessoa,
          recorrente: _recorrente,
          tipoReceita: _tipo,
          detalhado: true,
        ));
      }
    }

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final categorias = _isGasto ? _categoriasGasto : _categoriasReceita;
    final pessoas = _pessoas;
    final formas = _formas;
    final datas = _datasGeradas;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        title: const Text('Registros por Datas'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Tipo ──
          if (!widget.fixarTipo) ...[
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Gasto'), icon: Icon(Icons.remove_circle_outline)),
                ButtonSegment(value: false, label: Text('Receita'), icon: Icon(Icons.add_circle_outline)),
              ],
              selected: {_isGasto},
              onSelectionChanged: (s) => setState(() {
                _isGasto = s.first;
                _categoria = _isGasto ? 'Alimentação' : 'Salário';
              }),
            ),
            const SizedBox(height: 20),
          ],

          // ── Dados do registro ──
          Text('Dados do registro',
              style: TextStyle(fontWeight: FontWeight.bold, color: primary, fontSize: 15)),
          const SizedBox(height: 12),

          TextField(
            controller: _valorCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [CurrencyInputFormatter()],
            decoration: const InputDecoration(
              labelText: 'Valor (R\$)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _descricaoCtrl,
            decoration: const InputDecoration(
              labelText: 'Descrição',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),

          if (_isGasto)
            Column(
              children: [
                TextField(
                  controller: _estabelecimentoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Estabelecimento (opcional)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),

          DropdownButtonFormField<String>(
            key: const ValueKey('cat'),
            initialValue: categorias.contains(_categoria) ? _categoria : categorias.first,
            decoration: const InputDecoration(
              labelText: 'Categoria',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: categorias.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() => _categoria = v!),
          ),
          const SizedBox(height: 12),

          if (_isGasto && formas.isNotEmpty)
            Column(
              children: [
                DropdownButtonFormField<FormaPagamento>(
                  key: const ValueKey('forma'),
                  initialValue: _formaPagamento,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Forma de pagamento',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: formas.map((f) => DropdownMenuItem(
                    value: f,
                    child: Text(
                      [f.descricao, f.tipo, if (f.banco.isNotEmpty) f.banco].join(' - '),
                      overflow: TextOverflow.ellipsis,
                    ),
                  )).toList(),
                  onChanged: (v) => setState(() => _formaPagamento = v),
                ),
                const SizedBox(height: 12),
              ],
            ),

          if (pessoas.isNotEmpty)
            Column(
              children: [
                DropdownButtonFormField<String>(
                  key: const ValueKey('pessoa'),
                  initialValue: pessoas.any((p) => p.nome == _pessoa) ? _pessoa : pessoas.first.nome,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Pessoa',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: pessoas.map((p) => DropdownMenuItem(value: p.nome, child: Text(p.nome))).toList(),
                  onChanged: (v) => setState(() => _pessoa = v!),
                ),
                const SizedBox(height: 12),
              ],
            ),

          DropdownButtonFormField<String>(
            key: const ValueKey('tipo'),
            initialValue: _tipo,
            decoration: InputDecoration(
              labelText: _isGasto ? 'Tipo de gasto' : 'Tipo de receita',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(value: 'Fixo', child: Text('Fixo')),
              DropdownMenuItem(value: 'Variável', child: Text('Variável')),
            ],
            onChanged: (v) => setState(() => _tipo = v!),
          ),
          const SizedBox(height: 12),

          SwitchListTile(
            value: _recorrente,
            onChanged: (v) => setState(() => _recorrente = v),
            title: const Text('Recorrente'),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),

          if (_isGasto) ...[
            SwitchListTile(
              value: _gastoEsperado,
              onChanged: (v) => setState(() => _gastoEsperado = v),
              title: const Text('Gasto esperado'),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            SwitchListTile(
              value: _gastoEvitavel,
              onChanged: (v) => setState(() => _gastoEvitavel = v),
              title: const Text('Gasto evitável'),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ],

          const Divider(height: 28),

          // ── Datas ──
          Text('Período',
              style: TextStyle(fontWeight: FontWeight.bold, color: primary, fontSize: 15)),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _selecionarData(true),
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text('Início: ${_formatarData(_dataInicio)}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _selecionarData(false),
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text('Fim: ${_formatarData(_dataFim)}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Text('Dias da semana',
              style: TextStyle(fontWeight: FontWeight.bold, color: primary, fontSize: 15)),
          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Todos'),
                selected: _modoDias == 'todos',
                onSelected: (_) => _setModoDias('todos'),
              ),
              ChoiceChip(
                label: const Text('Dias úteis'),
                selected: _modoDias == 'uteis',
                onSelected: (_) => _setModoDias('uteis'),
              ),
              ChoiceChip(
                label: const Text('Personalizado'),
                selected: _modoDias == 'personalizado',
                onSelected: (_) => _setModoDias('personalizado'),
              ),
            ],
          ),

          if (_modoDias == 'personalizado') ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              children: List.generate(7, (i) {
                final dia = i + 1;
                return FilterChip(
                  label: Text(_nomesDias[i]),
                  selected: _diasSelecionados.contains(dia),
                  onSelected: (sel) => setState(() {
                    if (sel) {
                      _diasSelecionados.add(dia);
                    } else {
                      _diasSelecionados.remove(dia);
                    }
                  }),
                );
              }),
            ),
          ],

          const SizedBox(height: 16),

          // ── Preview ──
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: primary.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${datas.length} registro(s) serão criados',
                  style: TextStyle(fontWeight: FontWeight.bold, color: primary),
                ),
                if (datas.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    datas.map((d) => _formatarData(d)).join('  •  '),
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: datas.isEmpty ? null : _salvar,
              icon: const Icon(Icons.save),
              label: Text('Salvar ${datas.length} registro(s)'),
              style: FilledButton.styleFrom(
                backgroundColor: _isGasto ? Colors.red[700] : Colors.green[700],
              ),
            ),
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}
