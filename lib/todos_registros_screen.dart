import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'dart:io';
import 'gasto.dart';
import 'receita.dart';
import 'main.dart';

class TodosRegistrosScreen extends StatefulWidget {
  const TodosRegistrosScreen({super.key});

  @override
  State<TodosRegistrosScreen> createState() => _TodosRegistrosScreenState();
}

class _TodosRegistrosScreenState extends State<TodosRegistrosScreen> {
  late Box<Gasto> _gastosBox;
  late Box<Receita> _receitasBox;

  final Set<String> _selecionados = {};
  bool _modoSelecao = false;
  bool _modoBusca = false;
  final TextEditingController _buscaController = TextEditingController();
  String _termoBusca = '';

  int? _mesFiltro;
  int? _anoFiltro;
  String _tipoFiltro = 'todos';

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
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

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
      case 'Mercado':
        return Icons.shopping_cart;
      default:
        return Icons.category;
    }
  }

  List<Map<String, int>> get _mesesDisponiveis {
    final Set<String> vistos = {};
    final List<Map<String, int>> lista = [];
    final todasDatas = <DateTime>[];

    for (int i = 0; i < _gastosBox.length; i++) {
      final g = _gastosBox.getAt(i);
      if (g != null) todasDatas.add(g.data);
    }
    for (int i = 0; i < _receitasBox.length; i++) {
      final r = _receitasBox.getAt(i);
      if (r != null) todasDatas.add(r.data);
    }

    todasDatas.sort((a, b) => b.compareTo(a));
    for (final data in todasDatas) {
      final chave = '${data.year}-${data.month}';
      if (!vistos.contains(chave)) {
        vistos.add(chave);
        lista.add({'mes': data.month, 'ano': data.year});
      }
    }
    return lista;
  }

  bool _correspondeBusca(
    String categoria,
    String descricao,
    String pessoa,
    String formaPagamento,
    String estabelecimento,
  ) {
    if (_termoBusca.isEmpty) return true;
    final termo = _termoBusca.toLowerCase();
    return categoria.toLowerCase().contains(termo) ||
        descricao.toLowerCase().contains(termo) ||
        pessoa.toLowerCase().contains(termo) ||
        formaPagamento.toLowerCase().contains(termo) ||
        estabelecimento.toLowerCase().contains(termo);
  }

  List<Map<String, dynamic>> get _todosItens {
    final List<Map<String, dynamic>> itens = [];

    if (_tipoFiltro != 'receita') {
      for (int i = 0; i < _gastosBox.length; i++) {
        final g = _gastosBox.getAt(i);
        if (g != null) {
          final mesBateu =
              _mesFiltro == null ||
              (g.data.month == _mesFiltro && g.data.year == _anoFiltro);
          final buscaBateu = _correspondeBusca(
            g.categoria,
            g.descricao,
            g.pessoa,
            g.formaPagamento,
            g.estabelecimento,
          );
          if (mesBateu && buscaBateu) {
            itens.add({'tipo': 'gasto', 'item': g, 'index': i});
          }
        }
      }
    }

    if (_tipoFiltro != 'gasto') {
      for (int i = 0; i < _receitasBox.length; i++) {
        final r = _receitasBox.getAt(i);
        if (r != null) {
          final mesBateu =
              _mesFiltro == null ||
              (r.data.month == _mesFiltro && r.data.year == _anoFiltro);
          final buscaBateu = _correspondeBusca(
            r.categoria,
            r.descricao,
            r.pessoa,
            '',
            '',
          );
          if (mesBateu && buscaBateu) {
            itens.add({'tipo': 'receita', 'item': r, 'index': i});
          }
        }
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
    return itens;
  }

  String _itemId(Map<String, dynamic> item) => item['tipo'] == 'gasto'
      ? (item['item'] as Gasto).id
      : (item['item'] as Receita).id;

  void _toggleSelecao(String id) {
    setState(() {
      if (_selecionados.contains(id)) {
        _selecionados.remove(id);
        if (_selecionados.isEmpty) _modoSelecao = false;
      } else {
        _selecionados.add(id);
      }
    });
  }

  void _selecionarTodos() {
    setState(() {
      final ids = _todosItens.map((i) => _itemId(i)).toSet();
      if (_selecionados.length == ids.length) {
        _selecionados.clear();
        _modoSelecao = false;
      } else {
        _selecionados.addAll(ids);
      }
    });
  }

  Future<void> _excluirSelecionados() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir registros'),
        content: Text(
          'Excluir ${_selecionados.length} registro(s) selecionado(s)?',
        ),
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

    final itens = _todosItens;
    final gastosParaDeletar = <int>[];
    final receitasParaDeletar = <int>[];

    for (final item in itens) {
      if (_selecionados.contains(_itemId(item))) {
        if (item['tipo'] == 'gasto') {
          gastosParaDeletar.add(item['index'] as int);
        } else {
          receitasParaDeletar.add(item['index'] as int);
        }
      }
    }

    gastosParaDeletar.sort((a, b) => b.compareTo(a));
    receitasParaDeletar.sort((a, b) => b.compareTo(a));

    for (final i in gastosParaDeletar) await _gastosBox.deleteAt(i);
    for (final i in receitasParaDeletar) await _receitasBox.deleteAt(i);

    setState(() {
      _selecionados.clear();
      _modoSelecao = false;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Registros excluídos')));
  }

  String _gerarCsv() {
    final buffer = StringBuffer();
    buffer.writeln(
      'Tipo,Categoria,Valor,Data,Descrição,Pessoa,Forma Pagamento,Estabelecimento,Parcelado,Parcelas,Recorrente',
    );
    for (final item in _todosItens) {
      if (item['tipo'] == 'gasto') {
        final g = item['item'] as Gasto;
        buffer.writeln(
          'Gasto,"${g.categoria}",-${g.valor.toStringAsFixed(2)},${_formatarData(g.data)},"${g.descricao}","${g.pessoa}","${g.formaPagamento}","${g.estabelecimento}",${g.parcelado ? 'Sim' : 'Não'},${g.numeroParcelas},${g.recorrente ? 'Sim' : 'Não'}',
        );
      } else {
        final r = item['item'] as Receita;
        buffer.writeln(
          'Receita,"${r.categoria}",+${r.valor.toStringAsFixed(2)},${_formatarData(r.data)},"${r.descricao}","${r.pessoa}",,,,${r.recorrente ? 'Sim' : 'Não'}',
        );
      }
    }
    return buffer.toString();
  }

  Future<void> _exportarCsv() async {
    try {
      final csv = _gerarCsv();
      final dir = await getApplicationDocumentsDirectory();
      final arquivo = File('${dir.path}/registros.csv');
      await arquivo.writeAsString(csv);
      await Share.shareXFiles([
        XFile(arquivo.path),
      ], text: 'Registros exportados');
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao exportar: $e')));
    }
  }

  Future<void> _exportarPorEmail() async {
    try {
      final csv = _gerarCsv();
      final dir = await getApplicationDocumentsDirectory();
      final arquivo = File('${dir.path}/registros.csv');
      await arquivo.writeAsString(csv);
      try {
        final email = Email(
          body:
              'Segue em anexo o arquivo CSV com todos os registros financeiros.',
          subject: 'Exportação de registros financeiros',
          attachmentPaths: [arquivo.path],
          isHTML: false,
        );
        await FlutterEmailSender.send(email);
      } catch (_) {
        await Share.shareXFiles(
          [XFile(arquivo.path)],
          subject: 'Exportação de registros financeiros',
          text:
              'Segue em anexo o arquivo CSV com todos os registros financeiros.',
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao exportar: $e')));
    }
  }

  Future<void> _excluirItem(Map<String, dynamic> item) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Excluir ${item['tipo'] == 'gasto' ? 'Gasto' : 'Receita'}'),
        content: const Text('Tem certeza que deseja excluir este registro?'),
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
    if (item['tipo'] == 'gasto') {
      await _gastosBox.deleteAt(item['index'] as int);
    } else {
      await _receitasBox.deleteAt(item['index'] as int);
    }
    setState(() {});
  }

  void _mostrarFiltroMes() {
    final meses = _mesesDisponiveis;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filtrar por mês',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Icon(
                Icons.calendar_today,
                color: _mesFiltro == null
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey,
              ),
              title: const Text('Todos os registros'),
              selected: _mesFiltro == null,
              selectedTileColor: Theme.of(
                context,
              ).colorScheme.primary.withOpacity(0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              onTap: () {
                setState(() {
                  _mesFiltro = null;
                  _anoFiltro = null;
                });
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ...meses.map((m) {
              final selecionado =
                  _mesFiltro == m['mes'] && _anoFiltro == m['ano'];
              return ListTile(
                leading: Icon(
                  Icons.calendar_month,
                  color: selecionado
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                ),
                title: Text('${_nomesMeses[m['mes']! - 1]} ${m['ano']}'),
                selected: selecionado,
                selectedTileColor: Theme.of(
                  context,
                ).colorScheme.primary.withOpacity(0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                onTap: () {
                  setState(() {
                    _mesFiltro = m['mes'];
                    _anoFiltro = m['ano'];
                  });
                  Navigator.pop(context);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _abrirBusca() {
    setState(() {
      _modoBusca = true;
      _modoSelecao = false;
      _selecionados.clear();
    });
  }

  void _fecharBusca() {
    setState(() {
      _modoBusca = false;
      _termoBusca = '';
      _buscaController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final itens = _todosItens;
    final filtroMesAtivo = _mesFiltro != null;
    final tituloFiltro = filtroMesAtivo
        ? '${_nomesMeses[_mesFiltro! - 1]} $_anoFiltro'
        : 'Todos';
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        title: _modoBusca
            ? TextField(
                controller: _buscaController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                cursorColor: Colors.white,
                decoration: const InputDecoration(
                  hintText: 'Buscar por categoria, descrição, pessoa...',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _termoBusca = v),
              )
            : Text(
                _modoSelecao
                    ? '${_selecionados.length} selecionado(s)'
                    : 'Todos os Registros',
              ),
        actions: [
          if (_modoBusca) ...[
            if (_termoBusca.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  setState(() {
                    _termoBusca = '';
                    _buscaController.clear();
                  });
                },
              ),
            IconButton(icon: const Icon(Icons.close), onPressed: _fecharBusca),
          ] else if (_modoSelecao) ...[
            IconButton(
              icon: const Icon(Icons.select_all),
              tooltip: 'Selecionar todos',
              onPressed: _selecionarTodos,
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Excluir selecionados',
              onPressed: _selecionados.isNotEmpty ? _excluirSelecionados : null,
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                _selecionados.clear();
                _modoSelecao = false;
              }),
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Buscar',
              onPressed: _abrirBusca,
            ),
            IconButton(
              icon: Icon(
                Icons.filter_list,
                color: filtroMesAtivo ? Colors.yellowAccent : Colors.white,
              ),
              tooltip: 'Filtrar por mês',
              onPressed: _mostrarFiltroMes,
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'csv') _exportarCsv();
                if (value == 'email') _exportarPorEmail();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'csv',
                  child: Row(
                    children: [
                      Icon(Icons.download, size: 20),
                      SizedBox(width: 8),
                      Text('Exportar CSV'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'email',
                  child: Row(
                    children: [
                      Icon(Icons.email, size: 20),
                      SizedBox(width: 8),
                      Text('Enviar por e-mail'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // FILTRO DE TIPO
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.grey[100],
            child: Row(
              children: [
                _chipTipo('Todos', 'todos', Colors.blueGrey),
                const SizedBox(width: 8),
                _chipTipo('Gastos', 'gasto', Colors.red),
                const SizedBox(width: 8),
                _chipTipo('Receitas', 'receita', Colors.green),
              ],
            ),
          ),

          // BANNER BUSCA ATIVA
          if (_termoBusca.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.orange.withOpacity(0.1),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Buscando: "$_termoBusca"  •  ${itens.length} resultado(s)',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _fecharBusca,
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ),

          // BARRA FILTRO MÊS ATIVO
          if (filtroMesAtivo)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: primary.withOpacity(0.1),
              child: Row(
                children: [
                  Icon(Icons.filter_list, size: 16, color: primary),
                  const SizedBox(width: 8),
                  Text(
                    'Filtrando: $tituloFiltro  •  ${itens.length} registro(s)',
                    style: TextStyle(
                      fontSize: 13,
                      color: primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() {
                      _mesFiltro = null;
                      _anoFiltro = null;
                    }),
                    child: Icon(Icons.close, size: 16, color: primary),
                  ),
                ],
              ),
            ),

          // LISTA
          Expanded(
            child: itens.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _termoBusca.isNotEmpty
                              ? Icons.search_off
                              : Icons.inbox,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _termoBusca.isNotEmpty
                              ? 'Nenhum resultado para "$_termoBusca".'
                              : filtroMesAtivo
                              ? 'Nenhum registro em $tituloFiltro.'
                              : 'Nenhum registro encontrado.',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: itens.length,
                    itemBuilder: (context, index) {
                      final item = itens[index];
                      final isGasto = item['tipo'] == 'gasto';
                      final id = _itemId(item);
                      final selecionado = _selecionados.contains(id);

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

                      return Container(
                        decoration: BoxDecoration(
                          color: selecionado ? primary.withOpacity(0.1) : null,
                          border: Border(
                            left: BorderSide(
                              color: isGasto ? Colors.red : Colors.green,
                              width: 4,
                            ),
                          ),
                        ),
                        child: ListTile(
                          leading: _modoSelecao
                              ? Checkbox(
                                  value: selecionado,
                                  onChanged: (_) => _toggleSelecao(id),
                                )
                              : CircleAvatar(
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
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${isGasto ? 'Gasto' : 'Receita'} • ${_formatarData(data)}${descricao.isNotEmpty ? ' • $descricao' : ''}',
                          ),
                          trailing: _modoSelecao
                              ? Text(
                                  '${isGasto ? '-' : '+'} R\$ ${_formatarValor(valor)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: isGasto ? Colors.red : Colors.green,
                                  ),
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${isGasto ? '-' : '+'} R\$ ${_formatarValor(valor)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: isGasto
                                            ? Colors.red
                                            : Colors.green,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 18),
                                      onPressed: () async {
                                        final boxIndex = item['index'] as int;
                                        if (isGasto) {
                                          final resultado =
                                              await Navigator.push<dynamic>(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      AdicionarGastoScreen(
                                                        gasto:
                                                            item['item']
                                                                as Gasto,
                                                      ),
                                                ),
                                              );
                                          if (resultado != null &&
                                              resultado is Gasto) {
                                            await _gastosBox.putAt(
                                              boxIndex,
                                              resultado,
                                            );
                                            setState(() {});
                                          }
                                        } else {
                                          final resultado =
                                              await Navigator.push<Receita>(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      AdicionarReceitaScreen(
                                                        receita:
                                                            item['item']
                                                                as Receita,
                                                      ),
                                                ),
                                              );
                                          if (resultado != null) {
                                            await _receitasBox.putAt(
                                              boxIndex,
                                              resultado,
                                            );
                                            setState(() {});
                                          }
                                        }
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        size: 18,
                                        color: Colors.red,
                                      ),
                                      onPressed: () => _excluirItem(item),
                                    ),
                                  ],
                                ),
                          onTap: _modoSelecao ? () => _toggleSelecao(id) : null,
                          onLongPress: () {
                            setState(() {
                              _modoSelecao = true;
                              _selecionados.add(id);
                            });
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chipTipo(String label, String key, Color cor) {
    final selecionado = _tipoFiltro == key;
    return GestureDetector(
      onTap: () => setState(() => _tipoFiltro = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: selecionado ? cor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selecionado ? cor : Colors.grey[300]!),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selecionado ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }
}
