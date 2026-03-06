import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
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

class _RelatoriosScreenState extends State<RelatoriosScreen> {
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

  // Controle de linhas do gráfico
  bool _mostrarGastos = true;
  bool _mostrarReceitas = true;
  bool _mostrarSaldo = true;
  bool _mostrarAcumulado = false;

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
    _aplicarPeriodo('30d');
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

  // ── Helpers de filtro ─────────────────────────────────────────────────────

  List<String> get _todasPessoas =>
      _pessoasBox.values.map((p) => p.nome).toList();

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
      if (r.data.isBefore(_dataInicio.subtract(const Duration(days: 1))))
        return false;
      if (r.data.isAfter(_dataFim.add(const Duration(days: 1)))) return false;
      if (_pessoaSelecionada != null && r.pessoa != _pessoaSelecionada)
        return false;
      return true;
    }).toList();
  }

  double get _totalGastos => _gastosFiltrados.fold(0, (s, g) => s + g.valor);
  double get _totalReceitas =>
      _receitasFiltradas.fold(0, (s, r) => s + r.valor);
  double get _saldo => _totalReceitas - _totalGastos;

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
        if (_pessoaSelecionada != null && r.pessoa != _pessoaSelecionada)
          return false;
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

  double _gastoMesPorCategoria(String categoria) {
    final agora = DateTime.now();
    return _gastosBox.values
        .where(
          (g) =>
              g.categoria == categoria &&
              g.data.month == agora.month &&
              g.data.year == agora.year,
        )
        .fold(0, (s, g) => s + g.valor);
  }

  Color _corProgresso(double percentual) {
    if (percentual >= 1.0) return Colors.red;
    if (percentual >= 0.8) return Colors.orange;
    return Colors.green;
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

  Future<pw.Document> _gerarPdf() async {
    final doc = pw.Document();
    final periodoTexto = _periodoSelecionado == 'todos'
        ? 'Todos os registros'
        : '${_formatarData(_dataInicio)} ate ${_formatarData(_dataFim)}';
    final gastosPorCat = _gastosPorCategoria;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Text(
            'Relatorio Financeiro',
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
              _pdfCard('Receitas', _formatarValor(_totalReceitas)),
              pw.SizedBox(width: 8),
              _pdfCard('Saldo', _formatarValor(_saldo)),
              pw.SizedBox(width: 8),
              _pdfCard(
                'Transacoes',
                '${_gastosFiltrados.length + _receitasFiltradas.length}',
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
            pw.Table.fromTextArray(
              headers: ['Categoria', 'Total'],
              data: gastosPorCat.entries
                  .map((e) => [e.key, _formatarValor(e.value)])
                  .toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey200,
              ),
              border: pw.TableBorder.all(color: PdfColors.grey300),
              cellAlignment: pw.Alignment.centerLeft,
            ),
            pw.SizedBox(height: 20),
          ],
          pw.Text(
            'Gastos',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          _gastosFiltrados.isEmpty
              ? pw.Text(
                  'Nenhum gasto no periodo.',
                  style: const pw.TextStyle(color: PdfColors.grey),
                )
              : pw.Table.fromTextArray(
                  headers: ['Data', 'Categoria', 'Descricao', 'Valor'],
                  data: _gastosFiltrados
                      .map(
                        (g) => [
                          _formatarData(g.data),
                          g.categoria,
                          g.descricao.isEmpty ? '-' : g.descricao,
                          _formatarValor(g.valor),
                        ],
                      )
                      .toList(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.grey200,
                  ),
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  cellAlignment: pw.Alignment.centerLeft,
                ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Receitas',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          _receitasFiltradas.isEmpty
              ? pw.Text(
                  'Nenhuma receita no periodo.',
                  style: const pw.TextStyle(color: PdfColors.grey),
                )
              : pw.Table.fromTextArray(
                  headers: ['Data', 'Categoria', 'Descricao', 'Valor'],
                  data: _receitasFiltradas
                      .map(
                        (r) => [
                          _formatarData(r.data),
                          r.categoria,
                          r.descricao.isEmpty ? '-' : r.descricao,
                          _formatarValor(r.valor),
                        ],
                      )
                      .toList(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.grey200,
                  ),
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

  Future<void> _exportarPdf() async {
    try {
      final doc = await _gerarPdf();
      await Printing.sharePdf(
        bytes: await doc.save(),
        filename: 'relatorio_financeiro.pdf',
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao gerar PDF: $e')));
    }
  }

  Future<void> _enviarPdfEmail() async {
    try {
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
      } catch (_) {
        await Share.shareXFiles(
          [XFile(arquivo.path)],
          subject: 'Relatório Financeiro',
          text: 'Segue em anexo o relatório financeiro.',
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao enviar PDF: $e')));
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

  Widget _chipFiltro(String label, bool selecionado, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selecionado
              ? Theme.of(context).colorScheme.primary
              : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selecionado ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  Widget _linhaFiltroBoolean(
    String label,
    bool? valor,
    void Function(bool?) onChange,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(label, style: const TextStyle(fontSize: 13)),
        ),
        _chipFiltro('Todos', valor == null, () => onChange(null)),
        const SizedBox(width: 8),
        _chipFiltro('Sim', valor == true, () => onChange(valor == true ? null : true)),
        const SizedBox(width: 8),
        _chipFiltro('Não', valor == false, () => onChange(valor == false ? null : false)),
      ],
    );
  }

  Widget _toggleLinha(Color cor, String label, bool ativo, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
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
    final categorias = gastosPorCat.keys.toList();
    final mesesHistorico = _gerarMesesHistorico();
    final agora = DateTime.now();
    final orcamentos = _orcamentosBox.values.toList();
    final todasPessoas = _todasPessoas;
    final acumulados = _calcularAcumulado(mesesHistorico);

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
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Exportar PDF',
            onPressed: _exportarPdf,
          ),
          IconButton(
            icon: const Icon(Icons.email),
            tooltip: 'Enviar PDF por e-mail',
            onPressed: _enviarPdfEmail,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).padding.bottom + 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── FILTRO DE PERÍODO ──────────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Período',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _periodos.map((p) {
                        final sel = _periodoSelecionado == p['key'];
                        return _chipFiltro(
                          p['label']!,
                          sel,
                          () => _aplicarPeriodo(p['key']!),
                        );
                      }).toList(),
                    ),
                    if (_periodoSelecionado == 'Personalizado') ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: _selecionarDataInicio,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      size: 16,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _formatarData(_dataInicio),
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              'até',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: _selecionarDataFim,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      size: 16,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _formatarData(_dataFim),
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_periodoSelecionado != 'Personalizado' &&
                        _periodoSelecionado != 'todos') ...[
                      const SizedBox(height: 8),
                      Text(
                        '${_formatarData(_dataInicio)} até ${_formatarData(_dataFim)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── FILTRO POR PESSOA ──────────────────────────────────────────
            if (todasPessoas.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pessoa',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _chipFiltro(
                            'Todas',
                            _pessoaSelecionada == null,
                            () => setState(() => _pessoaSelecionada = null),
                          ),
                          ...todasPessoas.map(
                            (p) => _chipFiltro(
                              p,
                              _pessoaSelecionada == p,
                              () => setState(
                                () => _pessoaSelecionada =
                                    _pessoaSelecionada == p ? null : p,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ── FILTRO POR FORMA DE PAGAMENTO ──────────────────────────────
            if (_formasPagamentoBox.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Forma de Pagamento',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Nível 1 — tipo
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _chipFiltro(
                            'Todos',
                            _tipoFormaPagamento == null,
                            () => setState(() {
                              _tipoFormaPagamento = null;
                              _formaPagamentoSelecionada = null;
                            }),
                          ),
                          ...['Crédito', 'Débito', 'VA/VR']
                              .where(
                                (tipo) => _formasPagamentoBox.values.any(
                                  (f) => f.tipo == tipo,
                                ),
                              )
                              .map(
                                (tipo) => _chipFiltro(
                                  tipo,
                                  _tipoFormaPagamento == tipo,
                                  () => setState(() {
                                    _tipoFormaPagamento =
                                        _tipoFormaPagamento == tipo
                                        ? null
                                        : tipo;
                                    _formaPagamentoSelecionada = null;
                                  }),
                                ),
                              ),
                        ],
                      ),

                      // Nível 2 — forma específica
                      if (_tipoFormaPagamento != null) ...[
                        const SizedBox(height: 10),
                        const Divider(height: 1),
                        const SizedBox(height: 10),
                        Text(
                          'Cartão / Conta ($_tipoFormaPagamento)',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _chipFiltro(
                              'Todas',
                              _formaPagamentoSelecionada == null,
                              () => setState(
                                () => _formaPagamentoSelecionada = null,
                              ),
                            ),
                            ..._formasPagamentoBox.values
                                .where((f) => f.tipo == _tipoFormaPagamento)
                                .map(
                                  (f) => _chipFiltro(
                                    f.descricao,
                                    _formaPagamentoSelecionada == f.descricao,
                                    () => setState(
                                      () => _formaPagamentoSelecionada =
                                          _formaPagamentoSelecionada ==
                                              f.descricao
                                          ? null
                                          : f.descricao,
                                    ),
                                  ),
                                ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ── FILTRO POR CARACTERÍSTICAS ─────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Características',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _linhaFiltroBoolean(
                      'Esperado',
                      _filtroEsperado,
                      (v) => setState(() => _filtroEsperado = v),
                    ),
                    const SizedBox(height: 8),
                    _linhaFiltroBoolean(
                      'Evitável',
                      _filtroEvitavel,
                      (v) => setState(() => _filtroEvitavel = v),
                    ),
                    const SizedBox(height: 8),
                    _linhaFiltroBoolean(
                      'Fixo',
                      _filtroFixo,
                      (v) => setState(() => _filtroFixo = v),
                    ),
                    const SizedBox(height: 8),
                    _linhaFiltroBoolean(
                      'Recorrente',
                      _filtroRecorrente,
                      (v) => setState(() => _filtroRecorrente = v),
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
                _cardResumo('Receitas', _totalReceitas, Colors.green),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _cardResumo(
                  'Saldo',
                  _saldo,
                  _saldo >= 0 ? Colors.green : Colors.red,
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
                                  color: Colors.red.withOpacity(0.08),
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
                                  color: Colors.green.withOpacity(0.08),
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
                                  color: Colors.blue.withOpacity(0.05),
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
                                  color: Colors.purple.withOpacity(0.05),
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
            if (orcamentos.isNotEmpty) ...[
              const Text(
                'Orçamento por Categoria',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...orcamentos.map((orc) {
                final gasto = _gastoMesPorCategoria(orc.categoria);
                final percentual = orc.limite > 0 ? (gasto / orc.limite) : 0.0;
                final cor = _corProgresso(percentual);
                final ultrapassou = percentual >= 1.0;
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: ultrapassou
                        ? const BorderSide(color: Colors.red, width: 1.5)
                        : BorderSide.none,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                orc.categoria,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (ultrapassou)
                              const Icon(
                                Icons.warning_amber,
                                color: Colors.red,
                                size: 16,
                              ),
                            const SizedBox(width: 4),
                            Text(
                              '${(percentual * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: cor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: percentual.clamp(0.0, 1.0),
                            minHeight: 10,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(cor),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Gasto: ${_formatarValor(gasto)}',
                              style: TextStyle(fontSize: 12, color: cor),
                            ),
                            Text(
                              'Limite: ${_formatarValor(orc.limite)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        if (ultrapassou)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '⚠ Ultrapassado em ${_formatarValor(gasto - orc.limite)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 14),
            ],
          ],
        ),
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
