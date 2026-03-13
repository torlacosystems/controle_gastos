import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'dart:io';
import 'gasto.dart';
import 'receita.dart';
import 'main.dart';
import 'atualizar_parcelas_result.dart';
import 'fade_route.dart';
import 'categoria.dart';
import 'forma_pagamento.dart';
import 'pessoa.dart';

class TodosRegistrosScreen extends StatefulWidget {
  final String termoBuscaInicial;

  const TodosRegistrosScreen({super.key, this.termoBuscaInicial = ''});

  @override
  State<TodosRegistrosScreen> createState() => _TodosRegistrosScreenState();
}

class _TodosRegistrosScreenState extends State<TodosRegistrosScreen> {
  late Box<Gasto> _gastosBox;
  late Box<Receita> _receitasBox;
  late Box<Categoria> _categoriasBox;
  late Box<FormaPagamento> _formasPagamentoBox;
  late Box<Pessoa> _pessoasBox;

  final Set<String> _selecionados = {};
  bool _modoSelecao = false;
  bool _modoBusca = false;
  final TextEditingController _buscaController = TextEditingController();
  String _termoBusca = '';

  int? _mesFiltro;
  int? _anoFiltro;
  String _tipoFiltro = 'todos';
  bool _filtroParcelado = false;

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
    _categoriasBox = Hive.box<Categoria>('categorias');
    _formasPagamentoBox = Hive.box<FormaPagamento>('formas_pagamento');
    _pessoasBox = Hive.box<Pessoa>('pessoas');
    if (widget.termoBuscaInicial.isNotEmpty) {
      _termoBusca = widget.termoBuscaInicial;
      _modoBusca = true;
      _buscaController.text = widget.termoBuscaInicial;
    }
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
      case 'Assinaturas':
        return Icons.subscriptions;
      case 'Vestuário':
        return Icons.checkroom;
      case 'Cuidados Pessoais':
        return Icons.spa;
      case 'Presentes':
        return Icons.card_giftcard;
      default:
        // Busca em categorias personalizadas
        final custom = _categoriasBox.values.cast<Categoria?>().firstWhere(
          (c) => c?.nome == categoria,
          orElse: () => null,
        );
        return custom?.icone ?? Icons.category;
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
          final parceladoBateu = !_filtroParcelado || g.parcelado;
          if (mesBateu && buscaBateu && parceladoBateu) {
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
            '',
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

  /// Returns 'gasto' if all selected are gastos, 'receita' if all receitas, null if mixed or < 2
  String? get _tipoSelecao {
    if (_selecionados.length < 2) return null;
    final itens = _todosItens;
    String? tipo;
    for (final item in itens) {
      if (_selecionados.contains(_itemId(item))) {
        final t = item['tipo'] as String;
        if (tipo == null) {
          tipo = t;
        } else if (tipo != t) {
          return null;
        }
      }
    }
    return tipo;
  }

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

  Future<void> _editarEmMassa() async {
    final tipo = _tipoSelecao;
    if (tipo == null) return;

    final formas = _formasPagamentoBox.values.map((f) => f.descricao).toList();
    final pessoas = _pessoasBox.values.toList()
      ..sort((a, b) {
        if (a.parentesco == 'Eu Mesmo') return -1;
        if (b.parentesco == 'Eu Mesmo') return 1;
        return a.nome.compareTo(b.nome);
      });
    final nomesPessoas = pessoas.map((p) => p.nome).toList();

    // State for the bottom sheet
    String? novaForma;       // gastos only
    String? novaCategoria;
    String? novoTipo;        // tipoGasto or tipoReceita
    String? novaPessoa;
    bool? novoRecorrente;    // receitas only
    final categoriasBox = _categoriasBox;

    // Fixed receita categories (same as multiplas_receitas_screen)
    final categoriasReceita = ['Salário', 'Freelance', 'Investimento', 'Aluguel', 'Presente', 'Benefício', 'Outros'];

    // Gasto categories
    final fixasSemOutros = ['Alimentação', 'Transporte', 'Saúde', 'Lazer', 'Moradia', 'Educação', 'Mercado', 'Assinaturas', 'Vestuário', 'Cuidados Pessoais', 'Presentes'];
    final custom = categoriasBox.values.map((c) => c.nome).toList()..sort();
    final categoriasGasto = [...fixasSemOutros, ...custom, 'Outros'];

    final categorias = tipo == 'gasto' ? categoriasGasto : categoriasReceita;

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
                    'Editar ${_selecionados.length} ${tipo == 'gasto' ? 'gastos' : 'receitas'}',
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

                  // Forma de pagamento (gastos only)
                  if (tipo == 'gasto' && formas.isNotEmpty) ...[
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
                        ...formas.map((f) => DropdownMenuItem(value: f, child: Text(f))),
                      ],
                      onChanged: (v) => setSheet(() => novaForma = v),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Tipo de gasto / tipo de receita
                  Text(
                    tipo == 'gasto' ? 'Tipo de gasto' : 'Tipo de receita',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
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

                  // Recorrência (receitas only)
                  if (tipo == 'receita') ...[
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
                    const SizedBox(height: 16),
                  ],

                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: (novaCategoria == null &&
                              novaForma == null &&
                              novoTipo == null &&
                              novaPessoa == null &&
                              novoRecorrente == null)
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

      final itens = _todosItens;
      for (final item in itens) {
        if (!_selecionados.contains(_itemId(item))) continue;
        final idx = item['index'] as int;

        if (tipo == 'gasto') {
          final g = item['item'] as Gasto;
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
        } else {
          final r = item['item'] as Receita;
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
      }

      setState(() {
        _selecionados.clear();
        _modoSelecao = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registros atualizados com sucesso.')),
        );
      }
    });
  }

  // ── CSV ───────────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> get _todosRegistros {
    final List<Map<String, dynamic>> itens = [];
    for (int i = 0; i < _gastosBox.length; i++) {
      final g = _gastosBox.getAt(i);
      if (g != null) itens.add({'tipo': 'gasto', 'item': g, 'index': i});
    }
    for (int i = 0; i < _receitasBox.length; i++) {
      final r = _receitasBox.getAt(i);
      if (r != null) itens.add({'tipo': 'receita', 'item': r, 'index': i});
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

  String _gerarCsv(List<Map<String, dynamic>> itens) {
    String v(double valor) => valor.toStringAsFixed(2).replaceAll('.', ',');
    String q(String s) => '"${s.replaceAll('"', '""')}"';

    final buffer = StringBuffer();
    // BOM UTF-8 para Excel reconhecer acentos automaticamente
    buffer.write('\uFEFF');
    buffer.writeln(
      'Tipo;Categoria;Valor;Data;Descrição;Pessoa;Forma Pagamento;Estabelecimento;Parcelado;Parcelas;Recorrente',
    );
    for (final item in itens) {
      if (item['tipo'] == 'gasto') {
        final g = item['item'] as Gasto;
        buffer.writeln([
          'Gasto',
          q(g.categoria),
          '-${v(g.valor)}',
          _formatarData(g.data),
          q(g.descricao),
          q(g.pessoa),
          q(g.formaPagamento),
          q(g.estabelecimento),
          g.parcelado ? 'Sim' : 'Não',
          '${g.numeroParcelas}',
          g.recorrente ? 'Sim' : 'Não',
        ].join(';'));
      } else {
        final r = item['item'] as Receita;
        buffer.writeln([
          'Receita',
          q(r.categoria),
          v(r.valor),
          _formatarData(r.data),
          q(r.descricao),
          '',
          '',
          '',
          '',
          r.recorrente ? 'Sim' : 'Não',
        ].join(';'));
      }
    }
    return buffer.toString();
  }

  Future<File> _salvarCsvArquivo(List<Map<String, dynamic>> itens) async {
    final csv = _gerarCsv(itens);
    final dir = await getApplicationDocumentsDirectory();
    final arquivo = File('${dir.path}/registros_granix.csv');
    await arquivo.writeAsString(csv);
    return arquivo;
  }

  Future<Directory> _pastaDownloads() async {
    if (Platform.isAndroid) {
      final dir = Directory('/storage/emulated/0/Download');
      if (await dir.exists()) return dir;
    }
    Directory? dir;
    try { dir = await getDownloadsDirectory(); } catch (_) {}
    return dir ?? await getApplicationDocumentsDirectory();
  }

  Future<void> _downloadCsv(List<Map<String, dynamic>> itens) async {
    try {
      final csv = _gerarCsv(itens);
      final dir = await _pastaDownloads();
      final nome = 'registros_granix_${DateTime.now().millisecondsSinceEpoch}.csv';
      final arquivo = File('${dir.path}/$nome');
      await arquivo.writeAsString(csv);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('CSV salvo em Downloads: $nome'),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
    }
  }

  Future<void> _compartilharCsv(List<Map<String, dynamic>> itens) async {
    try {
      final arquivo = await _salvarCsvArquivo(itens);
      await Share.shareXFiles([XFile(arquivo.path)], text: 'Registros — Granix');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao compartilhar: $e')));
    }
  }

  Future<void> _enviarCsvEmail(List<Map<String, dynamic>> itens) async {
    try {
      final arquivo = await _salvarCsvArquivo(itens);
      try {
        final email = Email(
          body: 'Segue em anexo os registros financeiros.',
          subject: 'Registros — Granix',
          attachmentPaths: [arquivo.path],
          isHTML: false,
        );
        await FlutterEmailSender.send(email);
      } catch (_) {
        await Share.shareXFiles(
          [XFile(arquivo.path)],
          subject: 'Registros — Granix',
          text: 'Segue em anexo os registros financeiros.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao enviar: $e')));
    }
  }

  Future<void> _mostrarOpcoesExportacao(String acao) async {
    final visiveis = _todosItens;
    final selecionados = visiveis.where((i) => _selecionados.contains(_itemId(i))).toList();
    final todos = _todosRegistros;

    String? escopo = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Exportar CSV — Quais registros?'),
        children: [
          if (_selecionados.isNotEmpty)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 'selecionados'),
              child: ListTile(
                leading: const Icon(Icons.check_box),
                title: Text('Selecionados (${selecionados.length})'),
                dense: true,
              ),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'visiveis'),
            child: ListTile(
              leading: const Icon(Icons.filter_list),
              title: Text(
                _mesFiltro != null
                    ? 'Mês filtrado (${_nomesMeses[_mesFiltro! - 1]}/$_anoFiltro)'
                    : 'Visíveis na tela (${visiveis.length})',
              ),
              dense: true,
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'todos'),
            child: ListTile(
              leading: const Icon(Icons.select_all),
              title: Text('Todos os registros (${todos.length})'),
              dense: true,
            ),
          ),
        ],
      ),
    );

    if (escopo == null || !mounted) return;

    final itensExportar = escopo == 'selecionados'
        ? selecionados
        : escopo == 'visiveis'
            ? visiveis
            : todos;

    if (acao == 'download') _downloadCsv(itensExportar);
    if (acao == 'share') _compartilharCsv(itensExportar);
    if (acao == 'email') _enviarCsvEmail(itensExportar);
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

  void _mostrarFiltroMes() {
    final meses = _mesesDisponiveis;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final bottomPadding = MediaQuery.of(context).padding.bottom;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          builder: (context, scrollController) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
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
                      selectedTileColor:
                          Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      onTap: () {
                        setState(() {
                          _mesFiltro = null;
                          _anoFiltro = null;
                        });
                        Navigator.pop(context);
                      },
                    ),
                    const Divider(height: 8),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding + 16),
                  children: meses.map((m) {
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
                      selectedTileColor:
                          Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      onTap: () {
                        setState(() {
                          _mesFiltro = m['mes'];
                          _anoFiltro = m['ano'];
                        });
                        Navigator.pop(context);
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
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
        title: _modoSelecao
            ? Text('${_selecionados.length} selecionado(s)')
            : _modoBusca
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
                : const Text('Todos os Registros'),
        actions: [
          if (_modoSelecao) ...[
            if (_tipoSelecao != null)
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Editar em massa',
                onPressed: _editarEmMassa,
              ),
            IconButton(
              icon: const Icon(Icons.select_all),
              tooltip: 'Selecionar todos',
              onPressed: _selecionarTodos,
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'Exportar CSV',
              onSelected: (v) => _mostrarOpcoesExportacao(v),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'download',
                  child: ListTile(
                    leading: Icon(Icons.download),
                    title: Text('Baixar CSV'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
                PopupMenuItem(
                  value: 'share',
                  child: ListTile(
                    leading: Icon(Icons.share),
                    title: Text('Compartilhar CSV'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
                PopupMenuItem(
                  value: 'email',
                  child: ListTile(
                    leading: Icon(Icons.email),
                    title: Text('Enviar por e-mail'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
              ],
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
          ] else if (_modoBusca) ...[
            if (_termoBusca.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => setState(() {
                  _termoBusca = '';
                  _buscaController.clear();
                }),
              ),
            IconButton(icon: const Icon(Icons.close), onPressed: _fecharBusca),
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
              tooltip: 'Exportar CSV',
              onSelected: (v) => _mostrarOpcoesExportacao(v),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'download',
                  child: ListTile(
                    leading: Icon(Icons.download),
                    title: Text('Baixar CSV'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
                PopupMenuItem(
                  value: 'share',
                  child: ListTile(
                    leading: Icon(Icons.share),
                    title: Text('Compartilhar CSV'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
                PopupMenuItem(
                  value: 'email',
                  child: ListTile(
                    leading: Icon(Icons.email),
                    title: Text('Enviar por e-mail'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.grey[100],
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _chipTipo('Todos', 'todos', Colors.blueGrey),
                  const SizedBox(width: 8),
                  _chipTipo('Gastos', 'gasto', Colors.red),
                  const SizedBox(width: 8),
                  _chipTipo('Receitas', 'receita', Colors.green),
                  const SizedBox(width: 8),
                  _chipParcelado(),
                ],
              ),
            ),
          ),

          if (_termoBusca.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.orange.withValues(alpha: 0.1),
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

          if (filtroMesAtivo)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: primary.withValues(alpha: 0.1),
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
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).padding.bottom,
                    ),
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
                      final bool naoDetalhado = isGasto
                          ? !(item['item'] as Gasto).detalhado
                          : !(item['item'] as Receita).detalhado;

                      return Dismissible(
                        key: Key('reg_$id'),
                        direction: _modoSelecao
                            ? DismissDirection.none
                            : DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          color: Colors.red,
                          child:
                              const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (_) => showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text(
                                'Excluir ${isGasto ? 'Gasto' : 'Receita'}'),
                            content: const Text(
                                'Tem certeza que deseja excluir este registro?'),
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
                        onDismissed: (_) async {
                          if (isGasto) {
                            await _gastosBox.deleteAt(item['index'] as int);
                          } else {
                            await _receitasBox.deleteAt(item['index'] as int);
                          }
                          setState(() {});
                        },
                        child: Container(
                        decoration: BoxDecoration(
                          color: selecionado ? primary.withValues(alpha: 0.1) : null,
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
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  categoria,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
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
                            () {
                              final base = '${isGasto ? 'Gasto' : 'Receita'} • ${_formatarData(data)}${descricao.isNotEmpty ? ' • $descricao' : ''}';
                              if (isGasto) {
                                final g = item['item'] as Gasto;
                                if (g.parcelado) {
                                  return '$base • Parcela ${g.numeroParcela}/${g.numeroParcelas}';
                                }
                              }
                              return base;
                            }(),
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
                                        if (isGasto) {
                                          await _editarGasto(item);
                                        } else {
                                          final boxIndex = item['index'] as int;
                                          final resultado =
                                              await Navigator.push<Receita>(
                                                context,
                                                FadeRoute(
                                                  page: AdicionarReceitaScreen(
                                                    receita:
                                                        item['item'] as Receita,
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
                      ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chipParcelado() {
    final cor = Colors.purple;
    return GestureDetector(
      onTap: () => setState(() {
        _filtroParcelado = !_filtroParcelado;
        if (_filtroParcelado) {
          _tipoFiltro = 'gasto';
        }
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: _filtroParcelado ? cor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _filtroParcelado ? cor : Colors.grey[300]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.credit_card,
              size: 14,
              color: _filtroParcelado ? Colors.white : Colors.grey[700],
            ),
            const SizedBox(width: 4),
            Text(
              'Parcelados',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _filtroParcelado ? Colors.white : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipTipo(String label, String key, Color cor) {
    final selecionado = _tipoFiltro == key;
    return GestureDetector(
      onTap: () => setState(() {
        _tipoFiltro = key;
        if (key == 'receita' || key == 'todos') _filtroParcelado = false;
      }),
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
