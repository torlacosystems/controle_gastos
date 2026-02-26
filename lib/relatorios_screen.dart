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

class RelatoriosScreen extends StatefulWidget {
  const RelatoriosScreen({super.key});

  @override
  State<RelatoriosScreen> createState() => _RelatoriosScreenState();
}

class _RelatoriosScreenState extends State<RelatoriosScreen> {
  late Box<Gasto> _gastosBox;
  late Box<Receita> _receitasBox;

  DateTime _dataInicio = DateTime.now().subtract(const Duration(days: 30));
  DateTime _dataFim = DateTime.now();
  int _historicoMeses = 6;
  String _periodoSelecionado = '30d';

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

  List<Gasto> get _gastosFiltrados => _gastosBox.values
      .where(
        (g) =>
            g.data.isAfter(_dataInicio.subtract(const Duration(days: 1))) &&
            g.data.isBefore(_dataFim.add(const Duration(days: 1))),
      )
      .toList();

  List<Receita> get _receitasFiltradas => _receitasBox.values
      .where(
        (r) =>
            r.data.isAfter(_dataInicio.subtract(const Duration(days: 1))) &&
            r.data.isBefore(_dataFim.add(const Duration(days: 1))),
      )
      .toList();

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

  Map<String, double> get _gastosPorCategoria {
    final Map<String, double> mapa = {};
    for (final g in _gastosFiltrados) {
      mapa[g.categoria] = (mapa[g.categoria] ?? 0) + g.valor;
    }
    return mapa;
  }

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
      .where((g) => g.data.month == mes.month && g.data.year == mes.year)
      .fold(0, (s, g) => s + g.valor);

  double _receitasPorMes(DateTime mes) => _receitasBox.values
      .where((r) => r.data.month == mes.month && r.data.year == mes.year)
      .fold(0, (s, r) => s + r.valor);

  double _saldoPorMes(DateTime mes) {
    final s = _receitasPorMes(mes) - _gastosPorMes(mes);
    return s < 0 ? 0 : s;
  }

  // ── PDF ──────────────────────────────────────────────────────────────────

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

  // ── FIM PDF ──────────────────────────────────────────────────────────────

  final List<Color> _coresCategorias = [
    Colors.blue,
    Colors.red,
    Colors.orange,
    Colors.green,
    Colors.purple,
    Colors.teal,
    Colors.pink,
  ];

  @override
  Widget build(BuildContext context) {
    final gastosPorCat = _gastosPorCategoria;
    final categorias = gastosPorCat.keys.toList();
    final mesesHistorico = _gerarMesesHistorico();
    final agora = DateTime.now();

    double maxY = 0;
    for (final mes in mesesHistorico) {
      final g = _gastosPorMes(mes);
      final r = _receitasPorMes(mes);
      final s = _saldoPorMes(mes);
      if (g > maxY) maxY = g;
      if (r > maxY) maxY = r;
      if (s > maxY) maxY = s;
    }
    maxY = maxY == 0 ? 100 : maxY * 1.2;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatórios'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // FILTRO DE PERÍODO
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
                        final selecionado = _periodoSelecionado == p['key'];
                        return GestureDetector(
                          onTap: () => _aplicarPeriodo(p['key']!),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: selecionado
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey[200],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              p['label']!,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: selecionado
                                    ? Colors.white
                                    : Colors.grey[700],
                              ),
                            ),
                          ),
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
            const SizedBox(height: 16),

            // CARDS DE RESUMO
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

            // HISTÓRICO MENSAL
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Histórico Mensal',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [3, 6, 12].map((meses) {
                    final selecionado = _historicoMeses == meses;
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
                            color: selecionado
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '${meses}m',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: selecionado
                                  ? Colors.white
                                  : Colors.grey[700],
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
                          maxY: maxY,
                          lineBarsData: [
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
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _legenda(Colors.red, 'Gastos', ''),
                        const SizedBox(width: 16),
                        _legenda(Colors.green, 'Receitas', ''),
                        const SizedBox(width: 16),
                        _legenda(Colors.blue, 'Saldo', ''),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Mês atual destacado',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // GRÁFICO GASTOS ESPERADOS VS INESPERADOS
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

            // GRÁFICO GASTOS POR CATEGORIA
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
