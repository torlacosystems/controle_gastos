import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'gasto.dart';
import 'receita.dart';
import 'orcamento.dart';
import 'pessoa.dart';
import 'forma_pagamento.dart';

class RelatoriosScreen extends StatefulWidget {
  const RelatoriosScreen({super.key});

  @override
  State<RelatoriosScreen> createState() => _RelatoriosScreenState();
}

class _RelatoriosScreenState extends State<RelatoriosScreen> with SingleTickerProviderStateMixin {
  late Box<Gasto> _gastosBox;
  late Box<Receita> _receitasBox;
  late Box<Orcamento> _orcamentosBox;
  late Box<Pessoa> _pessoasBox;
  late Box<FormaPagamento> _formasPagamentoBox;

  DateTime _dataInicio = DateTime.now().subtract(const Duration(days: 30));
  DateTime _dataFim = DateTime.now();
  int _historicoMeses = 6;
  String _periodoSelecionado = '30d';

  // Filtros
  String? _pessoaSelecionada;
  String? _tipoFormaPagamento;
  String? _formaPagamentoSelecionada;
  bool? _filtroEsperado;
  bool? _filtroEvitavel;
  bool? _filtroFixo;
  bool? _filtroRecorrente;

  // Filtros da aba Receitas (independentes dos filtros de gastos)
  String _receitaPeriodoSelecionado = '30d';
  late DateTime _receitaDataInicio;
  late DateTime _receitaDataFim;
  String? _receitaCategoriaSelecionada;

  // Controle de linhas do gráfico (aba Gastos)
  bool _mostrarGastos = true;
  bool _mostrarReceitas = true;
  bool _mostrarSaldo = true;
  bool _mostrarAcumulado = false;

  // Controle de linhas do gráfico (aba Receitas)
  int _receitaHistoricoMeses = 6;
  bool _mostrarReceitasHist = true;
  bool _mostrarReceitasAcumulado = false;
  late TabController _tabController;

  final List<String> _nomesMeses = [
    'Jan',
    'Fev',
    'Mar',
    'Abr',
    'Mai',
    'Jun',
    'Jul',
    'Ago',
    'Set',
    'Out',
    'Nov',
    'Dez',
  ];

  final List<Map<String, String>> _periodos = [
    {'label': 'Hoje', 'key': 'hoje'},
    {'label': '1 sem', 'key': '7d'},
    {'label': '15 dias', 'key': '15d'},
    {'label': '30 dias', 'key': '30d'},
    {'label': '3 meses', 'key': '3m'},
    {'label': '6 meses', 'key': '6m'},
    {'label': '12 meses', 'key': '12m'},
    {'label': 'Todos', 'key': 'todos'},
    {'label': 'Personalizado', 'key': 'Personalizado'},
  ];

  @override
  void initState() {
    super.initState();
    _gastosBox = Hive.box<Gasto>('gastos');
    _receitasBox = Hive.box<Receita>('receitas');
    _orcamentosBox = Hive.box<Orcamento>('orcamentos');
    _pessoasBox = Hive.box<Pessoa>('pessoas');
    _formasPagamentoBox = Hive.box<FormaPagamento>('formas_pagamento');
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() { if (mounted) setState(() {}); });
    _aplicarPeriodo('30d');
    _aplicarPeriodoReceita('30d');
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _aplicarPeriodo(String key) {
    final agora = DateTime.now();
    setState(() {
      _periodoSelecionado = key;
      switch (key) {
        case 'hoje':
          _dataInicio = DateTime(agora.year, agora.month, agora.day);
          _dataFim = agora;
          break;
        case '7d':
          _dataInicio = agora.subtract(const Duration(days: 7));
          _dataFim = agora;
          break;
        case '15d':
          _dataInicio = agora.subtract(const Duration(days: 15));
          _dataFim = agora;
          break;
        case '30d':
          _dataInicio = agora.subtract(const Duration(days: 30));
          _dataFim = agora;
          break;
        case '3m':
          _dataInicio = agora.subtract(const Duration(days: 90));
          _dataFim = agora;
          break;
        case '6m':
          _dataInicio = agora.subtract(const Duration(days: 180));
          _dataFim = agora;
          break;
        case '12m':
          _dataInicio = agora.subtract(const Duration(days: 365));
          _dataFim = agora;
          break;
        case 'todos':
          _dataInicio = DateTime(2000);
          _dataFim = DateTime(2100);
          break;
        case 'Personalizado':
          break;
      }
    });
  }

  void _aplicarPeriodoReceita(String key) {
    final agora = DateTime.now();
    setState(() {
      _receitaPeriodoSelecionado = key;
      switch (key) {
        case 'hoje':
          _receitaDataInicio = DateTime(agora.year, agora.month, agora.day);
          _receitaDataFim = agora;
          break;
        case '7d':
          _receitaDataInicio = agora.subtract(const Duration(days: 7));
          _receitaDataFim = agora;
          break;
        case '15d':
          _receitaDataInicio = agora.subtract(const Duration(days: 15));
          _receitaDataFim = agora;
          break;
        case '30d':
          _receitaDataInicio = agora.subtract(const Duration(days: 30));
          _receitaDataFim = agora;
          break;
        case '3m':
          _receitaDataInicio = agora.subtract(const Duration(days: 90));
          _receitaDataFim = agora;
          break;
        case '6m':
          _receitaDataInicio = agora.subtract(const Duration(days: 180));
          _receitaDataFim = agora;
          break;
        case '12m':
          _receitaDataInicio = agora.subtract(const Duration(days: 365));
          _receitaDataFim = agora;
          break;
        case 'todos':
          _receitaDataInicio = DateTime(2000);
          _receitaDataFim = DateTime(2100);
          break;
        case 'Personalizado':
          break;
      }
    });
  }

  // ── Helpers de filtro ─────────────────────────────────────────────────────

  List<String> get _todasPessoas {
    final lista = _pessoasBox.values.toList()
      ..sort((a, b) {
        if (a.parentesco == 'Eu Mesmo') return -1;
        if (b.parentesco == 'Eu Mesmo') return 1;
        return a.nome.compareTo(b.nome);
      });
    return lista.map((p) => p.nome).toList();
  }

  String _tipoDeForma(String descricao) {
    final forma = _formasPagamentoBox.values.firstWhere(
      (f) => f.descricao == descricao,
      orElse: () => FormaPagamento(id: '', descricao: '', tipo: '', banco: ''),
    );
    return forma.tipo;
  }

  // ── Dados filtrados ───────────────────────────────────────────────────────

  List<Gasto> get _gastosFiltrados {
    return _gastosBox.values.where((g) {
      if (g.data.isBefore(_dataInicio.subtract(const Duration(days: 1))))
        return false;
      if (g.data.isAfter(_dataFim.add(const Duration(days: 1)))) return false;
      if (_pessoaSelecionada != null && g.pessoa != _pessoaSelecionada)
        return false;
      if (_tipoFormaPagamento != null &&
          _tipoDeForma(g.formaPagamento) != _tipoFormaPagamento)
        return false;
      if (_formaPagamentoSelecionada != null &&
          g.formaPagamento != _formaPagamentoSelecionada)
        return false;
      if (_filtroEsperado != null && g.gastoEsperado != _filtroEsperado)
        return false;
      if (_filtroEvitavel != null && g.gastoEvitavel != _filtroEvitavel)
        return false;
      if (_filtroFixo != null && (g.tipoGasto == 'Fixo') != _filtroFixo)
        return false;
      if (_filtroRecorrente != null && g.recorrente != _filtroRecorrente)
        return false;
      return true;
    }).toList();
  }

  List<Receita> get _receitasFiltradas {
    return _receitasBox.values.where((r) {
      if (r.data.isBefore(_receitaDataInicio.subtract(const Duration(days: 1))))
        return false;
      if (r.data.isAfter(_receitaDataFim.add(const Duration(days: 1)))) return false;
      if (_receitaCategoriaSelecionada != null && r.categoria != _receitaCategoriaSelecionada)
        return false;
      return true;
    }).toList();
  }

  double get _totalGastos => _gastosFiltrados.fold(0, (s, g) => s + g.valor);
  double get _totalReceitas =>
      _receitasFiltradas.fold(0, (s, r) => s + r.valor);
  // Receitas filtradas pelo período e filtros de gastos (usadas nos cards da aba Gastos)
  double get _totalReceitasPeriodoGastos => _receitasBox.values.where((r) {
        if (r.data.isBefore(_dataInicio.subtract(const Duration(days: 1)))) return false;
        if (r.data.isAfter(_dataFim.add(const Duration(days: 1)))) return false;
        return true;
      }).fold(0, (s, r) => s + r.valor);
  double get _saldoPeriodoGastos => _totalReceitasPeriodoGastos - _totalGastos;

  double get _totalEsperados => _gastosFiltrados
      .where((g) => g.gastoEsperado)
      .fold(0, (s, g) => s + g.valor);
  double get _totalInesperados => _gastosFiltrados
      .where((g) => !g.gastoEsperado)
      .fold(0, (s, g) => s + g.valor);
  double get _totalEvitaveis => _gastosFiltrados
      .where((g) => g.gastoEvitavel)
      .fold(0, (s, g) => s + g.valor);
  double get _totalInevitaveis => _gastosFiltrados
      .where((g) => !g.gastoEvitavel)
      .fold(0, (s, g) => s + g.valor);

  Map<String, double> get _gastosPorCategoria {
    final Map<String, double> mapa = {};
    for (final g in _gastosFiltrados) {
      mapa[g.categoria] = (mapa[g.categoria] ?? 0) + g.valor;
    }
    return mapa;
  }

  Map<String, double> get _gastosPorPessoa {
    final Map<String, double> mapa = {};
    for (final g in _gastosFiltrados) {
      if (g.pessoa.isNotEmpty) {
        mapa[g.pessoa] = (mapa[g.pessoa] ?? 0) + g.valor;
      }
    }
    return mapa;
  }

  Map<String, double> get _receitasPorCategoria {
    final Map<String, double> mapa = {};
    for (final r in _receitasFiltradas) {
      mapa[r.categoria] = (mapa[r.categoria] ?? 0) + r.valor;
    }
    return mapa;
  }

  double get _totalFixasReceita =>
      _receitasFiltradas.where((r) => r.tipoReceita == 'Fixo').fold(0, (s, r) => s + r.valor);
  double get _totalVariaveisReceita =>
      _receitasFiltradas.where((r) => r.tipoReceita == 'Variável').fold(0, (s, r) => s + r.valor);
  double get _totalRecorrentesReceita =>
      _receitasFiltradas.where((r) => r.recorrente).fold(0, (s, r) => s + r.valor);
  double get _totalNaoRecorrentesReceita =>
      _receitasFiltradas.where((r) => !r.recorrente).fold(0, (s, r) => s + r.valor);

  // ── Histórico mensal ──────────────────────────────────────────────────────

  List<DateTime> _gerarMesesHistorico() {
    final agora = DateTime.now();
    final metade = _historicoMeses ~/ 2;
    final List<DateTime> meses = [];
    for (int i = -metade; i <= metade; i++) {
      meses.add(DateTime(agora.year, agora.month + i));
    }
    return meses;
  }

  double _gastosPorMes(DateTime mes) => _gastosBox.values
      .where((g) {
        if (g.data.month != mes.month || g.data.year != mes.year) return false;
        if (_pessoaSelecionada != null && g.pessoa != _pessoaSelecionada)
          return false;
        if (_tipoFormaPagamento != null &&
            _tipoDeForma(g.formaPagamento) != _tipoFormaPagamento)
          return false;
        if (_formaPagamentoSelecionada != null &&
            g.formaPagamento != _formaPagamentoSelecionada)
          return false;
        if (_filtroEsperado != null && g.gastoEsperado != _filtroEsperado)
          return false;
        if (_filtroEvitavel != null && g.gastoEvitavel != _filtroEvitavel)
          return false;
        if (_filtroFixo != null && (g.tipoGasto == 'Fixo') != _filtroFixo)
          return false;
        if (_filtroRecorrente != null && g.recorrente != _filtroRecorrente)
          return false;
        return true;
      })
      .fold(0, (s, g) => s + g.valor);

  double _receitasPorMes(DateTime mes) => _receitasBox.values
      .where((r) {
        if (r.data.month != mes.month || r.data.year != mes.year) return false;
        return true;
      })
      .fold(0, (s, r) => s + r.valor);

  double _saldoPorMes(DateTime mes) {
    final s = _receitasPorMes(mes) - _gastosPorMes(mes);
    return s < 0 ? 0 : s;
  }

  List<double> _calcularAcumulado(List<DateTime> meses) {
    double acumulado = 0;
    return meses.map((mes) {
      acumulado += _receitasPorMes(mes) - _gastosPorMes(mes);
      return acumulado;
    }).toList();
  }

  List<DateTime> _gerarMesesHistoricoReceitas() {
    final agora = DateTime.now();
    final metade = _receitaHistoricoMeses ~/ 2;
    final List<DateTime> meses = [];
    for (int i = -metade; i <= metade; i++) {
      meses.add(DateTime(agora.year, agora.month + i));
    }
    return meses;
  }

  double _receitasPorMesHistorico(DateTime mes) => _receitasBox.values
      .where((r) {
        if (r.data.month != mes.month || r.data.year != mes.year) return false;
        if (_receitaCategoriaSelecionada != null && r.categoria != _receitaCategoriaSelecionada) return false;
        return true;
      })
      .fold(0, (s, r) => s + r.valor);

  List<double> _calcularAcumuladoReceitas(List<DateTime> meses) {
    double acumulado = 0;
    return meses.map((mes) {
      acumulado += _receitasPorMesHistorico(mes);
      return acumulado;
    }).toList();
  }

  double _gastosNoPeriodoPorCategoria(String categoria) =>
      _gastosFiltrados.where((g) => g.categoria == categoria).fold(0, (s, g) => s + g.valor);

  // limite == null → categoria sem orçamento configurado
  Widget _orcRow(String categoria, double gasto, double? limite) {
    final semLimite = limite == null;
    final percentual = (limite != null && limite > 0) ? (gasto / limite) : null;
    final ultrapassou = percentual != null && percentual >= 1.0;
    final corPct = semLimite
        ? Colors.blueGrey
        : ultrapassou
            ? Colors.red
            : percentual! >= 0.75
                ? Colors.orange
                : Colors.green;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 90,
                child: Text(
                  categoria,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: LayoutBuilder(
                  builder: (ctx, constraints) {
                    final total = constraints.maxWidth;
                    if (semLimite) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                            height: 20, color: Colors.blueGrey.shade200),
                      );
                    }
                    if (ultrapassou) {
                      final limiteW = total * 0.75;
                      final excedenteW = total - limiteW;
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: SizedBox(
                              height: 20,
                              child: Row(
                                children: [
                                  Container(width: limiteW, color: Colors.green[600]),
                                  Container(width: excedenteW, color: Colors.red[600]),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            left: limiteW - 1.5,
                            top: 0,
                            bottom: 0,
                            child: Container(width: 3, color: Colors.white),
                          ),
                        ],
                      );
                    }
                    final gastoW = (percentual! * total).clamp(0.0, total);
                    final restoW = total - gastoW;
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        height: 20,
                        child: Row(
                          children: [
                            if (gastoW > 0) Container(width: gastoW, color: corPct),
                            if (restoW > 0) Container(width: restoW, color: Colors.grey.shade200),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 50,
                child: Text(
                  semLimite
                      ? '—'
                      : '${(percentual! * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: corPct),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 98),
            child: Row(
              children: [
                Text(
                  _formatarValor(gasto),
                  style: TextStyle(
                      fontSize: 10,
                      color: corPct,
                      fontWeight: FontWeight.w600),
                ),
                const Text(' / ',
                    style: TextStyle(fontSize: 10, color: Colors.grey)),
                Text(
                  semLimite ? 'sem limite' : _formatarValor(limite),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                if (ultrapassou) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.warning_amber, color: Colors.red, size: 12),
                  const SizedBox(width: 2),
                  Text(
                    'Limite excedido',
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.red[700],
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatarValor(double valor) =>
      'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';

  String _formatarData(DateTime data) =>
      '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';

  Future<void> _selecionarDataInicio() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataInicio,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _dataInicio = picked);
  }

  Future<void> _selecionarDataFim() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataFim,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _dataFim = picked);
  }

  // ── PDF ───────────────────────────────────────────────────────────────────

  static const int _kMaxLinhasPdf = 500;

  Future<pw.Document> _gerarPdf() async {
    final doc = pw.Document();
    String periodoTexto;
    if (_periodoSelecionado == 'todos') {
      final todosGastosBox = Hive.box<Gasto>('gastos');
      final todasReceitasBox = Hive.box<Receita>('receitas');
      final todasDatas = [
        ...todosGastosBox.values.map((g) => g.data),
        ...todasReceitasBox.values.map((r) => r.data),
      ];
      if (todasDatas.isEmpty) {
        periodoTexto = '${_formatarData(_dataInicio)} ate ${_formatarData(_dataFim)}';
      } else {
        final primeiro = todasDatas.reduce((a, b) => a.isBefore(b) ? a : b);
        final ultimo = todasDatas.reduce((a, b) => a.isAfter(b) ? a : b);
        periodoTexto = '${_formatarData(primeiro)} ate ${_formatarData(ultimo)}';
      }
    } else {
      periodoTexto = '${_formatarData(_dataInicio)} ate ${_formatarData(_dataFim)}';
    }
    final gastosPorCat = _gastosPorCategoria;

    final todosGastos = _gastosFiltrados..sort((a, b) => a.data.compareTo(b.data));
    final todasReceitas = _receitasFiltradas..sort((a, b) => a.data.compareTo(b.data));
    final gastosTruncados = todosGastos.length > _kMaxLinhasPdf;
    final receitasTruncadas = todasReceitas.length > _kMaxLinhasPdf;
    final gastosParaPdf = gastosTruncados
        ? todosGastos.sublist(todosGastos.length - _kMaxLinhasPdf)
        : todosGastos;
    final receitasParaPdf = receitasTruncadas
        ? todasReceitas.sublist(todasReceitas.length - _kMaxLinhasPdf)
        : todasReceitas;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Text(
            'Relatorio Financeiro - Granix',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Periodo: $periodoTexto',
            style: const pw.TextStyle(fontSize: 12),
          ),
          if (_pessoaSelecionada != null)
            pw.Text(
              'Pessoa: $_pessoaSelecionada',
              style: const pw.TextStyle(fontSize: 12),
            ),
          if (_tipoFormaPagamento != null)
            pw.Text(
              'Pagamento: $_tipoFormaPagamento${_formaPagamentoSelecionada != null ? ' › $_formaPagamentoSelecionada' : ''}',
              style: const pw.TextStyle(fontSize: 12),
            ),
          pw.SizedBox(height: 16),
          pw.Row(
            children: [
              _pdfCard('Gastos', _formatarValor(_totalGastos)),
              pw.SizedBox(width: 8),
              _pdfCard('Receitas', _formatarValor(_totalReceitasPeriodoGastos)),
              pw.SizedBox(width: 8),
              _pdfCard('Saldo', _formatarValor(_saldoPeriodoGastos)),
              pw.SizedBox(width: 8),
              _pdfCard(
                'Transacoes',
                '${todosGastos.length + todasReceitas.length}',
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          if (gastosPorCat.isNotEmpty) ...[
            pw.Text(
              'Gastos por Categoria',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['Categoria', 'Total'],
              data: gastosPorCat.entries
                  .map((e) => [e.key, _formatarValor(e.value)])
                  .toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              border: pw.TableBorder.all(color: PdfColors.grey300),
              cellAlignment: pw.Alignment.centerLeft,
            ),
            pw.SizedBox(height: 20),
          ],
          pw.Text(
            'Gastos${gastosTruncados ? ' (ultimos $_kMaxLinhasPdf de ${todosGastos.length})' : ''}',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          if (gastosTruncados)
            pw.Text(
              'Use filtros de periodo/pessoa para exportar um intervalo menor.',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          pw.SizedBox(height: 8),
          gastosParaPdf.isEmpty
              ? pw.Text('Nenhum gasto no periodo.', style: const pw.TextStyle(color: PdfColors.grey))
              : pw.TableHelper.fromTextArray(
                  headers: ['Data', 'Categoria', 'Descricao', 'Valor'],
                  data: gastosParaPdf
                      .map((g) => [
                            _formatarData(g.data),
                            g.categoria,
                            g.descricao.isEmpty ? '-' : g.descricao,
                            _formatarValor(g.valor),
                          ])
                      .toList(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  cellAlignment: pw.Alignment.centerLeft,
                ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Receitas${receitasTruncadas ? ' (ultimas $_kMaxLinhasPdf de ${todasReceitas.length})' : ''}',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          if (receitasTruncadas)
            pw.Text(
              'Use filtros de periodo/pessoa para exportar um intervalo menor.',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          pw.SizedBox(height: 8),
          receitasParaPdf.isEmpty
              ? pw.Text('Nenhuma receita no periodo.', style: const pw.TextStyle(color: PdfColors.grey))
              : pw.TableHelper.fromTextArray(
                  headers: ['Data', 'Categoria', 'Descricao', 'Valor'],
                  data: receitasParaPdf
                      .map((r) => [
                            _formatarData(r.data),
                            r.categoria,
                            r.descricao.isEmpty ? '-' : r.descricao,
                            _formatarValor(r.valor),
                          ])
                      .toList(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  cellAlignment: pw.Alignment.centerLeft,
                ),
        ],
      ),
    );
    return doc;
  }

  pw.Widget _pdfCard(String titulo, String valor) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              titulo,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              valor,
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _mostrarLoadingPdf() {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Gerando PDF...'),
          ],
        ),
      ),
    );
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

  Future<void> _downloadPdf() async {
    _mostrarLoadingPdf();
    try {
      await Future.microtask(() {});
      final doc = await _gerarPdf();
      final bytes = await doc.save();
      if (!mounted) return;
      Navigator.of(context).pop();
      final dir = await _pastaDownloads();
      final nome = 'relatorio_granix_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final arquivo = File('${dir.path}/$nome');
      await arquivo.writeAsBytes(bytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF salvo em Downloads: $nome'), duration: const Duration(seconds: 4)),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar PDF: $e')));
    }
  }

  Future<void> _compartilharPdf() async {
    _mostrarLoadingPdf();
    try {
      await Future.microtask(() {});
      final doc = await _gerarPdf();
      final bytes = await doc.save();
      if (!mounted) return;
      Navigator.of(context).pop();
      final dir = await getApplicationDocumentsDirectory();
      final arquivo = File('${dir.path}/relatorio_granix.pdf');
      await arquivo.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(arquivo.path)],
        subject: 'Relatório Financeiro — Granix',
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao compartilhar PDF: $e')));
    }
  }

  Future<void> _enviarPdfEmail() async {
    _mostrarLoadingPdf();
    try {
      await Future.microtask(() {});
      final doc = await _gerarPdf();
      final bytes = await doc.save();
      final dir = await getApplicationDocumentsDirectory();
      final arquivo = File('${dir.path}/relatorio_financeiro.pdf');
      await arquivo.writeAsBytes(bytes);
      try {
        final email = Email(
          body: 'Segue em anexo o relatório financeiro.',
          subject: 'Relatório Financeiro',
          attachmentPaths: [arquivo.path],
          isHTML: false,
        );
        await FlutterEmailSender.send(email);
        if (mounted) Navigator.of(context).pop();
      } catch (_) {
        if (mounted) Navigator.of(context).pop();
        await Share.shareXFiles(
          [XFile(arquivo.path)],
          subject: 'Relatório Financeiro',
          text: 'Segue em anexo o relatório financeiro.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao enviar PDF: $e')));
    }
  }

  // ── Helpers de UI ─────────────────────────────────────────────────────────

  final List<Color> _coresCategorias = [
    Colors.blue,
    Colors.red,
    Colors.orange,
    Colors.green,
    Colors.purple,
    Colors.teal,
    Colors.pink,
  ];

  Widget _dropFiltro<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        isDense: true,
      ),
      items: items,
      onChanged: onChanged,
    );
  }

  Widget _toggleLinha(Color cor, String label, bool ativo, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: ativo ? cor : Colors.grey[300],
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: ativo ? Colors.black87 : Colors.grey,
              decoration: ativo ? null : TextDecoration.lineThrough,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gastosPorCat = _gastosPorCategoria;
    final categorias = gastosPorCat.keys.toList()
      ..sort((a, b) {
        if (a == 'Outros') return 1;
        if (b == 'Outros') return -1;
        return a.compareTo(b);
      });
    final mesesHistorico = _gerarMesesHistorico();
    final agora = DateTime.now();
    final orcamentos = _orcamentosBox.values.toList()
      ..sort((a, b) {
        if (a.categoria == 'Outros') return 1;
        if (b.categoria == 'Outros') return -1;
        return a.categoria.compareTo(b.categoria);
      });
    final todasPessoas = _todasPessoas;
    final acumulados = _calcularAcumulado(mesesHistorico);
    final gastosPorPessoa = _gastosPorPessoa;
    final pessoasList = gastosPorPessoa.keys.toList();
    final totalPessoas = gastosPorPessoa.values.fold(0.0, (s, v) => s + v);

    final temFiltroAtivo =
        _pessoaSelecionada != null ||
        _tipoFormaPagamento != null ||
        _formaPagamentoSelecionada != null ||
        _filtroEsperado != null ||
        _filtroEvitavel != null ||
        _filtroFixo != null ||
        _filtroRecorrente != null;

    double maxY = 0;
    for (int i = 0; i < mesesHistorico.length; i++) {
      final mes = mesesHistorico[i];
      if (_mostrarGastos && _gastosPorMes(mes) > maxY)
        maxY = _gastosPorMes(mes);
      if (_mostrarReceitas && _receitasPorMes(mes) > maxY)
        maxY = _receitasPorMes(mes);
      if (_mostrarSaldo && _saldoPorMes(mes) > maxY) maxY = _saldoPorMes(mes);
      if (_mostrarAcumulado && acumulados[i].abs() > maxY)
        maxY = acumulados[i].abs();
    }
    maxY = maxY == 0 ? 100 : maxY * 1.2;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Relatórios'),
            if (temFiltroAtivo) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Filtrado', style: TextStyle(fontSize: 11)),
              ),
            ],
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.trending_down, size: 18), text: 'Gastos'),
            Tab(icon: Icon(Icons.trending_up, size: 18), text: 'Receitas'),
          ],
        ),
        actions: [
          if (temFiltroAtivo)
            IconButton(
              icon: const Icon(Icons.filter_alt_off),
              tooltip: 'Limpar filtros',
              onPressed: () => setState(() {
                _pessoaSelecionada = null;
                _tipoFormaPagamento = null;
                _formaPagamentoSelecionada = null;
                _filtroEsperado = null;
                _filtroEvitavel = null;
                _filtroFixo = null;
                _filtroRecorrente = null;
              }),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Exportar PDF',
            onSelected: (v) {
              if (v == 'download') _downloadPdf();
              if (v == 'share') _compartilharPdf();
              if (v == 'email') _enviarPdfEmail();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'download',
                child: ListTile(
                  leading: Icon(Icons.download),
                  title: Text('Baixar PDF'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              PopupMenuItem(
                value: 'share',
                child: ListTile(
                  leading: Icon(Icons.share),
                  title: Text('Compartilhar PDF'),
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
      ),
      body: _tabController.index == 0
          ? SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).padding.bottom + 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── FILTROS ────────────────────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _dropFiltro<String>(
                            label: 'Período',
                            value: _periodoSelecionado,
                            items: _periodos.map((p) => DropdownMenuItem(
                              value: p['key']!,
                              child: Text(p['label']!, style: const TextStyle(fontSize: 13)),
                            )).toList(),
                            onChanged: (v) {
                              if (v == 'Personalizado') setState(() => _periodoSelecionado = 'Personalizado');
                              else if (v != null) _aplicarPeriodo(v);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _dropFiltro<String>(
                            label: 'Pessoa',
                            value: _pessoaSelecionada,
                            items: [
                              const DropdownMenuItem(value: null, child: Text('Todas', style: TextStyle(fontSize: 13))),
                              ...todasPessoas.map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 13)))),
                            ],
                            onChanged: (v) => setState(() => _pessoaSelecionada = v),
                          ),
                        ),
                      ],
                    ),
                    if (_periodoSelecionado == 'Personalizado') ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: _selecionarDataInicio,
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'De',
                                  labelStyle: TextStyle(fontSize: 12),
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  isDense: true,
                                ),
                                child: Text(_formatarData(_dataInicio), style: const TextStyle(fontSize: 13)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GestureDetector(
                              onTap: _selecionarDataFim,
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Até',
                                  labelStyle: TextStyle(fontSize: 12),
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  isDense: true,
                                ),
                                child: Text(_formatarData(_dataFim), style: const TextStyle(fontSize: 13)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else if (_periodoSelecionado != 'todos') ...[
                      const SizedBox(height: 4),
                      Text(
                        '${_formatarData(_dataInicio)} até ${_formatarData(_dataFim)}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                    if (_formasPagamentoBox.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _dropFiltro<String>(
                              label: 'Tipo pagamento',
                              value: _tipoFormaPagamento,
                              items: [
                                const DropdownMenuItem(value: null, child: Text('Todos', style: TextStyle(fontSize: 13))),
                                ...[
                                  'Crédito', 'Débito', 'VA/VR'
                                ].where((t) => _formasPagamentoBox.values.any((f) => f.tipo == t))
                                  .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13)))),
                              ],
                              onChanged: (v) => setState(() {
                                _tipoFormaPagamento = v;
                                _formaPagamentoSelecionada = null;
                              }),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _dropFiltro<String>(
                              label: 'Cartão / Conta',
                              value: _formaPagamentoSelecionada,
                              items: [
                                const DropdownMenuItem(value: null, child: Text('Todos', style: TextStyle(fontSize: 13))),
                                ..._formasPagamentoBox.values
                                  .where((f) => _tipoFormaPagamento == null || f.tipo == _tipoFormaPagamento)
                                  .map((f) => DropdownMenuItem(value: f.descricao, child: Text(f.descricao, style: const TextStyle(fontSize: 13)))),
                              ],
                              onChanged: (v) => setState(() => _formaPagamentoSelecionada = v),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _dropFiltro<bool>(
                            label: 'Esperado',
                            value: _filtroEsperado,
                            items: const [
                              DropdownMenuItem(value: null, child: Text('Todos', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(value: true, child: Text('Sim', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(value: false, child: Text('Não', style: TextStyle(fontSize: 13))),
                            ],
                            onChanged: (v) => setState(() => _filtroEsperado = v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _dropFiltro<bool>(
                            label: 'Evitável',
                            value: _filtroEvitavel,
                            items: const [
                              DropdownMenuItem(value: null, child: Text('Todos', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(value: true, child: Text('Sim', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(value: false, child: Text('Não', style: TextStyle(fontSize: 13))),
                            ],
                            onChanged: (v) => setState(() => _filtroEvitavel = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _dropFiltro<bool>(
                            label: 'Fixo',
                            value: _filtroFixo,
                            items: const [
                              DropdownMenuItem(value: null, child: Text('Todos', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(value: true, child: Text('Sim', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(value: false, child: Text('Não', style: TextStyle(fontSize: 13))),
                            ],
                            onChanged: (v) => setState(() => _filtroFixo = v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _dropFiltro<bool>(
                            label: 'Recorrente',
                            value: _filtroRecorrente,
                            items: const [
                              DropdownMenuItem(value: null, child: Text('Todos', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(value: true, child: Text('Sim', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(value: false, child: Text('Não', style: TextStyle(fontSize: 13))),
                            ],
                            onChanged: (v) => setState(() => _filtroRecorrente = v),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── CARDS DE RESUMO ────────────────────────────────────────────
            Row(
              children: [
                _cardResumo('Gastos', _totalGastos, Colors.red),
                const SizedBox(width: 8),
                _cardResumo('Receitas', _totalReceitasPeriodoGastos, Colors.green),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _cardResumo(
                  'Saldo',
                  _saldoPeriodoGastos,
                  _saldoPeriodoGastos >= 0 ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                _cardResumo(
                  'Transações',
                  (_gastosFiltrados.length + _receitasFiltradas.length)
                      .toDouble(),
                  Colors.blue,
                  isCount: true,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── HISTÓRICO MENSAL ───────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Histórico Mensal',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [3, 6, 12].map((meses) {
                    final sel = _historicoMeses == meses;
                    return Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: GestureDetector(
                        onTap: () => setState(() => _historicoMeses = meses),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: sel
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '${meses}m',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: sel ? Colors.white : Colors.grey[700],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                child: Column(
                  children: [
                    SizedBox(
                      height: 220,
                      child: LineChart(
                        LineChartData(
                          minY: _mostrarAcumulado ? null : 0,
                          maxY: maxY,
                          lineBarsData: [
                            if (_mostrarGastos)
                              LineChartBarData(
                                spots: mesesHistorico
                                    .asMap()
                                    .entries
                                    .map(
                                      (e) => FlSpot(
                                        e.key.toDouble(),
                                        _gastosPorMes(e.value),
                                      ),
                                    )
                                    .toList(),
                                isCurved: true,
                                color: Colors.red,
                                barWidth: 3,
                                dotData: FlDotData(
                                  getDotPainter: (spot, percent, bar, index) {
                                    final mes = mesesHistorico[index];
                                    final isMesAtual =
                                        mes.month == agora.month &&
                                        mes.year == agora.year;
                                    return FlDotCirclePainter(
                                      radius: isMesAtual ? 6 : 3,
                                      color: Colors.red,
                                      strokeWidth: isMesAtual ? 2 : 0,
                                      strokeColor: Colors.white,
                                    );
                                  },
                                ),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: Colors.red.withValues(alpha: 0.08),
                                ),
                              ),
                            if (_mostrarReceitas)
                              LineChartBarData(
                                spots: mesesHistorico
                                    .asMap()
                                    .entries
                                    .map(
                                      (e) => FlSpot(
                                        e.key.toDouble(),
                                        _receitasPorMes(e.value),
                                      ),
                                    )
                                    .toList(),
                                isCurved: true,
                                color: Colors.green,
                                barWidth: 3,
                                dotData: FlDotData(
                                  getDotPainter: (spot, percent, bar, index) {
                                    final mes = mesesHistorico[index];
                                    final isMesAtual =
                                        mes.month == agora.month &&
                                        mes.year == agora.year;
                                    return FlDotCirclePainter(
                                      radius: isMesAtual ? 6 : 3,
                                      color: Colors.green,
                                      strokeWidth: isMesAtual ? 2 : 0,
                                      strokeColor: Colors.white,
                                    );
                                  },
                                ),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: Colors.green.withValues(alpha: 0.08),
                                ),
                              ),
                            if (_mostrarSaldo)
                              LineChartBarData(
                                spots: mesesHistorico
                                    .asMap()
                                    .entries
                                    .map(
                                      (e) => FlSpot(
                                        e.key.toDouble(),
                                        _saldoPorMes(e.value),
                                      ),
                                    )
                                    .toList(),
                                isCurved: true,
                                color: Colors.blue,
                                barWidth: 3,
                                dashArray: [6, 3],
                                dotData: FlDotData(
                                  getDotPainter: (spot, percent, bar, index) {
                                    final mes = mesesHistorico[index];
                                    final isMesAtual =
                                        mes.month == agora.month &&
                                        mes.year == agora.year;
                                    return FlDotCirclePainter(
                                      radius: isMesAtual ? 6 : 3,
                                      color: Colors.blue,
                                      strokeWidth: isMesAtual ? 2 : 0,
                                      strokeColor: Colors.white,
                                    );
                                  },
                                ),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: Colors.blue.withValues(alpha: 0.05),
                                ),
                              ),
                            if (_mostrarAcumulado)
                              LineChartBarData(
                                spots: acumulados
                                    .asMap()
                                    .entries
                                    .map(
                                      (e) => FlSpot(e.key.toDouble(), e.value),
                                    )
                                    .toList(),
                                isCurved: true,
                                color: Colors.purple,
                                barWidth: 3,
                                dashArray: [3, 3],
                                dotData: FlDotData(
                                  getDotPainter: (spot, percent, bar, index) {
                                    final mes = mesesHistorico[index];
                                    final isMesAtual =
                                        mes.month == agora.month &&
                                        mes.year == agora.year;
                                    return FlDotCirclePainter(
                                      radius: isMesAtual ? 6 : 3,
                                      color: Colors.purple,
                                      strokeWidth: isMesAtual ? 2 : 0,
                                      strokeColor: Colors.white,
                                    );
                                  },
                                ),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: Colors.purple.withValues(alpha: 0.05),
                                ),
                              ),
                          ],
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 1,
                                getTitlesWidget: (value, meta) {
                                  final i = value.toInt();
                                  if (i < 0 || i >= mesesHistorico.length) {
                                    return const Text('');
                                  }
                                  final mes = mesesHistorico[i];
                                  final isMesAtual =
                                      mes.month == agora.month &&
                                      mes.year == agora.year;
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      _nomesMeses[mes.month - 1],
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: isMesAtual
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: isMesAtual
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.primary
                                            : Colors.grey,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 55,
                                getTitlesWidget: (value, meta) => Text(
                                  'R\$${value.toInt()}',
                                  style: const TextStyle(fontSize: 9),
                                ),
                              ),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          gridData: const FlGridData(show: true),
                          borderData: FlBorderData(show: false),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        _toggleLinha(
                          Colors.red,
                          'Gastos',
                          _mostrarGastos,
                          () =>
                              setState(() => _mostrarGastos = !_mostrarGastos),
                        ),
                        _toggleLinha(
                          Colors.green,
                          'Receitas',
                          _mostrarReceitas,
                          () => setState(
                            () => _mostrarReceitas = !_mostrarReceitas,
                          ),
                        ),
                        _toggleLinha(
                          Colors.blue,
                          'Saldo mensal',
                          _mostrarSaldo,
                          () => setState(() => _mostrarSaldo = !_mostrarSaldo),
                        ),
                        _toggleLinha(
                          Colors.purple,
                          'Acumulado',
                          _mostrarAcumulado,
                          () => setState(
                            () => _mostrarAcumulado = !_mostrarAcumulado,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Toque nas legendas para mostrar/ocultar • Mês atual destacado',
                      style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── GASTOS POR PESSOA ──────────────────────────────────────────
            const Text(
              'Gastos por Pessoa',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: pessoasList.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Nenhum gasto com pessoa associada no período',
                            style: TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          SizedBox(
                            height: 200,
                            child: PieChart(
                              PieChartData(
                                sections: pessoasList.asMap().entries.map((entry) {
                                  final i = entry.key;
                                  final pessoa = entry.value;
                                  final valor = gastosPorPessoa[pessoa]!;
                                  final pct = totalPessoas > 0 ? valor / totalPessoas * 100 : 0;
                                  return PieChartSectionData(
                                    value: valor,
                                    color: _coresCategorias[i % _coresCategorias.length],
                                    title: '${pct.toStringAsFixed(1)}%',
                                    titleStyle: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    radius: 80,
                                  );
                                }).toList(),
                                sectionsSpace: 2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: pessoasList.asMap().entries.map((entry) {
                              final i = entry.key;
                              final pessoa = entry.value;
                              return _legenda(
                                _coresCategorias[i % _coresCategorias.length],
                                pessoa,
                                _formatarValor(gastosPorPessoa[pessoa]!),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // ── GASTOS ESPERADOS VS INESPERADOS ────────────────────────────
            const Text(
              'Gastos Esperados vs Inesperados',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _totalEsperados == 0 && _totalInesperados == 0
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Nenhum gasto no período',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          SizedBox(
                            height: 180,
                            child: PieChart(
                              PieChartData(
                                sections: [
                                  if (_totalEsperados > 0)
                                    PieChartSectionData(
                                      value: _totalEsperados,
                                      color: Colors.blue,
                                      title:
                                          '${(_totalEsperados / _totalGastos * 100).toStringAsFixed(1)}%',
                                      titleStyle: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      radius: 70,
                                    ),
                                  if (_totalInesperados > 0)
                                    PieChartSectionData(
                                      value: _totalInesperados,
                                      color: Colors.orange,
                                      title:
                                          '${(_totalInesperados / _totalGastos * 100).toStringAsFixed(1)}%',
                                      titleStyle: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      radius: 70,
                                    ),
                                ],
                                sectionsSpace: 2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _legenda(
                                Colors.blue,
                                'Esperados',
                                _formatarValor(_totalEsperados),
                              ),
                              const SizedBox(width: 24),
                              _legenda(
                                Colors.orange,
                                'Inesperados',
                                _formatarValor(_totalInesperados),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // ── GASTOS EVITÁVEIS VS INEVITÁVEIS ───────────────────────────
            const Text(
              'Gastos Evitáveis vs Inevitáveis',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _totalEvitaveis == 0 && _totalInevitaveis == 0
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Nenhum gasto no período',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          SizedBox(
                            height: 180,
                            child: PieChart(
                              PieChartData(
                                sections: [
                                  if (_totalEvitaveis > 0)
                                    PieChartSectionData(
                                      value: _totalEvitaveis,
                                      color: Colors.red,
                                      title:
                                          '${(_totalEvitaveis / _totalGastos * 100).toStringAsFixed(1)}%',
                                      titleStyle: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      radius: 70,
                                    ),
                                  if (_totalInevitaveis > 0)
                                    PieChartSectionData(
                                      value: _totalInevitaveis,
                                      color: Colors.green,
                                      title:
                                          '${(_totalInevitaveis / _totalGastos * 100).toStringAsFixed(1)}%',
                                      titleStyle: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      radius: 70,
                                    ),
                                ],
                                sectionsSpace: 2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _legenda(
                                Colors.red,
                                'Evitáveis',
                                _formatarValor(_totalEvitaveis),
                              ),
                              const SizedBox(width: 24),
                              _legenda(
                                Colors.green,
                                'Inevitáveis',
                                _formatarValor(_totalInevitaveis),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // ── GASTOS POR CATEGORIA ───────────────────────────────────────
            const Text(
              'Gastos por Categoria',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: gastosPorCat.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Nenhum gasto no período',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          SizedBox(
                            height: 200,
                            child: PieChart(
                              PieChartData(
                                sections: categorias.asMap().entries.map((
                                  entry,
                                ) {
                                  final i = entry.key;
                                  final cat = entry.value;
                                  final valor = gastosPorCat[cat]!;
                                  final pct = valor / _totalGastos * 100;
                                  return PieChartSectionData(
                                    value: valor,
                                    color:
                                        _coresCategorias[i %
                                            _coresCategorias.length],
                                    title: '${pct.toStringAsFixed(1)}%',
                                    titleStyle: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    radius: 80,
                                  );
                                }).toList(),
                                sectionsSpace: 2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: categorias.asMap().entries.map((entry) {
                              final i = entry.key;
                              final cat = entry.value;
                              return _legenda(
                                _coresCategorias[i % _coresCategorias.length],
                                cat,
                                _formatarValor(gastosPorCat[cat]!),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // ── ORÇAMENTO POR CATEGORIA ────────────────────────────────────
            Builder(builder: (context) {
              final catsSemLimite = _gastosPorCategoria.keys
                  .where((c) => !orcamentos.any((o) => o.categoria == c))
                  .toList()
                ..sort((a, b) {
                    if (a == 'Outros') return 1;
                    if (b == 'Outros') return -1;
                    return a.compareTo(b);
                  });
              if (orcamentos.isEmpty && catsSemLimite.isEmpty) {
                return const SizedBox.shrink();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Orçamento por Categoria',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              _legendaItem(Colors.green, 'Gasto'),
                              const SizedBox(width: 16),
                              _legendaItem(Colors.grey.shade300, 'Disponível'),
                              const SizedBox(width: 16),
                              _legendaItem(Colors.red[300]!, 'Excedido'),
                              const SizedBox(width: 16),
                              _legendaItem(Colors.blueGrey.shade200, 'Sem limite'),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ...orcamentos.map((orc) =>
                              _orcRow(orc.categoria,
                                  _gastosNoPeriodoPorCategoria(orc.categoria),
                                  orc.limite)),
                          ...catsSemLimite.map((cat) =>
                              _orcRow(cat,
                                  _gastosNoPeriodoPorCategoria(cat),
                                  null)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
              );
            }),
          ],
        ),
      )
          : _buildReceitasTab(context),
    );
  }

  Widget _buildReceitasTab(BuildContext context) {
    final todasCategorias = _receitasBox.values.map((r) => r.categoria).toSet().toList()
      ..sort((a, b) {
        if (a == 'Outros') return 1;
        if (b == 'Outros') return -1;
        return a.compareTo(b);
      });
    final receitasPorCat = _receitasPorCategoria;
    final categorias = receitasPorCat.keys.toList();
    final total = _totalReceitas;

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── FILTROS ────────────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _dropFiltro<String>(
                          label: 'Período',
                          value: _receitaPeriodoSelecionado,
                          items: _periodos.map((p) => DropdownMenuItem(
                            value: p['key']!,
                            child: Text(p['label']!, style: const TextStyle(fontSize: 13)),
                          )).toList(),
                          onChanged: (v) {
                            if (v == 'Personalizado') setState(() => _receitaPeriodoSelecionado = 'Personalizado');
                            else if (v != null) _aplicarPeriodoReceita(v);
                          },
                        ),
                      ),
                    ],
                  ),
                  if (_receitaPeriodoSelecionado == 'Personalizado') ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _receitaDataInicio,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) setState(() => _receitaDataInicio = picked);
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'De',
                                labelStyle: TextStyle(fontSize: 12),
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                isDense: true,
                              ),
                              child: Text(_formatarData(_receitaDataInicio), style: const TextStyle(fontSize: 13)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _receitaDataFim,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) setState(() => _receitaDataFim = picked);
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Até',
                                labelStyle: TextStyle(fontSize: 12),
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                isDense: true,
                              ),
                              child: Text(_formatarData(_receitaDataFim), style: const TextStyle(fontSize: 13)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else if (_receitaPeriodoSelecionado != 'todos') ...[
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${_formatarData(_receitaDataInicio)} até ${_formatarData(_receitaDataFim)}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ),
                  ],
                  if (todasCategorias.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _dropFiltro<String>(
                      label: 'Categoria',
                      value: _receitaCategoriaSelecionada,
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Todas', style: TextStyle(fontSize: 13))),
                        ...todasCategorias.map((cat) => DropdownMenuItem(value: cat, child: Text(cat, style: const TextStyle(fontSize: 13)))),
                      ],
                      onChanged: (v) => setState(() => _receitaCategoriaSelecionada = v),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── CARDS DE RESUMO ──────────────────────────────────────────
          Row(
            children: [
              _cardResumo('Total de Receitas', total, Colors.green),
              const SizedBox(width: 8),
              _cardResumo(
                'Transações',
                _receitasFiltradas.length.toDouble(),
                Colors.blue,
                isCount: true,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── HISTÓRICO MENSAL DE RECEITAS ───────────────────────────────
          Builder(builder: (context) {
            final agora = DateTime.now();
            final mesesReceitas = _gerarMesesHistoricoReceitas();
            final acumuladosReceitas = _calcularAcumuladoReceitas(mesesReceitas);
            final maxYR = [
              if (_mostrarReceitasHist)
                ...mesesReceitas.map(_receitasPorMesHistorico),
              if (_mostrarReceitasAcumulado) ...acumuladosReceitas,
              0.0,
            ].reduce((a, b) => a > b ? a : b) * 1.2;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Histórico Mensal',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [3, 6, 12].map((m) {
                        final sel = _receitaHistoricoMeses == m;
                        return Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: GestureDetector(
                            onTap: () => setState(() => _receitaHistoricoMeses = m),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: sel ? Theme.of(context).colorScheme.primary : Colors.grey[200],
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                '${m}m',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: sel ? Colors.white : Colors.grey[700],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 220,
                          child: LineChart(
                            LineChartData(
                              minY: 0,
                              maxY: maxYR > 0 ? maxYR : 1000,
                              lineBarsData: [
                                if (_mostrarReceitasHist)
                                  LineChartBarData(
                                    spots: mesesReceitas.asMap().entries.map((e) =>
                                        FlSpot(e.key.toDouble(), _receitasPorMesHistorico(e.value))).toList(),
                                    isCurved: true,
                                    color: Colors.green,
                                    barWidth: 3,
                                    dotData: FlDotData(
                                      getDotPainter: (spot, percent, bar, index) {
                                        final mes = mesesReceitas[index];
                                        final atual = mes.month == agora.month && mes.year == agora.year;
                                        return FlDotCirclePainter(
                                          radius: atual ? 6 : 3,
                                          color: Colors.green,
                                          strokeWidth: atual ? 2 : 0,
                                          strokeColor: Colors.white,
                                        );
                                      },
                                    ),
                                    belowBarData: BarAreaData(show: true, color: Colors.green.withValues(alpha: 0.08)),
                                  ),
                                if (_mostrarReceitasAcumulado)
                                  LineChartBarData(
                                    spots: acumuladosReceitas.asMap().entries.map((e) =>
                                        FlSpot(e.key.toDouble(), e.value)).toList(),
                                    isCurved: true,
                                    color: Colors.purple,
                                    barWidth: 3,
                                    dashArray: [3, 3],
                                    dotData: FlDotData(
                                      getDotPainter: (spot, percent, bar, index) {
                                        final mes = mesesReceitas[index];
                                        final atual = mes.month == agora.month && mes.year == agora.year;
                                        return FlDotCirclePainter(
                                          radius: atual ? 6 : 3,
                                          color: Colors.purple,
                                          strokeWidth: atual ? 2 : 0,
                                          strokeColor: Colors.white,
                                        );
                                      },
                                    ),
                                    belowBarData: BarAreaData(show: true, color: Colors.purple.withValues(alpha: 0.05)),
                                  ),
                              ],
                              titlesData: FlTitlesData(
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    interval: 1,
                                    getTitlesWidget: (value, meta) {
                                      final i = value.toInt();
                                      if (i < 0 || i >= mesesReceitas.length) return const Text('');
                                      final mes = mesesReceitas[i];
                                      final atual = mes.month == agora.month && mes.year == agora.year;
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          _nomesMeses[mes.month - 1],
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: atual ? FontWeight.bold : FontWeight.normal,
                                            color: atual ? Theme.of(context).colorScheme.primary : Colors.grey,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 55,
                                    getTitlesWidget: (value, meta) => Text(
                                      'R\$${value.toInt()}',
                                      style: const TextStyle(fontSize: 9),
                                    ),
                                  ),
                                ),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              ),
                              gridData: const FlGridData(show: true),
                              borderData: FlBorderData(show: false),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            _toggleLinha(Colors.green, 'Receitas', _mostrarReceitasHist,
                                () => setState(() => _mostrarReceitasHist = !_mostrarReceitasHist)),
                            _toggleLinha(Colors.purple, 'Acumulado', _mostrarReceitasAcumulado,
                                () => setState(() => _mostrarReceitasAcumulado = !_mostrarReceitasAcumulado)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Toque nas legendas para mostrar/ocultar • Mês atual destacado',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: 24),

          // ── RECEITAS POR CATEGORIA ────────────────────────────────────
          const Text(
            'Receitas por Categoria',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: categorias.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Nenhuma receita no período',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        SizedBox(
                          height: 200,
                          child: PieChart(
                            PieChartData(
                              sections: categorias.asMap().entries.map((entry) {
                                final i = entry.key;
                                final cat = entry.value;
                                final valor = receitasPorCat[cat]!;
                                final pct = total > 0 ? valor / total * 100 : 0;
                                return PieChartSectionData(
                                  value: valor,
                                  color: _coresCategorias[i % _coresCategorias.length],
                                  title: '${pct.toStringAsFixed(1)}%',
                                  titleStyle: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  radius: 80,
                                );
                              }).toList(),
                              sectionsSpace: 2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: categorias.asMap().entries.map((entry) {
                            final i = entry.key;
                            final cat = entry.value;
                            return _legenda(
                              _coresCategorias[i % _coresCategorias.length],
                              cat,
                              _formatarValor(receitasPorCat[cat]!),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 24),

          // ── FIXA VS VARIÁVEL ──────────────────────────────────────────
          const Text(
            'Fixa vs Variável',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _totalFixasReceita == 0 && _totalVariaveisReceita == 0
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Nenhuma receita no período',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        SizedBox(
                          height: 180,
                          child: PieChart(
                            PieChartData(
                              sections: [
                                if (_totalFixasReceita > 0)
                                  PieChartSectionData(
                                    value: _totalFixasReceita,
                                    color: Colors.blue,
                                    title: total > 0
                                        ? '${(_totalFixasReceita / total * 100).toStringAsFixed(1)}%'
                                        : '',
                                    titleStyle: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    radius: 70,
                                  ),
                                if (_totalVariaveisReceita > 0)
                                  PieChartSectionData(
                                    value: _totalVariaveisReceita,
                                    color: Colors.teal,
                                    title: total > 0
                                        ? '${(_totalVariaveisReceita / total * 100).toStringAsFixed(1)}%'
                                        : '',
                                    titleStyle: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    radius: 70,
                                  ),
                              ],
                              sectionsSpace: 2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _legenda(Colors.blue, 'Fixa', _formatarValor(_totalFixasReceita)),
                            const SizedBox(width: 24),
                            _legenda(Colors.teal, 'Variável', _formatarValor(_totalVariaveisReceita)),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 24),

          // ── RECORRÊNCIA ───────────────────────────────────────────────
          const Text(
            'Recorrência',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _totalRecorrentesReceita == 0 && _totalNaoRecorrentesReceita == 0
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Nenhuma receita no período',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        SizedBox(
                          height: 180,
                          child: PieChart(
                            PieChartData(
                              sections: [
                                if (_totalRecorrentesReceita > 0)
                                  PieChartSectionData(
                                    value: _totalRecorrentesReceita,
                                    color: Colors.green,
                                    title: total > 0
                                        ? '${(_totalRecorrentesReceita / total * 100).toStringAsFixed(1)}%'
                                        : '',
                                    titleStyle: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    radius: 70,
                                  ),
                                if (_totalNaoRecorrentesReceita > 0)
                                  PieChartSectionData(
                                    value: _totalNaoRecorrentesReceita,
                                    color: Colors.orange,
                                    title: total > 0
                                        ? '${(_totalNaoRecorrentesReceita / total * 100).toStringAsFixed(1)}%'
                                        : '',
                                    titleStyle: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    radius: 70,
                                  ),
                              ],
                              sectionsSpace: 2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _legenda(Colors.green, 'Recorrente', _formatarValor(_totalRecorrentesReceita)),
                            const SizedBox(width: 24),
                            _legenda(Colors.orange, 'Não recorrente', _formatarValor(_totalNaoRecorrentesReceita)),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _cardResumo(
    String titulo,
    double valor,
    Color cor, {
    bool isCount = false,
  }) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                isCount ? valor.toInt().toString() : _formatarValor(valor),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: cor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legendaItem(Color cor, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
              color: cor, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _legenda(Color cor, String label, String valor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12)),
            if (valor.isNotEmpty)
              Text(
                valor,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
          ],
        ),
      ],
    );
  }
}
