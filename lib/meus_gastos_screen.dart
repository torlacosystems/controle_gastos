import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'gasto.dart';
import 'main.dart';
import 'atualizar_parcelas_result.dart';
import 'fade_route.dart';
import 'multiplos_gastos_screen.dart';
import 'categoria.dart';
import 'forma_pagamento.dart';
import 'pessoa.dart';

class MeusGastosScreen extends StatefulWidget {
  const MeusGastosScreen({super.key});

  @override
  State<MeusGastosScreen> createState() => _MeusGastosScreenState();
}

class _MeusGastosScreenState extends State<MeusGastosScreen> {
  late Box<Gasto> _gastosBox;
  late Box<Categoria> _categoriasBox;
  late Box<FormaPagamento> _formasPagamentoBox;
  late Box<Pessoa> _pessoasBox;
  bool _filtroNaoDetalhado = false;

  final Set<String> _selecionados = {};
  bool _modoSelecao = false;

  @override
  void initState() {
    super.initState();
    _gastosBox = Hive.box<Gasto>('gastos');
    _categoriasBox = Hive.box<Categoria>('categorias');
    _formasPagamentoBox = Hive.box<FormaPagamento>('formas_pagamento');
    _pessoasBox = Hive.box<Pessoa>('pessoas');
  }

  String _formatarValor(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

  String _formatarData(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  List<Map<String, dynamic>> get _itens {
    final agora = DateTime.now();
    final limite = DateTime(agora.year, agora.month, agora.day)
        .subtract(const Duration(days: 2));
    final lista = <Map<String, dynamic>>[];
    for (int i = 0; i < _gastosBox.length; i++) {
      final g = _gastosBox.getAt(i);
      if (g == null) continue;
      final dataGasto = DateTime(g.data.year, g.data.month, g.data.day);
      if (dataGasto.isBefore(limite)) continue;
      if (_filtroNaoDetalhado && g.detalhado) continue;
      lista.add({'item': g, 'index': i});
    }
    lista.sort((a, b) =>
        (b['item'] as Gasto).data.compareTo((a['item'] as Gasto).data));
    return lista;
  }

  Future<void> _editarGasto(Map<String, dynamic> item) async {
    final boxIndex = item['index'] as int;
    final resultado = await Navigator.push<dynamic>(
      context,
      FadeRoute(page: AdicionarGastoScreen(gasto: item['item'] as Gasto)),
    );
    if (resultado == null) return;
    if (resultado is Gasto) {
      await _gastosBox.putAt(boxIndex, resultado);
    } else if (resultado is AtualizarParcelasResult) {
      await _gastosBox.putAt(boxIndex, resultado.gastoAtual);
      for (final entry in resultado.proximas) {
        await _gastosBox.putAt(entry.key, entry.value);
      }
    } else if (resultado is List<Gasto>) {
      for (final parcela in resultado) {
        await _gastosBox.add(parcela);
      }
    }
    setState(() {});
  }

  Future<bool> _confirmarExclusao(Gasto g) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Excluir gasto'),
            content: Text(
                'Deseja excluir "${g.descricao.isNotEmpty ? g.descricao : g.categoria}" de R\$ ${_formatarValor(g.valor)}?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Excluir'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _excluirSelecionados() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir gastos'),
        content: Text('Excluir ${_selecionados.length} gasto(s) selecionado(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    final itens = _itens;
    final indices = <int>[];
    for (final item in itens) {
      if (_selecionados.contains((item['item'] as Gasto).id)) {
        indices.add(item['index'] as int);
      }
    }
    indices.sort((a, b) => b.compareTo(a));
    for (final i in indices) { await _gastosBox.deleteAt(i); }

    setState(() {
      _selecionados.clear();
      _modoSelecao = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Gastos excluídos.')));
    }
  }

  Future<void> _editarEmMassa() async {
    final formas = _formasPagamentoBox.values.toList();
    final pessoas = _pessoasBox.values.toList()
      ..sort((a, b) {
        if (a.parentesco == 'Eu Mesmo') return -1;
        if (b.parentesco == 'Eu Mesmo') return 1;
        return a.nome.compareTo(b.nome);
      });
    final nomesPessoas = pessoas.map((p) => p.nome).toList();

    final fixasSemOutros = ['Alimentação', 'Transporte', 'Saúde', 'Lazer', 'Moradia', 'Educação', 'Mercado', 'Assinaturas'];
    final custom = _categoriasBox.values.map((c) => c.nome).toList()..sort();
    final categorias = [...fixasSemOutros, ...custom, 'Outros'];

    String? novaForma;
    String? novaCategoria;
    String? novoTipo;
    String? novaPessoa;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              24, 20, 24,
              MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Editar ${_selecionados.length} gastos',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Deixe em branco os campos que não deseja alterar.',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 20),

                  // Pessoa
                  if (nomesPessoas.isNotEmpty) ...[
                    const Text('Pessoa', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      key: const ValueKey('pessoa'),
                      initialValue: novaPessoa,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: '— sem alteração —',
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('— sem alteração —')),
                        ...nomesPessoas.map((p) => DropdownMenuItem(value: p, child: Text(p))),
                      ],
                      onChanged: (v) => setSheet(() => novaPessoa = v),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Categoria
                  const Text('Categoria', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    key: const ValueKey('categoria'),
                    initialValue: novaCategoria,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: '— sem alteração —',
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('— sem alteração —')),
                      ...categorias.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                    ],
                    onChanged: (v) => setSheet(() => novaCategoria = v),
                  ),
                  const SizedBox(height: 16),

                  // Forma de pagamento
                  if (formas.isNotEmpty) ...[
                    const Text('Forma de pagamento', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      key: const ValueKey('forma'),
                      initialValue: novaForma,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: '— sem alteração —',
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('— sem alteração —')),
                        ...formas.map((f) => DropdownMenuItem(
                          value: f.descricao,
                          child: Text([f.descricao, f.tipo, if (f.banco.isNotEmpty) f.banco].join(' - ')),
                        )),
                      ],
                      onChanged: (v) => setSheet(() => novaForma = v),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Tipo de gasto
                  const Text('Tipo de gasto', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    key: const ValueKey('tipo'),
                    initialValue: novoTipo,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: '— sem alteração —',
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('— sem alteração —')),
                      DropdownMenuItem(value: 'Fixo', child: Text('Fixo')),
                      DropdownMenuItem(value: 'Variável', child: Text('Variável')),
                    ],
                    onChanged: (v) => setSheet(() => novoTipo = v),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: (novaCategoria == null && novaForma == null && novoTipo == null && novaPessoa == null)
                          ? null
                          : () => Navigator.pop(ctx, true),
                      child: const Text('Aplicar alterações'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).then((aplicar) async {
      if (aplicar != true) return;

      final itens = _itens;
      for (final item in itens) {
        final g = item['item'] as Gasto;
        if (!_selecionados.contains(g.id)) continue;
        final idx = item['index'] as int;
        final atualizado = Gasto(
          id: g.id,
          descricao: g.descricao,
          valor: g.valor,
          categoria: novaCategoria ?? g.categoria,
          data: g.data,
          formaPagamento: novaForma ?? g.formaPagamento,
          pessoa: novaPessoa ?? g.pessoa,
          tipoGasto: novoTipo ?? g.tipoGasto,
          parcelado: g.parcelado,
          numeroParcelas: g.numeroParcelas,
          estabelecimento: g.estabelecimento,
          recorrente: g.recorrente,
          gastoEsperado: g.gastoEsperado,
          grupoId: g.grupoId,
          numeroParcela: g.numeroParcela,
          gastoEvitavel: g.gastoEvitavel,
          detalhado: g.detalhado,
        );
        await _gastosBox.putAt(idx, atualizado);
      }

      setState(() {
        _selecionados.clear();
        _modoSelecao = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gastos atualizados com sucesso.')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final itens = _itens;
    return Scaffold(
      appBar: _modoSelecao
          ? AppBar(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _selecionados.clear();
                  _modoSelecao = false;
                }),
              ),
              title: Text('${_selecionados.length} selecionado(s)'),
              actions: [
                if (_selecionados.length >= 2)
                  IconButton(
                    icon: const Icon(Icons.edit),
                    tooltip: 'Editar em massa',
                    onPressed: _editarEmMassa,
                  ),
                IconButton(
                  icon: const Icon(Icons.select_all),
                  tooltip: 'Selecionar todos',
                  onPressed: () => setState(() {
                    final ids = itens.map((i) => (i['item'] as Gasto).id).toSet();
                    if (_selecionados.length == ids.length) {
                      _selecionados.clear();
                      _modoSelecao = false;
                    } else {
                      _selecionados.addAll(ids);
                    }
                  }),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: 'Excluir selecionados',
                  onPressed: _selecionados.isNotEmpty ? _excluirSelecionados : null,
                ),
              ],
            )
          : AppBar(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              title: const Text('Meus Gastos'),
            ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.grey[100],
            child: Row(
              children: [
                GestureDetector(
                  onTap: () =>
                      setState(() => _filtroNaoDetalhado = !_filtroNaoDetalhado),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: _filtroNaoDetalhado ? Colors.orange : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _filtroNaoDetalhado
                            ? Colors.orange
                            : Colors.grey[300]!,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.pending_actions,
                            size: 14,
                            color: _filtroNaoDetalhado
                                ? Colors.white
                                : Colors.grey[700]),
                        const SizedBox(width: 4),
                        Text(
                          'Não Detalhados',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _filtroNaoDetalhado
                                ? Colors.white
                                : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${itens.length} registro(s) • últimos 3 dias',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Expanded(
            child: itens.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long,
                            size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text(
                          _filtroNaoDetalhado
                              ? 'Nenhum gasto não detalhado nos últimos 3 dias.'
                              : 'Nenhum gasto nos últimos 3 dias.',
                          style: const TextStyle(color: Colors.grey, fontSize: 15),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: itens.length,
                    itemBuilder: (context, index) {
                      final item = itens[index];
                      final g = item['item'] as Gasto;
                      final naoDetalhado = !g.detalhado;
                      final selecionado = _selecionados.contains(g.id);
                      final tile = Container(
                        key: Key('meugasto_tile_${g.id}'),
                        decoration: BoxDecoration(
                          color: selecionado ? primary.withValues(alpha: 0.1) : null,
                          border: Border(
                            left: BorderSide(
                              color: selecionado
                                  ? primary
                                  : naoDetalhado
                                      ? Colors.orange
                                      : Colors.red,
                              width: 4,
                            ),
                          ),
                        ),
                        child: ListTile(
                          onLongPress: () => setState(() {
                            _modoSelecao = true;
                            _selecionados.add(g.id);
                          }),
                          onTap: _modoSelecao
                              ? () => setState(() {
                                    if (selecionado) {
                                      _selecionados.remove(g.id);
                                      if (_selecionados.isEmpty) _modoSelecao = false;
                                    } else {
                                      _selecionados.add(g.id);
                                    }
                                  })
                              : null,
                          leading: _modoSelecao
                              ? Checkbox(
                                  value: selecionado,
                                  onChanged: (_) => setState(() {
                                    if (selecionado) {
                                      _selecionados.remove(g.id);
                                      if (_selecionados.isEmpty) _modoSelecao = false;
                                    } else {
                                      _selecionados.add(g.id);
                                    }
                                  }),
                                )
                              : CircleAvatar(
                                  backgroundColor: naoDetalhado
                                      ? Colors.orange[50]
                                      : Colors.red[50],
                                  child: Icon(
                                    naoDetalhado
                                        ? Icons.pending_actions
                                        : Icons.receipt_long,
                                    color: naoDetalhado ? Colors.orange : Colors.red,
                                  ),
                                ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  g.descricao.isNotEmpty
                                      ? g.descricao
                                      : g.categoria,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              if (naoDetalhado)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[100],
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.orange),
                                  ),
                                  child: const Text(
                                    'Não Detalhado',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.orange,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Text(
                            g.categoria.isNotEmpty && g.categoria != 'Outros'
                                ? '${_formatarData(g.data)} • ${g.categoria}'
                                : _formatarData(g.data),
                          ),
                          trailing: _modoSelecao
                              ? null
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '- R\$ ${_formatarValor(g.valor)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Colors.red,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 18),
                                      onPressed: () => _editarGasto(item),
                                    ),
                                  ],
                                ),
                        ),
                      );
                      if (_modoSelecao) return tile;
                      return Dismissible(
                        key: Key('meugasto_${g.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          color: Colors.red,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (_) => _confirmarExclusao(g),
                        onDismissed: (_) async {
                          await _gastosBox.deleteAt(item['index'] as int);
                          setState(() {});
                        },
                        child: tile,
                      );
                    },
                  ),
          ),
          // ── Botões inferiores ──
          if (!_modoSelecao)
            Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 8, 16, MediaQuery.of(context).padding.bottom + 12),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final resultado = await Navigator.push<dynamic>(
                          context,
                          FadeRoute(page: const AdicionarGastoScreen()),
                        );
                        if (resultado == null) return;
                        if (resultado is List<Gasto>) {
                          for (final p in resultado) {
                            await _gastosBox.add(p);
                          }
                        } else if (resultado is Gasto) {
                          await _gastosBox.add(resultado);
                        } else if (resultado is AtualizarParcelasResult) {
                          await _gastosBox.add(resultado.gastoAtual);
                        }
                        setState(() {});
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Novo Gasto'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final salvo = await Navigator.push<bool>(
                          context,
                          FadeRoute(page: const MultiplosGastosScreen()),
                        );
                        if (salvo == true) setState(() {});
                      },
                      icon: const Icon(Icons.playlist_add),
                      label: const Text('Múltiplos Gastos'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[900],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
