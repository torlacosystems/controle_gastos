import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'gasto.dart';
import 'receita.dart';
import 'forma_pagamento.dart';
import 'pessoa.dart';
import 'orcamento.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  late Box<Gasto> _gastosBox;
  late Box<Receita> _receitasBox;
  late Box<FormaPagamento> _formasPagamentoBox;
  late Box<Pessoa> _pessoasBox;
  late Box<Orcamento> _orcamentosBox;

  bool _processando = false;

  @override
  void initState() {
    super.initState();
    _gastosBox = Hive.box<Gasto>('gastos');
    _receitasBox = Hive.box<Receita>('receitas');
    _formasPagamentoBox = Hive.box<FormaPagamento>('formas_pagamento');
    _pessoasBox = Hive.box<Pessoa>('pessoas');
    _orcamentosBox = Hive.box<Orcamento>('orcamentos');
  }

  // ── BACKUP ────────────────────────────────────────────────────────────────

  Map<String, dynamic> _exportarDados() {
    return {
      'versao': 1,
      'exportado_em': DateTime.now().toIso8601String(),
      'gastos': _gastosBox.values
          .map(
            (g) => {
              'id': g.id,
              'descricao': g.descricao,
              'valor': g.valor,
              'categoria': g.categoria,
              'data': g.data.toIso8601String(),
              'formaPagamento': g.formaPagamento,
              'pessoa': g.pessoa,
              'tipoGasto': g.tipoGasto,
              'parcelado': g.parcelado,
              'numeroParcelas': g.numeroParcelas,
              'estabelecimento': g.estabelecimento,
              'recorrente': g.recorrente,
              'gastoEsperado': g.gastoEsperado,
            },
          )
          .toList(),
      'receitas': _receitasBox.values
          .map(
            (r) => {
              'id': r.id,
              'descricao': r.descricao,
              'valor': r.valor,
              'categoria': r.categoria,
              'data': r.data.toIso8601String(),
              'pessoa': r.pessoa,
              'recorrente': r.recorrente,
              'tipoReceita': r.tipoReceita,
            },
          )
          .toList(),
      'formas_pagamento': _formasPagamentoBox.values
          .map(
            (f) => {
              'id': f.id,
              'descricao': f.descricao,
              'tipo': f.tipo,
              'banco': f.banco,
            },
          )
          .toList(),
      'pessoas': _pessoasBox.values
          .map((p) => {'id': p.id, 'nome': p.nome, 'parentesco': p.parentesco})
          .toList(),
      'orcamentos': _orcamentosBox.values
          .map(
            (o) => {'id': o.id, 'categoria': o.categoria, 'limite': o.limite},
          )
          .toList(),
    };
  }

  Future<void> _fazerBackup() async {
    setState(() => _processando = true);
    try {
      final dados = _exportarDados();
      final json = const JsonEncoder.withIndent('  ').convert(dados);

      final dir = await getApplicationDocumentsDirectory();
      final agora = DateTime.now();
      final nomeArquivo =
          'backup_gastos_${agora.year}${agora.month.toString().padLeft(2, '0')}${agora.day.toString().padLeft(2, '0')}_${agora.hour.toString().padLeft(2, '0')}${agora.minute.toString().padLeft(2, '0')}.json';
      final arquivo = File('${dir.path}/$nomeArquivo');
      await arquivo.writeAsString(json);

      await Share.shareXFiles(
        [XFile(arquivo.path)],
        subject: 'Backup Controle de Gastos',
        text: 'Backup dos dados do app Controle de Gastos.',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao fazer backup: $e')));
      }
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  // ── RESTORE ───────────────────────────────────────────────────────────────

  Future<void> _fazerRestore() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurar Backup'),
        content: const Text(
          'Todos os dados atuais serão substituídos pelos dados do backup.\n\nEsta ação não pode ser desfeita. Deseja continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _processando = true);
    try {
      final resultado = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (resultado == null || resultado.files.single.path == null) {
        setState(() => _processando = false);
        return;
      }

      final arquivo = File(resultado.files.single.path!);
      final conteudo = await arquivo.readAsString();
      final dados = jsonDecode(conteudo) as Map<String, dynamic>;

      // Valida versão
      if (!dados.containsKey('versao') || !dados.containsKey('gastos')) {
        throw Exception('Arquivo de backup inválido.');
      }

      // Limpa boxes
      await _gastosBox.clear();
      await _receitasBox.clear();
      await _formasPagamentoBox.clear();
      await _pessoasBox.clear();
      await _orcamentosBox.clear();

      // Restaura formas de pagamento
      for (final f in (dados['formas_pagamento'] as List)) {
        await _formasPagamentoBox.add(
          FormaPagamento(
            id: f['id'],
            descricao: f['descricao'],
            tipo: f['tipo'],
            banco: f['banco'],
          ),
        );
      }

      // Restaura pessoas
      for (final p in (dados['pessoas'] as List)) {
        await _pessoasBox.add(
          Pessoa(id: p['id'], nome: p['nome'], parentesco: p['parentesco']),
        );
      }

      // Restaura orçamentos
      for (final o in (dados['orcamentos'] as List)) {
        await _orcamentosBox.add(
          Orcamento(
            id: o['id'],
            categoria: o['categoria'],
            limite: (o['limite'] as num).toDouble(),
          ),
        );
      }

      // Restaura gastos
      for (final g in (dados['gastos'] as List)) {
        await _gastosBox.add(
          Gasto(
            id: g['id'],
            descricao: g['descricao'],
            valor: (g['valor'] as num).toDouble(),
            categoria: g['categoria'],
            data: DateTime.parse(g['data']),
            formaPagamento: g['formaPagamento'],
            pessoa: g['pessoa'],
            tipoGasto: g['tipoGasto'],
            parcelado: g['parcelado'] ?? false,
            numeroParcelas: g['numeroParcelas'] ?? 1,
            estabelecimento: g['estabelecimento'] ?? '',
            recorrente: g['recorrente'] ?? false,
            gastoEsperado: g['gastoEsperado'] ?? true,
          ),
        );
      }

      // Restaura receitas
      for (final r in (dados['receitas'] as List)) {
        await _receitasBox.add(
          Receita(
            id: r['id'],
            descricao: r['descricao'],
            valor: (r['valor'] as num).toDouble(),
            categoria: r['categoria'],
            data: DateTime.parse(r['data']),
            pessoa: r['pessoa'],
            recorrente: r['recorrente'] ?? false,
            tipoReceita: r['tipoReceita'] ?? 'Fixo',
          ),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Backup restaurado com sucesso!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao restaurar backup: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  int get _totalRegistros =>
      _gastosBox.length +
      _receitasBox.length +
      _formasPagamentoBox.length +
      _pessoasBox.length +
      _orcamentosBox.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup e Restore'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _processando
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Processando...', style: TextStyle(fontSize: 16)),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // RESUMO DOS DADOS
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Dados Atuais',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _linhaResumo(
                            Icons.money_off,
                            'Gastos',
                            _gastosBox.length,
                          ),
                          _linhaResumo(
                            Icons.attach_money,
                            'Receitas',
                            _receitasBox.length,
                          ),
                          _linhaResumo(
                            Icons.credit_card,
                            'Formas de Pagamento',
                            _formasPagamentoBox.length,
                          ),
                          _linhaResumo(
                            Icons.people,
                            'Pessoas',
                            _pessoasBox.length,
                          ),
                          _linhaResumo(
                            Icons.account_balance_wallet,
                            'Orçamentos',
                            _orcamentosBox.length,
                          ),
                          const Divider(),
                          _linhaResumo(
                            Icons.storage,
                            'Total de registros',
                            _totalRegistros,
                            negrito: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // BACKUP
                  const Text(
                    'Exportar Backup',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Gera um arquivo .json com todos os seus dados. Salve em um local seguro como Google Drive, WhatsApp ou e-mail.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _fazerBackup,
                      icon: const Icon(Icons.upload),
                      label: const Text(
                        'Fazer Backup',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // RESTORE
                  const Text(
                    'Importar Backup',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Selecione um arquivo .json gerado por este app. Atenção: os dados atuais serão substituídos.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _fazerRestore,
                      icon: const Icon(Icons.download),
                      label: const Text(
                        'Restaurar Backup',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // AVISO
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: Colors.amber, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Recomendamos fazer backup regularmente. O arquivo gerado é compatível apenas com este aplicativo.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _linhaResumo(
    IconData icone,
    String label,
    int quantidade, {
    bool negrito = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icone, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: negrito ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            '$quantidade',
            style: TextStyle(
              fontWeight: negrito ? FontWeight.bold : FontWeight.normal,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
