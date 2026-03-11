import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'forma_pagamento.dart';
import 'pessoa.dart';
import 'orcamento.dart';
import 'main.dart';
import 'fade_route.dart';

class SetupWizardScreen extends StatefulWidget {
  const SetupWizardScreen({super.key});

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen>
    with SingleTickerProviderStateMixin {
  int _step = 0; // 0=nome, 1=formas, 2=orcamentos, 3=pessoas, 4=pronto
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  // Step 0 – nome do usuário
  final _nomeUsuarioCtrl = TextEditingController();

  // Step 2 – formas de pagamento
  late Box<FormaPagamento> _formasBox;
  final _descricaoCtrl = TextEditingController();
  final _bancoCtrl = TextEditingController();
  String _tipoSelecionado = 'Débito';
  final List<FormaPagamento> _formasAdicionadas = [];

  // Step 3 – orçamentos por categoria
  late Box<Orcamento> _orcamentosBox;
  late Box<Pessoa> _pessoasBox;
  final Map<String, TextEditingController> _limiteCtrl = {};

  // Step 4 – pessoas
  final _pessoaNomeCtrl = TextEditingController();
  String _parentescoSelecionado = 'Cônjuge';
  final List<Pessoa> _pessoasAdicionadas = [];
  static const _parentescos = [
    'Cônjuge', 'Filho(a)', 'Pai/Mãe', 'Irmão/Irmã', 'Amigo(a)', 'Colega', 'Outro',
  ];

  static const _tipos = ['Débito', 'Crédito', 'VA/VR'];

  static const List<Map<String, dynamic>> _categorias = [
    {'nome': 'Alimentação',  'icone': Icons.restaurant},
    {'nome': 'Mercado',      'icone': Icons.shopping_cart},
    {'nome': 'Transporte',   'icone': Icons.directions_car},
    {'nome': 'Saúde',        'icone': Icons.health_and_safety},
    {'nome': 'Lazer',        'icone': Icons.movie},
    {'nome': 'Moradia',      'icone': Icons.home},
    {'nome': 'Educação',            'icone': Icons.school},
    {'nome': 'Assinaturas', 'icone': Icons.subscriptions},
    {'nome': 'Outros',              'icone': Icons.category},
  ];

  @override
  void initState() {
    super.initState();
    _formasBox = Hive.box<FormaPagamento>('formas_pagamento');
    _orcamentosBox = Hive.box<Orcamento>('orcamentos');
    _pessoasBox = Hive.box<Pessoa>('pessoas');
    for (final cat in _categorias) {
      _limiteCtrl[cat['nome'] as String] = TextEditingController();
    }
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _nomeUsuarioCtrl.dispose();
    _descricaoCtrl.dispose();
    _bancoCtrl.dispose();
    _pessoaNomeCtrl.dispose();
    for (final c in _limiteCtrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _irPara(int step) {
    _animCtrl.reverse().then((_) {
      setState(() => _step = step);
      _animCtrl.forward();
    });
  }

  /// Avança para o próximo step submetendo o campo em edição (se houver)
  void _avancar(int step) {
    if (_step == 1 && _descricaoCtrl.text.trim().isNotEmpty) _adicionarForma();
    if (_step == 3 && _pessoaNomeCtrl.text.trim().isNotEmpty) _adicionarPessoa();
    _irPara(step);
  }

  void _adicionarForma() {
    final desc = _descricaoCtrl.text.trim();
    if (desc.isEmpty) return;
    final jaExiste = _formasAdicionadas.any(
      (f) => f.descricao.toLowerCase() == desc.toLowerCase() && f.tipo == _tipoSelecionado,
    );
    if (jaExiste) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Forma de pagamento já cadastrada com esse nome e tipo.')),
      );
      return;
    }
    final forma = FormaPagamento(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      descricao: desc,
      tipo: _tipoSelecionado,
      banco: _bancoCtrl.text.trim(),
    );
    _formasAdicionadas.add(forma);
    _descricaoCtrl.clear();
    _bancoCtrl.clear();
    setState(() {});
  }

  Future<void> _concluir() async {
    // Salva o usuário principal como Pessoa com parentesco "Eu Mesmo"
    final nomeUsuario = _nomeUsuarioCtrl.text.trim();
    if (nomeUsuario.isNotEmpty) {
      await _pessoasBox.put(
        'usuario_principal',
        Pessoa(
          id: 'usuario_principal',
          nome: nomeUsuario,
          parentesco: 'Eu Mesmo',
        ),
      );
    }

    // Salva formas de pagamento
    if (_formasAdicionadas.isNotEmpty) {
      await _formasBox.addAll(_formasAdicionadas);
    }

    // Salva pessoas adicionadas no wizard
    for (final p in _pessoasAdicionadas) {
      await _pessoasBox.put(p.id, p);
    }

    // Salva orçamentos por categoria
    for (final cat in _categorias) {
      final nome = cat['nome'] as String;
      final texto = _limiteCtrl[nome]!.text.trim().replaceAll(',', '.');
      final limite = double.tryParse(texto);
      if (limite != null && limite > 0) {
        final jaExiste = _orcamentosBox.values
            .any((o) => o.categoria == nome);
        if (!jaExiste) {
          await _orcamentosBox.add(Orcamento(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            categoria: nome,
            limite: limite,
          ));
        }
      }
    }

    if (!mounted) return;
    Navigator.pushReplacement(context, FadeRoute(page: const HomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── Barra de progresso (steps 1, 2 e 3) ──
            if (_step >= 1 && _step <= 3)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: List.generate(3, (i) {
                        final done = i < _step - 1;
                        final active = i == _step - 1;
                        return Expanded(
                          child: Container(
                            margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                            height: 6,
                            decoration: BoxDecoration(
                              color: done || active ? cor : Colors.grey[200],
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Passo $_step de 3',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),

            // ── Conteúdo animado ────────────────────────────────────────
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: _buildStep(cor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(Color cor) {
    switch (_step) {
      case 0:
        return _buildNome(cor);
      case 1:
        return _buildFormasPagamento(cor);
      case 2:
        return _buildOrcamentos(cor);
      case 3:
        return _buildPessoas(cor);
      case 4:
        return _buildPronto(cor);
      default:
        return const SizedBox();
    }
  }

  // ── STEP 0: Nome ──────────────────────────────────────────────────────────

  Widget _buildNome(Color cor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const SizedBox(height: 48),
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.waving_hand_outlined, size: 56, color: cor),
          ),
          const SizedBox(height: 32),
          const Text(
            'Olá! Como podemos\nte chamar?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            'Seu nome aparecerá nos insights e relatórios, e ficará salvo como pessoa principal.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey[600], height: 1.6),
          ),
          const SizedBox(height: 40),
          TextField(
            controller: _nomeUsuarioCtrl,
            textCapitalization: TextCapitalization.words,
            autofocus: true,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20),
            decoration: InputDecoration(
              hintText: 'Seu nome',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: () => _irPara(1),
              child: const Text('Continuar', style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _concluir,
            child: Text('Configurar depois',
                style: TextStyle(color: Colors.grey[500])),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── STEP 2: Formas de Pagamento ───────────────────────────────────────────

  Widget _buildFormasPagamento(Color cor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.credit_card_outlined, color: cor, size: 26),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Formas de Pagamento',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('Cartões, contas e carteiras',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          if (_formasAdicionadas.isNotEmpty) ...[
            const Text('Adicionadas:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ..._formasAdicionadas.asMap().entries.map((e) => Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      e.value.tipo == 'Crédito'
                          ? Icons.credit_card
                          : Icons.account_balance_wallet,
                      color: cor,
                      size: 20,
                    ),
                    title: Text(e.value.descricao,
                        style: const TextStyle(fontSize: 13)),
                    subtitle: Text('${e.value.tipo} • ${e.value.banco}',
                        style: const TextStyle(fontSize: 11)),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () =>
                          setState(() => _formasAdicionadas.removeAt(e.key)),
                    ),
                  ),
                )),
            const SizedBox(height: 16),
          ],

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formasAdicionadas.isEmpty
                        ? 'Adicione sua primeira forma de pagamento'
                        : 'Adicionar outra',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descricaoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nome (ex: Nubank Crédito)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _tipoSelecionado,
                          decoration: const InputDecoration(
                            labelText: 'Tipo',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: _tipos
                              .map((t) => DropdownMenuItem(
                                  value: t, child: Text(t)))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _tipoSelecionado = v!),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _bancoCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Banco (opcional)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _adicionarForma,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Adicionar'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: () => _avancar(2),
              child: const Text('Próximo: Orçamentos',
                  style: TextStyle(fontSize: 15)),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => _irPara(2),
              child: Text('Pular esta etapa',
                  style: TextStyle(color: Colors.grey[500])),
            ),
          ),
        ],
      ),
    );
  }

  // ── STEP 3: Orçamentos por categoria ─────────────────────────────────────

  Widget _buildOrcamentos(Color cor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.account_balance_wallet_outlined, color: cor, size: 26),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Orçamento Mensal',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('Defina limites de gasto por categoria',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: cor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Deixe em branco as categorias que não deseja controlar. Você pode ajustar depois em Configurações.',
                    style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          ..._categorias.map((cat) {
            final nome = cat['nome'] as String;
            final icone = cat['icone'] as IconData;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: cor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icone, color: cor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _limiteCtrl[nome],
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: nome,
                        hintText: 'Limite mensal',
                        prefixText: 'R\$ ',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: () => _avancar(3),
              child: const Text('Próximo: Pessoas', style: TextStyle(fontSize: 15)),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => _irPara(3),
              child: Text('Pular esta etapa',
                  style: TextStyle(color: Colors.grey[500])),
            ),
          ),
        ],
      ),
    );
  }

  // ── STEP 3: Pessoas ───────────────────────────────────────────────────────

  void _adicionarPessoa() {
    final nome = _pessoaNomeCtrl.text.trim();
    if (nome.isEmpty) return;
    final jaExiste = _pessoasAdicionadas.any(
      (p) => p.nome.toLowerCase() == nome.toLowerCase() && p.parentesco == _parentescoSelecionado,
    );
    if (jaExiste) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pessoa já cadastrada com esse nome e parentesco.')),
      );
      return;
    }
    setState(() {
      _pessoasAdicionadas.add(Pessoa(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        nome: nome,
        parentesco: _parentescoSelecionado,
      ));
      _pessoaNomeCtrl.clear();
    });
  }

  Widget _buildPessoas(Color cor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.group_outlined, color: cor, size: 26),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pessoas',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('Com quem você costuma gastar',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_pessoasAdicionadas.isNotEmpty) ...[
            const Text('Adicionadas:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ..._pessoasAdicionadas.asMap().entries.map((e) => Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.person_outline, color: cor, size: 20),
                    title: Text(e.value.nome,
                        style: const TextStyle(fontSize: 13)),
                    subtitle: Text(e.value.parentesco,
                        style: const TextStyle(fontSize: 11)),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () =>
                          setState(() => _pessoasAdicionadas.removeAt(e.key)),
                    ),
                  ),
                )),
            const SizedBox(height: 16),
          ],

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _pessoasAdicionadas.isEmpty
                        ? 'Adicione alguém com quem costuma gastar'
                        : 'Adicionar outra pessoa',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pessoaNomeCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nome',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _parentescoSelecionado,
                    decoration: const InputDecoration(
                      labelText: 'Parentesco / Relação',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _parentescos
                        .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _parentescoSelecionado = v!),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _adicionarPessoa,
                      icon: const Icon(Icons.person_add_outlined, size: 18),
                      label: const Text('Adicionar'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: () => _avancar(4),
              child: const Text('Concluir', style: TextStyle(fontSize: 15)),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => _irPara(4),
              child: Text('Pular esta etapa',
                  style: TextStyle(color: Colors.grey[500])),
            ),
          ),
        ],
      ),
    );
  }

  // ── STEP 4: Pronto ────────────────────────────────────────────────────────

  Widget _buildPronto(Color cor) {
    final orcamentosDefinidos = _categorias
        .where((cat) {
          final texto = _limiteCtrl[cat['nome'] as String]!.text.trim();
          final valor = double.tryParse(texto.replaceAll(',', '.'));
          return valor != null && valor > 0;
        })
        .length;
    final temNome = _nomeUsuarioCtrl.text.trim().isNotEmpty;
    final temFormas = _formasAdicionadas.isNotEmpty;
    final temPessoas = _pessoasAdicionadas.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_outline,
                size: 60, color: Colors.green),
          ),
          const SizedBox(height: 32),
          const Text(
            'Tudo pronto!',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            [
              if (temNome) 'Olá, ${_nomeUsuarioCtrl.text.trim()}!',
              if (temFormas) '${_formasAdicionadas.length} forma${_formasAdicionadas.length == 1 ? '' : 's'} de pagamento adicionada${_formasAdicionadas.length == 1 ? '' : 's'}.',
              if (orcamentosDefinidos > 0) '$orcamentosDefinidos limite${orcamentosDefinidos == 1 ? '' : 's'} de orçamento definido${orcamentosDefinidos == 1 ? '' : 's'}.',
              if (temPessoas) '${_pessoasAdicionadas.length} pessoa${_pessoasAdicionadas.length == 1 ? '' : 's'} adicionada${_pessoasAdicionadas.length == 1 ? '' : 's'}.',
              if (!temFormas && orcamentosDefinidos == 0) 'Você pode configurar formas de pagamento e orçamentos nas Configurações a qualquer momento.',
            ].join(' '),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey[600], height: 1.6),
          ),
          if (!temFormas) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Sem formas de pagamento não será possível registrar gastos.',
                      style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _concluir,
              child: const Text('Começar a usar o Granix',
                  style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => _irPara(3),
            child: Text('Voltar', style: TextStyle(color: Colors.grey[500])),
          ),
        ],
      ),
    );
  }
}
