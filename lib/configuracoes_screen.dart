import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'forma_pagamento.dart';
import 'pessoa.dart';
import 'orcamento.dart';

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
    {'nome': 'Transporte', 'icone': Icons.directions_car},
    {'nome': 'Saúde', 'icone': Icons.health_and_safety},
    {'nome': 'Lazer', 'icone': Icons.movie},
    {'nome': 'Moradia', 'icone': Icons.home},
    {'nome': 'Educação', 'icone': Icons.school},
    {'nome': 'Outros', 'icone': Icons.category},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _formasPagamentoBox = Hive.box<FormaPagamento>('formas_pagamento');
    _pessoasBox = Hive.box<Pessoa>('pessoas');
    _orcamentosBox = Hive.box<Orcamento>('orcamentos');
  }

  void _adicionarOuEditarOrcamento({Orcamento? orcamento, int? index}) {
    String categoriaSelecionada =
        orcamento?.categoria ?? _categoriasGasto.first['nome'];
    final limiteController = TextEditingController(
      text: orcamento != null
          ? orcamento.limite.toStringAsFixed(2).replaceAll('.', ',')
          : '',
    );

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
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                orcamento == null ? 'Novo Orçamento' : 'Editar Orçamento',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Categoria',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: categoriaSelecionada,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: _categoriasGasto.map((cat) {
                  return DropdownMenuItem<String>(
                    value: cat['nome'] as String,
                    child: Row(
                      children: [
                        Icon(
                          cat['icone'] as IconData,
                          size: 18,
                          color: Colors.grey[700],
                        ),
                        const SizedBox(width: 8),
                        Text(cat['nome'] as String),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (v) =>
                    setModalState(() => categoriaSelecionada = v!),
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
                decoration: const InputDecoration(
                  hintText: '0,00',
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
                    final limite = double.tryParse(texto);

                    if (limite == null || limite <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Informe um limite válido'),
                        ),
                      );
                      return;
                    }

                    final duplicado = _orcamentosBox.values
                        .toList()
                        .asMap()
                        .entries
                        .any((e) {
                          if (index != null && e.key == index) return false;
                          return e.value.categoria == categoriaSelecionada;
                        });

                    if (duplicado) {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Orçamento duplicado'),
                          content: Text(
                            'Já existe um orçamento para "$categoriaSelecionada".',
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

                    final novoOrcamento = Orcamento(
                      id:
                          orcamento?.id ??
                          DateTime.now().millisecondsSinceEpoch.toString(),
                      categoria: categoriaSelecionada,
                      limite: limite,
                    );

                    if (orcamento == null) {
                      await _orcamentosBox.add(novoOrcamento);
                    } else {
                      await _orcamentosBox.putAt(index!, novoOrcamento);
                    }
                    setState(() {});
                    Navigator.pop(context);
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
      ),
    );
  }

  void _adicionarOuEditarFormaPagamento({FormaPagamento? forma, int? index}) {
    final descricaoController = TextEditingController(
      text: forma?.descricao ?? '',
    );
    final bancoController = TextEditingController(text: forma?.banco ?? '');
    String tipoSelecionado = forma?.tipo ?? 'Crédito';

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
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                forma == null
                    ? 'Nova Forma de Pagamento'
                    : 'Editar Forma de Pagamento',
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
      ),
    );
  }

  void _adicionarOuEditarPessoa({Pessoa? pessoa, int? index}) {
    final nomeController = TextEditingController(text: pessoa?.nome ?? '');
    String parentescoSelecionado = pessoa?.parentesco ?? 'Eu Mesmo';
    if (!_grausParentesco.contains(parentescoSelecionado)) {
      parentescoSelecionado = 'Outro';
    }

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
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pessoa == null ? 'Nova Pessoa' : 'Editar Pessoa',
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
                value: parentescoSelecionado,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: _grausParentesco.map((grau) {
                  return DropdownMenuItem(value: grau, child: Text(grau));
                }).toList(),
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
      ),
    );
  }

  Future<bool?> _confirmarExclusao(
    BuildContext context,
    String titulo,
    String mensagem,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo),
        content: Text(mensagem),
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
  }

  String _formatarValor(double valor) =>
      'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';

  @override
  Widget build(BuildContext context) {
    final formas = _formasPagamentoBox.values.toList();
    final pessoas = _pessoasBox.values.toList();
    final orcamentos = _orcamentosBox.values.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
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
          // ── ABA FORMAS DE PAGAMENTO ──────────────────────────────────────
          formas.isEmpty
              ? const Center(
                  child: Text(
                    'Nenhuma forma de pagamento.\nToque em + para adicionar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                )
              : ListView.builder(
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
                      confirmDismiss: (direction) => _confirmarExclusao(
                        context,
                        'Excluir Forma de Pagamento',
                        'Tem certeza que deseja excluir esta forma de pagamento?',
                      ),
                      onDismissed: (_) async {
                        await _formasPagamentoBox.deleteAt(index);
                        setState(() {});
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

          // ── ABA PESSOAS ──────────────────────────────────────────────────
          pessoas.isEmpty
              ? const Center(
                  child: Text(
                    'Nenhuma pessoa cadastrada.\nToque em + para adicionar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                )
              : ListView.builder(
                  itemCount: pessoas.length,
                  itemBuilder: (context, index) {
                    final pessoa = pessoas[index];
                    return Dismissible(
                      key: Key(pessoa.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Colors.red,
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (direction) => _confirmarExclusao(
                        context,
                        'Excluir Pessoa',
                        'Tem certeza que deseja excluir esta pessoa?',
                      ),
                      onDismissed: (_) async {
                        await _pessoasBox.deleteAt(index);
                        setState(() {});
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
                            index: index,
                          ),
                        ),
                      ),
                    );
                  },
                ),

          // ── ABA ORÇAMENTOS ───────────────────────────────────────────────
          orcamentos.isEmpty
              ? const Center(
                  child: Text(
                    'Nenhum orçamento definido.\nToque em + para adicionar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: orcamentos.length,
                  itemBuilder: (context, index) {
                    final orc = orcamentos[index];
                    return Dismissible(
                      key: Key(orc.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Colors.red,
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (direction) => _confirmarExclusao(
                        context,
                        'Excluir Orçamento',
                        'Tem certeza que deseja excluir o orçamento de "${orc.categoria}"?',
                      ),
                      onDismissed: (_) async {
                        await _orcamentosBox.deleteAt(index);
                        setState(() {});
                      },
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            child: Icon(
                              Icons.account_balance_wallet,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          title: Text(
                            orc.categoria,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Limite: ${_formatarValor(orc.limite)}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            onPressed: () => _adicionarOuEditarOrcamento(
                              orcamento: orc,
                              index: index,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_tabController.index == 0) {
            _adicionarOuEditarFormaPagamento();
          } else if (_tabController.index == 1) {
            _adicionarOuEditarPessoa();
          } else {
            _adicionarOuEditarOrcamento();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
