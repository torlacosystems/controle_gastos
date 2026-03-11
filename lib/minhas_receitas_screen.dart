import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'receita.dart';
import 'main.dart';
import 'fade_route.dart';
import 'multiplas_receitas_screen.dart';
import 'pessoa.dart';

class MinhasReceitasScreen extends StatefulWidget {
  const MinhasReceitasScreen({super.key});

  @override
  State<MinhasReceitasScreen> createState() => _MinhasReceitasScreenState();
}

class _MinhasReceitasScreenState extends State<MinhasReceitasScreen> {
  late Box<Receita> _receitasBox;
  late Box<Pessoa> _pessoasBox;
  bool _filtroNaoDetalhado = false;

  final Set<String> _selecionados = {};
  bool _modoSelecao = false;

  @override
  void initState() {
    super.initState();
    _receitasBox = Hive.box<Receita>('receitas');
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
    for (int i = 0; i < _receitasBox.length; i++) {
      final r = _receitasBox.getAt(i);
      if (r == null) continue;
      final dataReceita = DateTime(r.data.year, r.data.month, r.data.day);
      if (dataReceita.isBefore(limite)) continue;
      if (_filtroNaoDetalhado && r.detalhado) continue;
      lista.add({'item': r, 'index': i});
    }
    lista.sort((a, b) =>
        (b['item'] as Receita).data.compareTo((a['item'] as Receita).data));
    return lista;
  }

  Future<void> _editarReceita(Map<String, dynamic> item) async {
    final boxIndex = item['index'] as int;
    final resultado = await Navigator.push<dynamic>(
      context,
      FadeRoute(
          page: AdicionarReceitaScreen(receita: item['item'] as Receita)),
    );
    if (resultado == null) return;
    if (resultado is Receita) {
      await _receitasBox.putAt(boxIndex, resultado);
    }
    setState(() {});
  }

  Future<bool> _confirmarExclusao(Receita r) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Excluir receita'),
            content: Text(
                'Deseja excluir "${r.descricao.isNotEmpty ? r.descricao : r.categoria}" de R\$ ${_formatarValor(r.valor)}?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white),
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
        title: const Text('Excluir receitas'),
        content: Text('Excluir ${_selecionados.length} receita(s) selecionada(s)?'),
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
      if (_selecionados.contains((item['item'] as Receita).id)) {
        indices.add(item['index'] as int);
      }
    }
    indices.sort((a, b) => b.compareTo(a));
    for (final i in indices) { await _receitasBox.deleteAt(i); }

    setState(() {
      _selecionados.clear();
      _modoSelecao = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Receitas excluídas.')));
    }
  }

  Future<void> _editarEmMassa() async {
    final pessoas = _pessoasBox.values.toList()
      ..sort((a, b) {
        if (a.parentesco == 'Eu Mesmo') return -1;
        if (b.parentesco == 'Eu Mesmo') return 1;
        return a.nome.compareTo(b.nome);
      });
    final nomesPessoas = pessoas.map((p) => p.nome).toList();

    final categoriasReceita = ['Salário', 'Freelance', 'Investimento', 'Aluguel', 'Presente', 'Benefício', 'Outros'];

    String? novaCategoria;
    String? novoTipo;
    String? novaPessoa;
    bool? novoRecorrente;

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
                    'Editar ${_selecionados.length} receitas',
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
                      ...categoriasReceita.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                    ],
                    onChanged: (v) => setSheet(() => novaCategoria = v),
                  ),
                  const SizedBox(height: 16),

                  // Tipo de receita
                  const Text('Tipo de receita', style: TextStyle(fontWeight: FontWeight.w600)),
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
                  const SizedBox(height: 16),

                  // Recorrência
                  const Text('Recorrência', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<bool>(
                    key: const ValueKey('recorrente'),
                    initialValue: novoRecorrente,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: '— sem alteração —',
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('— sem alteração —')),
                      DropdownMenuItem(value: true, child: Text('Recorrente')),
                      DropdownMenuItem(value: false, child: Text('Não recorrente')),
                    ],
                    onChanged: (v) => setSheet(() => novoRecorrente = v),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: (novaCategoria == null && novoTipo == null && novaPessoa == null && novoRecorrente == null)
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
        final r = item['item'] as Receita;
        if (!_selecionados.contains(r.id)) continue;
        final idx = item['index'] as int;
        final atualizado = Receita(
          id: r.id,
          descricao: r.descricao,
          valor: r.valor,
          categoria: novaCategoria ?? r.categoria,
          data: r.data,
          pessoa: novaPessoa ?? r.pessoa,
          recorrente: novoRecorrente ?? r.recorrente,
          tipoReceita: novoTipo ?? r.tipoReceita,
          detalhado: r.detalhado,
        );
        await _receitasBox.putAt(idx, atualizado);
      }

      setState(() {
        _selecionados.clear();
        _modoSelecao = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Receitas atualizadas com sucesso.')),
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
              title: Text('${_selecionados.length} selecionada(s)'),
              actions: [
                if (_selecionados.length >= 2)
                  IconButton(
                    icon: const Icon(Icons.edit),
                    tooltip: 'Editar em massa',
                    onPressed: _editarEmMassa,
                  ),
                IconButton(
                  icon: const Icon(Icons.select_all),
                  tooltip: 'Selecionar todas',
                  onPressed: () => setState(() {
                    final ids = itens.map((i) => (i['item'] as Receita).id).toSet();
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
                  tooltip: 'Excluir selecionadas',
                  onPressed: _selecionados.isNotEmpty ? _excluirSelecionados : null,
                ),
              ],
            )
          : AppBar(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              title: const Text('Minhas Receitas'),
            ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.grey[100],
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(
                      () => _filtroNaoDetalhado = !_filtroNaoDetalhado),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color:
                          _filtroNaoDetalhado ? Colors.teal : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _filtroNaoDetalhado
                            ? Colors.teal
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
                        Icon(Icons.attach_money,
                            size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text(
                          _filtroNaoDetalhado
                              ? 'Nenhuma receita não detalhada nos últimos 3 dias.'
                              : 'Nenhuma receita nos últimos 3 dias.',
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 15),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: itens.length,
                    itemBuilder: (context, index) {
                      final item = itens[index];
                      final r = item['item'] as Receita;
                      final naoDetalhado = !r.detalhado;
                      final selecionado = _selecionados.contains(r.id);
                      final tile = Container(
                          key: Key('minhareceita_tile_${r.id}'),
                          decoration: BoxDecoration(
                            color: selecionado ? primary.withValues(alpha: 0.1) : null,
                            border: Border(
                              left: BorderSide(
                                color: selecionado
                                    ? primary
                                    : naoDetalhado
                                        ? Colors.teal
                                        : Colors.green,
                                width: 4,
                              ),
                            ),
                          ),
                          child: ListTile(
                            onLongPress: () => setState(() {
                              _modoSelecao = true;
                              _selecionados.add(r.id);
                            }),
                            onTap: _modoSelecao
                                ? () => setState(() {
                                      if (selecionado) {
                                        _selecionados.remove(r.id);
                                        if (_selecionados.isEmpty) _modoSelecao = false;
                                      } else {
                                        _selecionados.add(r.id);
                                      }
                                    })
                                : null,
                            leading: _modoSelecao
                                ? Checkbox(
                                    value: selecionado,
                                    onChanged: (_) => setState(() {
                                      if (selecionado) {
                                        _selecionados.remove(r.id);
                                        if (_selecionados.isEmpty) _modoSelecao = false;
                                      } else {
                                        _selecionados.add(r.id);
                                      }
                                    }),
                                  )
                                : CircleAvatar(
                                    backgroundColor: naoDetalhado
                                        ? Colors.teal[50]
                                        : Colors.green[50],
                                    child: Icon(
                                      naoDetalhado
                                          ? Icons.pending_actions
                                          : Icons.attach_money,
                                      color: naoDetalhado
                                          ? Colors.teal
                                          : Colors.green,
                                    ),
                                  ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    r.descricao.isNotEmpty
                                        ? r.descricao
                                        : r.categoria,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                if (naoDetalhado)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.teal[50],
                                      borderRadius:
                                          BorderRadius.circular(6),
                                      border:
                                          Border.all(color: Colors.teal),
                                    ),
                                    child: const Text(
                                      'Não Detalhado',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.teal,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Text(
                              r.categoria.isNotEmpty &&
                                      r.categoria != 'Outros'
                                  ? '${_formatarData(r.data)} • ${r.categoria}'
                                  : _formatarData(r.data),
                            ),
                            trailing: _modoSelecao
                                ? null
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '+ R\$ ${_formatarValor(r.valor)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Colors.green,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 18),
                                        onPressed: () => _editarReceita(item),
                                      ),
                                    ],
                                  ),
                          ),
                        );
                      if (_modoSelecao) return tile;
                      return Dismissible(
                        key: Key('minhareceita_${r.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          color: Colors.red,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (_) => _confirmarExclusao(r),
                        onDismissed: (_) async {
                          await _receitasBox.deleteAt(item['index'] as int);
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
                          FadeRoute(page: const AdicionarReceitaScreen()),
                        );
                        if (resultado == null) return;
                        if (resultado is List<Receita>) {
                          for (final r in resultado) {
                            await _receitasBox.add(r);
                          }
                        } else if (resultado is Receita) {
                          await _receitasBox.add(resultado);
                        }
                        setState(() {});
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Nova Receita'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
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
                          FadeRoute(page: const MultiplasReceitasScreen()),
                        );
                        if (salvo == true) setState(() {});
                      },
                      icon: const Icon(Icons.playlist_add),
                      label: const Text('Múltiplas Receitas'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal[700],
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
