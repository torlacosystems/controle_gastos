import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'forma_pagamento.dart';
import 'pessoa.dart';
import 'orcamento.dart';
import 'currency_formatter.dart';
import 'gasto.dart';
import 'receita.dart';
import 'categoria.dart';
import 'subscription_service.dart';
import 'paywall_screen.dart';
import 'fade_route.dart';

class ConfiguracoesScreen extends StatefulWidget {
  const ConfiguracoesScreen({super.key});

  @override
  State<ConfiguracoesScreen> createState() => _ConfiguracoesScreenState();
}

class _ConfiguracoesScreenState extends State<ConfiguracoesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Box<FormaPagamento> _formasPagamentoBox;
  late Box<Pessoa> _pessoasBox;
  late Box<Orcamento> _orcamentosBox;
  late Box<Gasto> _gastosBox;
  late Box<Receita> _receitasBox;
  late Box<Categoria> _categoriasBox;

  final List<String> _grausParentesco = [
    'Eu Mesmo',
    'Cônjuge',
    'Filho(a)',
    'Pai',
    'Mãe',
    'Irmão(ã)',
    'Avô/Avó',
    'Neto(a)',
    'Tio(a)',
    'Sobrinho(a)',
    'Primo(a)',
    'Amigo(a)',
    'Outro',
  ];

  final List<Map<String, dynamic>> _categoriasGasto = [
    {'nome': 'Alimentação', 'icone': Icons.restaurant},
    {'nome': 'Mercado', 'icone': Icons.shopping_cart},
    {'nome': 'Transporte', 'icone': Icons.directions_bus},
    {'nome': 'Veículo', 'icone': Icons.directions_car},
    {'nome': 'Saúde', 'icone': Icons.health_and_safety},
    {'nome': 'Lazer', 'icone': Icons.movie},
    {'nome': 'Moradia', 'icone': Icons.home},
    {'nome': 'Educação', 'icone': Icons.school},
    {'nome': 'Assinaturas', 'icone': Icons.subscriptions},
    {'nome': 'Vestuário', 'icone': Icons.checkroom},
    {'nome': 'Cuidados Pessoais', 'icone': Icons.spa},
    {'nome': 'Presentes', 'icone': Icons.card_giftcard},
    {'nome': 'Outros', 'icone': Icons.category},
  ];

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _formasPagamentoBox = Hive.box<FormaPagamento>('formas_pagamento');
    _pessoasBox = Hive.box<Pessoa>('pessoas');
    _orcamentosBox = Hive.box<Orcamento>('orcamentos');
    _gastosBox = Hive.box<Gasto>('gastos');
    _receitasBox = Hive.box<Receita>('receitas');
    _categoriasBox = Hive.box<Categoria>('categorias');
  }

  void _mostrarSnackbarSucesso(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(mensagem),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Exclusão de Forma de Pagamento ────────────────────────────────────────

  Future<bool> _confirmarExclusaoForma(
    BuildContext context,
    FormaPagamento forma,
  ) async {
    final gastosVinculados = _gastosBox.values
        .where((g) => g.formaPagamento == forma.descricao)
        .length;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Forma de Pagamento'),
        content: Text(
          gastosVinculados > 0
              ? 'Existem $gastosVinculados gasto(s) vinculado(s) a "${forma.descricao}".\n\nDeseja excluir a forma de pagamento?'
              : 'Tem certeza que deseja excluir "${forma.descricao}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar != true) return false;

    if (gastosVinculados > 0) {
      final excluirRegistros = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Excluir registros vinculados?'),
          content: Text(
            'Deseja também excluir os $gastosVinculados gasto(s) cadastrado(s) com "${forma.descricao}"?\n\nSe não excluir, os gastos serão mantidos mas ficarão sem forma de pagamento válida.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Manter registros'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Excluir tudo'),
            ),
          ],
        ),
      );

      if (excluirRegistros == true) {
        final keysParaExcluir = _gastosBox.keys.where((k) {
          final g = _gastosBox.get(k);
          return g != null && g.formaPagamento == forma.descricao;
        }).toList();
        for (final k in keysParaExcluir) {
          await _gastosBox.delete(k);
        }
      }
    }

    return true;
  }

  // ── Exclusão de Pessoa ────────────────────────────────────────────────────

  Future<bool> _confirmarExclusaoPessoa(
    BuildContext context,
    Pessoa pessoa,
  ) async {
    final gastosVinculados = _gastosBox.values
        .where((g) => g.pessoa == pessoa.nome)
        .length;
    final receitasVinculadas = _receitasBox.values
        .where((r) => r.pessoa == pessoa.nome)
        .length;
    final totalVinculados = gastosVinculados + receitasVinculadas;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Pessoa'),
        content: Text(
          totalVinculados > 0
              ? 'Existem $gastosVinculados gasto(s) e $receitasVinculadas receita(s) vinculados a "${pessoa.nome}".\n\nDeseja excluir a pessoa?'
              : 'Tem certeza que deseja excluir "${pessoa.nome}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar != true) return false;

    if (totalVinculados > 0) {
      final partes = <String>[];
      if (gastosVinculados > 0) partes.add('$gastosVinculados gasto(s)');
      if (receitasVinculadas > 0) partes.add('$receitasVinculadas receita(s)');
      final descricao = partes.join(' e ');

      final excluirRegistros = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Excluir registros vinculados?'),
          content: Text(
            'Deseja também excluir $descricao cadastrado(s) para "${pessoa.nome}"?\n\nSe não excluir, os registros serão mantidos.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Manter registros'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Excluir tudo'),
            ),
          ],
        ),
      );

      if (excluirRegistros == true) {
        final gastosKeys = _gastosBox.keys.where((k) {
          final g = _gastosBox.get(k);
          return g != null && g.pessoa == pessoa.nome;
        }).toList();
        for (final k in gastosKeys) {
          await _gastosBox.delete(k);
        }

        final receitasKeys = _receitasBox.keys.where((k) {
          final r = _receitasBox.get(k);
          return r != null && r.pessoa == pessoa.nome;
        }).toList();
        for (final k in receitasKeys) {
          await _receitasBox.delete(k);
        }
      }
    }

    return true;
  }


  // ── Modal Forma de Pagamento ──────────────────────────────────────────────

  void _adicionarOuEditarFormaPagamento({FormaPagamento? forma, int? index}) {
    final descricaoController = TextEditingController(
      text: forma?.descricao ?? '',
    );
    final bancoController = TextEditingController(text: forma?.banco ?? '');
    String tipoSelecionado = forma?.tipo ?? 'Crédito';
    final isEdicao = forma != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom:
                MediaQuery.of(context).viewInsets.bottom +
                MediaQuery.of(context).padding.bottom +
                24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEdicao
                    ? 'Editar Forma de Pagamento'
                    : 'Nova Forma de Pagamento',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descricaoController,
                decoration: const InputDecoration(
                  labelText: 'Descrição',
                  hintText: 'Ex: Nubank Principal',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Tipo', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: ['Crédito', 'Débito', 'VA/VR'].map((tipo) {
                  final selecionado = tipo == tipoSelecionado;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setModalState(() => tipoSelecionado = tipo),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: selecionado
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          tipo,
                          style: TextStyle(
                            color: selecionado
                                ? Colors.white
                                : Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: bancoController,
                decoration: const InputDecoration(
                  labelText: 'Banco',
                  hintText: 'Ex: Nubank',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    final descricao = descricaoController.text.trim();
                    final banco = bancoController.text.trim();
                    if (descricao.isEmpty || banco.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Preencha todos os campos'),
                        ),
                      );
                      return;
                    }
                    final duplicada = _formasPagamentoBox.values
                        .toList()
                        .asMap()
                        .entries
                        .any((e) {
                          if (index != null && e.key == index) return false;
                          return e.value.descricao.trim().toLowerCase() ==
                                  descricao.toLowerCase() &&
                              e.value.tipo == tipoSelecionado &&
                              e.value.banco.trim().toLowerCase() ==
                                  banco.toLowerCase();
                        });
                    if (duplicada) {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Cadastro duplicado'),
                          content: const Text(
                            'Já existe uma forma de pagamento com esses dados.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                      return;
                    }
                    final novaForma = FormaPagamento(
                      id:
                          forma?.id ??
                          DateTime.now().millisecondsSinceEpoch.toString(),
                      descricao: descricao,
                      tipo: tipoSelecionado,
                      banco: banco,
                    );
                    if (forma == null) {
                      await _formasPagamentoBox.add(novaForma);
                    } else {
                      await _formasPagamentoBox.putAt(index!, novaForma);
                    }
                    setState(() {});
                    Navigator.pop(context);
                    _mostrarSnackbarSucesso(
                      isEdicao
                          ? 'Forma de pagamento atualizada com sucesso!'
                          : 'Forma de pagamento salva com sucesso!',
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    isEdicao ? 'Atualizar' : 'Salvar',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  // ── Editar nome do usuário principal ─────────────────────────────────────

  void _editarNomePrincipal(Pessoa pessoa) {
    final nomeController = TextEditingController(text: pessoa.nome);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom +
              MediaQuery.of(context).padding.bottom +
              24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Editar meu nome',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nomeController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nome',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () async {
                  final nome = nomeController.text.trim();
                  if (nome.isEmpty) return;
                  final atualizada = Pessoa(
                    id: 'usuario_principal',
                    nome: nome,
                    parentesco: 'Eu Mesmo',
                  );
                  await _pessoasBox.put('usuario_principal', atualizada);
                  if (!context.mounted) return;
                  setState(() {});
                  Navigator.pop(context);
                  _mostrarSnackbarSucesso('Nome atualizado com sucesso!');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Salvar',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Modal Pessoa ──────────────────────────────────────────────────────────

  void _adicionarOuEditarPessoa({Pessoa? pessoa, int? index}) {
    final nomeController = TextEditingController(text: pessoa?.nome ?? '');
    // "Eu Mesmo" é reservado ao usuário principal; não aparece ao cadastrar família
    final grausDisponiveis = _grausParentesco
        .where((g) => g != 'Eu Mesmo')
        .toList();
    String parentescoSelecionado = pessoa?.parentesco ?? grausDisponiveis.first;
    if (!grausDisponiveis.contains(parentescoSelecionado)) {
      parentescoSelecionado = 'Outro';
    }
    final isEdicao = pessoa != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom:
                MediaQuery.of(context).viewInsets.bottom +
                MediaQuery.of(context).padding.bottom +
                24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEdicao ? 'Editar Pessoa' : 'Nova Pessoa',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  hintText: 'Ex: Maria',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Grau de Parentesco',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: parentescoSelecionado,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: grausDisponiveis
                    .map(
                      (grau) =>
                          DropdownMenuItem(value: grau, child: Text(grau)),
                    )
                    .toList(),
                onChanged: (value) =>
                    setModalState(() => parentescoSelecionado = value!),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    final nome = nomeController.text.trim();
                    if (nome.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Preencha o nome')),
                      );
                      return;
                    }
                    final duplicada = _pessoasBox.values
                        .toList()
                        .asMap()
                        .entries
                        .any((e) {
                          if (index != null && e.key == index) return false;
                          return e.value.nome.trim().toLowerCase() ==
                                  nome.toLowerCase() &&
                              e.value.parentesco == parentescoSelecionado;
                        });
                    if (duplicada) {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Cadastro duplicado'),
                          content: const Text(
                            'Já existe uma pessoa com esse nome e parentesco.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                      return;
                    }
                    final novaPessoa = Pessoa(
                      id:
                          pessoa?.id ??
                          DateTime.now().millisecondsSinceEpoch.toString(),
                      nome: nome,
                      parentesco: parentescoSelecionado,
                    );
                    if (pessoa == null) {
                      await _pessoasBox.add(novaPessoa);
                    } else {
                      await _pessoasBox.putAt(index!, novaPessoa);
                    }
                    setState(() {});
                    Navigator.pop(context);
                    _mostrarSnackbarSucesso(
                      isEdicao
                          ? 'Pessoa atualizada com sucesso!'
                          : 'Pessoa salva com sucesso!',
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    isEdicao ? 'Atualizar' : 'Salvar',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Editar limite de categoria fixa ──────────────────────────────────────

  void _editarLimiteCategoriaFixa(String nomeCategoria, IconData icone) {
    final orcIdx = _orcamentosBox.values.toList().indexWhere(
      (o) => o.categoria == nomeCategoria,
    );
    final orcExistente = orcIdx >= 0 ? _orcamentosBox.getAt(orcIdx) : null;
    final limiteController = TextEditingController(
      text: orcExistente != null
          ? formatarValorParaCampo(orcExistente.limite)
          : '',
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom:
              MediaQuery.of(context).viewInsets.bottom +
              MediaQuery.of(context).padding.bottom +
              24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  child: Icon(
                    icone,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  nomeCategoria,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Limite mensal (R\$)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: limiteController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [CurrencyInputFormatter()],
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '0,00 (deixe vazio para sem limite)',
                border: OutlineInputBorder(),
                prefixText: 'R\$ ',
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () async {
                  final texto = limiteController.text
                      .replaceAll('.', '')
                      .replaceAll(',', '.');
                  final limite = double.tryParse(texto) ?? 0.0;
                  if (limite > 0) {
                    final novoOrcamento = Orcamento(
                      id:
                          orcExistente?.id ??
                          DateTime.now().millisecondsSinceEpoch.toString(),
                      categoria: nomeCategoria,
                      limite: limite,
                    );
                    if (orcIdx >= 0) {
                      await _orcamentosBox.putAt(orcIdx, novoOrcamento);
                    } else {
                      await _orcamentosBox.add(novoOrcamento);
                    }
                  } else {
                    if (orcIdx >= 0) await _orcamentosBox.deleteAt(orcIdx);
                  }
                  setState(() {});
                  Navigator.pop(context);
                  _mostrarSnackbarSucesso(
                    'Limite de "$nomeCategoria" atualizado!',
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Salvar',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Exclusão de Categoria Personalizada ──────────────────────────────────

  Future<bool> _confirmarExclusaoCategoria(
    BuildContext context,
    Categoria cat,
    int index,
  ) async {
    final gastosVinculados = _gastosBox.values
        .where((g) => g.categoria == cat.nome)
        .length;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Categoria'),
        content: Text(
          gastosVinculados > 0
              ? 'Existem $gastosVinculados gasto(s) vinculado(s) à categoria "${cat.nome}".\n\nDeseja excluir a categoria?'
              : 'Tem certeza que deseja excluir a categoria "${cat.nome}"? O orçamento vinculado também será removido.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmar != true) return false;
    if (gastosVinculados > 0) {
      final excluirRegistros = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Excluir registros vinculados?'),
          content: Text(
            'Deseja também excluir os $gastosVinculados gasto(s) cadastrado(s) na categoria "${cat.nome}"?\n\nSe não excluir, os registros ficarão como "Sem Categoria".',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Manter registros'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Excluir tudo'),
            ),
          ],
        ),
      );
      if (excluirRegistros == true) {
        final keys = _gastosBox.keys.where((k) {
          final g = _gastosBox.get(k);
          return g != null && g.categoria == cat.nome;
        }).toList();
        for (final k in keys) await _gastosBox.delete(k);
      } else {
        final keys = _gastosBox.keys.where((k) {
          final g = _gastosBox.get(k);
          return g != null && g.categoria == cat.nome;
        }).toList();
        for (final k in keys) {
          final g = _gastosBox.get(k)!;
          await _gastosBox.put(
            k,
            Gasto(
              id: g.id,
              descricao: g.descricao,
              valor: g.valor,
              categoria: 'Sem Categoria',
              data: g.data,
              formaPagamento: g.formaPagamento,
              pessoa: g.pessoa,
              tipoGasto: g.tipoGasto,
              parcelado: g.parcelado,
              numeroParcelas: g.numeroParcelas,
              estabelecimento: g.estabelecimento,
              recorrente: g.recorrente,
              gastoEsperado: g.gastoEsperado,
              grupoId: g.grupoId,
              numeroParcela: g.numeroParcela,
            ),
          );
        }
      }
    }
    final orcIdx = _orcamentosBox.values.toList().indexWhere(
      (o) => o.categoria == cat.nome,
    );
    if (orcIdx >= 0) await _orcamentosBox.deleteAt(orcIdx);
    await _categoriasBox.deleteAt(index);
    setState(() {});
    return false;
  }

  void _editarLimiteCategoria(Categoria cat, int index) {
    final limiteController = TextEditingController(
      text: cat.limiteMensal > 0
          ? formatarValorParaCampo(cat.limiteMensal)
          : '',
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom:
              MediaQuery.of(context).viewInsets.bottom +
              MediaQuery.of(context).padding.bottom +
              24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  child: Icon(
                    cat.icone,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  cat.nome,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Limite mensal (R\$)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: limiteController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [CurrencyInputFormatter()],
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '0,00 (deixe vazio para sem limite)',
                border: OutlineInputBorder(),
                prefixText: 'R\$ ',
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () async {
                  final texto = limiteController.text
                      .replaceAll('.', '')
                      .replaceAll(',', '.');
                  final limite = double.tryParse(texto) ?? 0.0;
                  final categoriaAtualizada = Categoria(
                    id: cat.id,
                    nome: cat.nome,
                    iconeCodePoint: cat.iconeCodePoint,
                    iconeFontFamily: cat.iconeFontFamily,
                    limiteMensal: limite,
                  );
                  await _categoriasBox.putAt(index, categoriaAtualizada);
                  final orcIdx = _orcamentosBox.values.toList().indexWhere(
                    (o) => o.categoria == cat.nome,
                  );
                  if (limite > 0) {
                    final novoOrcamento = Orcamento(
                      id: cat.id,
                      categoria: cat.nome,
                      limite: limite,
                    );
                    if (orcIdx >= 0) {
                      await _orcamentosBox.putAt(orcIdx, novoOrcamento);
                    } else {
                      await _orcamentosBox.add(novoOrcamento);
                    }
                  } else {
                    if (orcIdx >= 0) await _orcamentosBox.deleteAt(orcIdx);
                  }
                  setState(() {});
                  Navigator.pop(context);
                  _mostrarSnackbarSucesso(
                    'Limite de "${cat.nome}" atualizado!',
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Salvar',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Grid de ícones para categoria personalizada ───────────────────────────

  static const List<Map<String, dynamic>> _iconesDisponiveis = [
    {'icone': Icons.restaurant, 'label': 'Alimentação'},
    {'icone': Icons.shopping_bag, 'label': 'Compras'},
    {'icone': Icons.sports_soccer, 'label': 'Esportes'},
    {'icone': Icons.pets, 'label': 'Pets'},
    {'icone': Icons.music_note, 'label': 'Música'},
    {'icone': Icons.flight, 'label': 'Viagem'},
    {'icone': Icons.wifi, 'label': 'Internet'},
    {'icone': Icons.phone_android, 'label': 'Celular'},
    {'icone': Icons.checkroom, 'label': 'Vestuário'},
    {'icone': Icons.local_gas_station, 'label': 'Combustível'},
    {'icone': Icons.child_care, 'label': 'Filhos'},
    {'icone': Icons.casino, 'label': 'Lazer extra'},
    {'icone': Icons.science, 'label': 'Tecnologia'},
    {'icone': Icons.spa, 'label': 'Beleza'},
    {'icone': Icons.volunteer_activism, 'label': 'Doação'},
    {'icone': Icons.fastfood, 'label': 'Fast food'},
    {'icone': Icons.local_cafe, 'label': 'Café'},
    {'icone': Icons.cake, 'label': 'Festas'},
    {'icone': Icons.build, 'label': 'Manutenção'},
    {'icone': Icons.attach_money, 'label': 'Finanças'},
    {'icone': Icons.local_hospital, 'label': 'Hospital'},
    {'icone': Icons.directions_bike, 'label': 'Bike'},
    {'icone': Icons.videogame_asset, 'label': 'Games'},
    {'icone': Icons.book, 'label': 'Livros'},
  ];

  void _adicionarNovaCategoria() {
    final nomeController = TextEditingController();
    final limiteController = TextEditingController();
    IconData iconeSelecionado = Icons.category;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom:
                MediaQuery.of(context).viewInsets.bottom +
                MediaQuery.of(context).padding.bottom +
                24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nova Categoria',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nomeController,
                  decoration: const InputDecoration(
                    labelText: 'Nome da categoria',
                    hintText: 'Ex: Pets',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Limite mensal (R\$)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: limiteController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [CurrencyInputFormatter()],
                  decoration: const InputDecoration(
                    hintText: '0,00',
                    border: OutlineInputBorder(),
                    prefixText: 'R\$ ',
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Ícone',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: _iconesDisponiveis.length,
                  itemBuilder: (context, i) {
                    final icone = _iconesDisponiveis[i]['icone'] as IconData;
                    final selecionado = icone == iconeSelecionado;
                    return GestureDetector(
                      onTap: () =>
                          setModalState(() => iconeSelecionado = icone),
                      child: Container(
                        decoration: BoxDecoration(
                          color: selecionado
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selecionado
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey[300]!,
                          ),
                        ),
                        child: Icon(
                          icone,
                          size: 22,
                          color: selecionado ? Colors.white : Colors.grey[700],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () async {
                      final nome = nomeController.text.trim();
                      if (nome.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Informe o nome da categoria'),
                          ),
                        );
                        return;
                      }
                      final texto = limiteController.text
                          .replaceAll('.', '')
                          .replaceAll(',', '.');
                      final limite = double.tryParse(texto) ?? 0.0;
                      final categoriasFixas = [
                        'Alimentação',
                        'Mercado',
                        'Transporte',
                        'Saúde',
                        'Lazer',
                        'Moradia',
                        'Educação',
                        'Assinaturas',
                        'Vestuário',
                        'Cuidados Pessoais',
                        'Presentes',
                        'Outros',
                      ];
                      final nomeExiste =
                          categoriasFixas.any(
                            (c) => c.toLowerCase() == nome.toLowerCase(),
                          ) ||
                          _categoriasBox.values.any(
                            (c) => c.nome.toLowerCase() == nome.toLowerCase(),
                          );
                      if (nomeExiste) {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Categoria duplicada'),
                            content: Text(
                              'Já existe uma categoria chamada "$nome".',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );
                        return;
                      }
                      final id = DateTime.now().millisecondsSinceEpoch
                          .toString();
                      final novaCategoria = Categoria(
                        id: id,
                        nome: nome,
                        iconeCodePoint: iconeSelecionado.codePoint,
                        iconeFontFamily:
                            iconeSelecionado.fontFamily ?? 'MaterialIcons',
                        limiteMensal: limite,
                      );
                      await _categoriasBox.add(novaCategoria);
                      if (limite > 0) {
                        final novoOrcamento = Orcamento(
                          id: id,
                          categoria: nome,
                          limite: limite,
                        );
                        await _orcamentosBox.add(novoOrcamento);
                      }
                      setState(() {});
                      Navigator.pop(context);
                      _mostrarSnackbarSucesso(
                        'Categoria "$nome" criada com sucesso!',
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Salvar Categoria',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatarValor(double valor) {
    final p = valor.toStringAsFixed(2).split('.');
    return 'R\$ ${p[0].replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')},${p[1]}';
  }

  @override
  Widget build(BuildContext context) {
    final formas = _formasPagamentoBox.values.toList();
    final pessoasPrincipal = _pessoasBox.values
        .where((p) => p.id == 'usuario_principal')
        .toList();
    final pessoasFamilia = _pessoasBox.values
        .where((p) => p.id != 'usuario_principal')
        .toList();
    final pessoas = [...pessoasPrincipal, ...pessoasFamilia];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastro Inicial'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.credit_card), text: 'Pagamentos'),
            Tab(icon: Icon(Icons.people), text: 'Pessoas'),
            Tab(icon: Icon(Icons.account_balance_wallet), text: 'Orçamentos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── ABA FORMAS DE PAGAMENTO ────────────────────────────────────
          formas.isEmpty
              ? const Center(
                  child: Text(
                    'Nenhuma forma de pagamento.\nToque em + para adicionar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom,
                  ),
                  itemCount: formas.length,
                  itemBuilder: (context, index) {
                    final forma = formas[index];
                    return Dismissible(
                      key: Key(forma.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Colors.red,
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (_) async {
                        final confirmar = await _confirmarExclusaoForma(
                          context,
                          forma,
                        );
                        if (!confirmar) return false;
                        await _formasPagamentoBox.deleteAt(index);
                        setState(() {});
                        return false;
                      },
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                          child: Icon(
                            Icons.credit_card,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        title: Text(
                          forma.descricao,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('${forma.tipo} • ${forma.banco}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _adicionarOuEditarFormaPagamento(
                            forma: forma,
                            index: index,
                          ),
                        ),
                      ),
                    );
                  },
                ),

          // ── ABA PESSOAS ────────────────────────────────────────────────
          Column(
            children: [
              Expanded(
                child: pessoasFamilia.isEmpty && pessoasPrincipal.isEmpty
              ? const Center(
                  child: Text(
                    'Nenhuma pessoa cadastrada.\nToque em + para adicionar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom,
                  ),
                  itemCount: pessoas.length,
                  itemBuilder: (context, index) {
                    final pessoa = pessoas[index];
                    final isPrincipal = pessoa.id == 'usuario_principal';

                    if (isPrincipal) {
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          pessoa.nome,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(pessoa.parentesco),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _editarNomePrincipal(pessoa),
                        ),
                      );
                    }

                    final idxReal = _pessoasBox.values
                        .toList()
                        .indexWhere((p) => p.id == pessoa.id);
                    return Dismissible(
                      key: Key(pessoa.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Colors.red,
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (_) async {
                        final confirmar = await _confirmarExclusaoPessoa(
                          context,
                          pessoa,
                        );
                        if (!confirmar) return false;
                        if (idxReal >= 0) await _pessoasBox.deleteAt(idxReal);
                        setState(() {});
                        return false;
                      },
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                          child: Icon(
                            Icons.person,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        title: Text(
                          pessoa.nome,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(pessoa.parentesco),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _adicionarOuEditarPessoa(
                            pessoa: pessoa,
                            index: idxReal,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          // ── ABA ORÇAMENTOS ─────────────────────────────────────────────
          Builder(
            builder: (context) {
              final categoriasPersonalizadas = _categoriasBox.values.toList();
              final limitePorCategoria = <String, double>{};
              for (final orc in _orcamentosBox.values) {
                limitePorCategoria[orc.categoria] = orc.limite;
              }
              final fixasSemOutros = _categoriasGasto
                  .where((c) => c['nome'] != 'Outros')
                  .toList();
              final outros = _categoriasGasto
                  .where((c) => c['nome'] == 'Outros')
                  .toList();
              final todasCategorias = [
                ...fixasSemOutros.map(
                  (cat) => _CategoriaItem(
                    nome: cat['nome'] as String,
                    icone: cat['icone'] as IconData,
                    isPersonalizada: false,
                    catObj: null,
                    catIndex: -1,
                  ),
                ),
                ...categoriasPersonalizadas.asMap().entries.map(
                  (e) => _CategoriaItem(
                    nome: e.value.nome,
                    icone: e.value.icone,
                    isPersonalizada: true,
                    catObj: e.value,
                    catIndex: e.key,
                  ),
                ),
                ...outros.map(
                  (cat) => _CategoriaItem(
                    nome: cat['nome'] as String,
                    icone: cat['icone'] as IconData,
                    isPersonalizada: false,
                    catObj: null,
                    catIndex: -1,
                  ),
                ),
              ];

              Widget buildCard(_CategoriaItem item) {
                final limite =
                    limitePorCategoria[item.nome] ??
                    (item.catObj != null && item.catObj!.limiteMensal > 0
                        ? item.catObj!.limiteMensal
                        : null);
                final card = Card(
                  margin: const EdgeInsets.all(4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => item.isPersonalizada
                        ? _editarLimiteCategoria(item.catObj!, item.catIndex)
                        : _editarLimiteCategoriaFixa(item.nome, item.icone),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            child: Icon(
                              item.icone,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  item.nome,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  limite != null
                                      ? _formatarValor(limite)
                                      : 'Sem limite',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.edit, size: 14, color: Colors.grey[400]),
                        ],
                      ),
                    ),
                  ),
                );
                if (item.isPersonalizada) {
                  return Dismissible(
                    key: Key('cat_\${item.catObj!.id}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.delete,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    confirmDismiss: (_) => _confirmarExclusaoCategoria(
                      context,
                      item.catObj!,
                      item.catIndex,
                    ),
                    onDismissed: (_) {},
                    child: card,
                  );
                }
                return card;
              }

              final rows = <Widget>[];
              for (int i = 0; i < todasCategorias.length; i += 2) {
                final left = todasCategorias[i];
                final right = i + 1 < todasCategorias.length
                    ? todasCategorias[i + 1]
                    : null;
                rows.add(
                  Row(
                    children: [
                      Expanded(child: buildCard(left)),
                      right != null
                          ? Expanded(child: buildCard(right))
                          : const Expanded(child: SizedBox()),
                    ],
                  ),
                );
              }
              return ListView(
                padding: EdgeInsets.only(
                  left: 8,
                  right: 8,
                  top: 8,
                  bottom: MediaQuery.of(context).padding.bottom + 80,
                ),
                children: rows,
              );
            },
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 2
          ? FloatingActionButton.extended(
              heroTag: 'nova_categoria',
              onPressed: () {
                if (!SubscriptionService.instance.isPremium) {
                  Navigator.push(
                    context,
                    FadeRoute(page: const PaywallScreen()),
                  );
                  return;
                }
                _adicionarNovaCategoria();
              },
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Nova Categoria'),
              backgroundColor: Theme.of(context).colorScheme.secondary,
              foregroundColor: Colors.white,
            )
          : FloatingActionButton(
              onPressed: () {
                if (_tabController.index == 0) {
                  _adicionarOuEditarFormaPagamento();
                } else {
                  // Tab Pessoas: bloqueia adição se free e já existe 1 pessoa
                  if (!SubscriptionService.instance.isPremium &&
                      _pessoasBox.isNotEmpty) {
                    Navigator.push(
                      context,
                      FadeRoute(page: const PaywallScreen()),
                    );
                    return;
                  }
                  _adicionarOuEditarPessoa();
                }
              },
              child: const Icon(Icons.add),
            ),
    );
  }
}

class _CategoriaItem {
  final String nome;
  final IconData icone;
  final bool isPersonalizada;
  final Categoria? catObj;
  final int catIndex;

  _CategoriaItem({
    required this.nome,
    required this.icone,
    required this.isPersonalizada,
    required this.catObj,
    required this.catIndex,
  });
}
