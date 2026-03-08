import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'forma_pagamento.dart';
import 'pessoa.dart';
import 'app_settings.dart';
import 'main.dart';
import 'fade_route.dart';

class SetupWizardScreen extends StatefulWidget {
  const SetupWizardScreen({super.key});

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen>
    with SingleTickerProviderStateMixin {
  int _step = 0; // 0=intro, 1=nome+renda, 2=formas, 3=pessoas, 4=pronto
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  // Step 1 – nome do usuário e renda mensal
  final _nomeUsuarioCtrl = TextEditingController();
  final _rendaMensalCtrl = TextEditingController();

  // Formas de pagamento
  late Box<FormaPagamento> _formasBox;
  final _descricaoCtrl = TextEditingController();
  final _bancoCtrl = TextEditingController();
  String _tipoSelecionado = 'Débito';
  final List<FormaPagamento> _formasAdicionadas = [];

  // Pessoas
  late Box<Pessoa> _pessoasBox;
  final _nomeCtrl = TextEditingController();
  final _parentescoCtrl = TextEditingController();
  final List<Pessoa> _pessoasAdicionadas = [];

  static const _tipos = ['Débito', 'Crédito', 'VA/VR'];

  static const _parentescos = [
    'Eu mesmo',
    'Cônjuge',
    'Filho(a)',
    'Pai/Mãe',
    'Irmão/Irmã',
    'Outro',
  ];

  @override
  void initState() {
    super.initState();
    _formasBox = Hive.box<FormaPagamento>('formas_pagamento');
    _pessoasBox = Hive.box<Pessoa>('pessoas');
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
    _rendaMensalCtrl.dispose();
    _descricaoCtrl.dispose();
    _bancoCtrl.dispose();
    _nomeCtrl.dispose();
    _parentescoCtrl.dispose();
    super.dispose();
  }

  void _irPara(int step) {
    _animCtrl.reverse().then((_) {
      setState(() => _step = step);
      _animCtrl.forward();
    });
  }

  void _adicionarForma() {
    final desc = _descricaoCtrl.text.trim();
    if (desc.isEmpty) return;
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

  void _adicionarPessoa() {
    final nome = _nomeCtrl.text.trim();
    if (nome.isEmpty) return;
    final pessoa = Pessoa(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      nome: nome,
      parentesco: _parentescoCtrl.text.trim().isEmpty
          ? 'Eu mesmo'
          : _parentescoCtrl.text.trim(),
    );
    _pessoasAdicionadas.add(pessoa);
    _nomeCtrl.clear();
    _parentescoCtrl.clear();
    setState(() {});
  }

  Future<void> _concluir() async {
    // Salva o usuário principal como Pessoa com parentesco "Eu mesmo"
    final nomeUsuario = _nomeUsuarioCtrl.text.trim();
    if (nomeUsuario.isNotEmpty) {
      final pessoaUsuario = Pessoa(
        id: 'usuario_principal',
        nome: nomeUsuario,
        parentesco: 'Eu Mesmo',
      );
      await _pessoasBox.put('usuario_principal', pessoaUsuario);
    }
    // Salva a renda mensal
    final rendaTexto = _rendaMensalCtrl.text.trim().replaceAll(',', '.');
    final renda = double.tryParse(rendaTexto);
    if (renda != null && renda > 0) {
      await salvarRendaMensal(renda);
    }
    if (_formasAdicionadas.isNotEmpty) {
      await _formasBox.addAll(_formasAdicionadas);
    }
    if (_pessoasAdicionadas.isNotEmpty) {
      await _pessoasBox.addAll(_pessoasAdicionadas);
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
            // ── Barra de progresso ─────────────────────────────────────
            if (_step > 0 && _step < 4)
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
        return _buildIntro(cor);
      case 1:
        return _buildNomeRenda(cor);
      case 2:
        return _buildFormasPagamento(cor);
      case 3:
        return _buildPessoas(cor);
      case 4:
        return _buildPronto(cor);
      default:
        return const SizedBox();
    }
  }

  // ── STEP 0: Intro ─────────────────────────────────────────────────────────

  Widget _buildIntro(Color cor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.tune_rounded, size: 56, color: cor),
          ),
          const SizedBox(height: 32),
          const Text(
            'Vamos configurar\nseu Granix!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            'Em menos de 2 minutos você vai cadastrar suas formas de pagamento e as pessoas da sua família. Isso é necessário para registrar gastos.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey[600], height: 1.6),
          ),
          const SizedBox(height: 40),
          _itemInfo(cor, Icons.person_outline, 'Seu nome e renda mensal',
              'Para personalizar insights'),
          const SizedBox(height: 14),
          _itemInfo(cor, Icons.credit_card_outlined, 'Formas de pagamento',
              'Cartões, contas e carteiras'),
          const SizedBox(height: 14),
          _itemInfo(cor, Icons.people_outlined, 'Pessoas',
              'Você e sua família'),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: () => _irPara(1),
              child: const Text('Começar configuração',
                  style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _concluir,
            child: Text('Configurar depois',
                style: TextStyle(color: Colors.grey[500])),
          ),
        ],
      ),
    );
  }

  Widget _itemInfo(Color cor, IconData icone, String titulo, String sub) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: cor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icone, color: cor, size: 22),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            Text(sub,
                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          ],
        ),
      ],
    );
  }

  // ── STEP 1: Nome + Renda ──────────────────────────────────────────────────

  Widget _buildNomeRenda(Color cor) {
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
                child: Icon(Icons.person_outline, color: cor, size: 26),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sobre você',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('Nome e renda familiar mensal',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _nomeUsuarioCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Seu nome',
                      hintText: 'Ex: João',
                      border: OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _rendaMensalCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Renda familiar mensal (R\$)',
                      hintText: 'Ex: 5000,00',
                      border: OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                  ),
                  const SizedBox(height: 12),
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
                            'A renda será usada para calcular sua média de gasto diário vs renda diária nos insights.',
                            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                          ),
                        ),
                      ],
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
              onPressed: () => _irPara(2),
              child: const Text('Próximo: Formas de Pagamento',
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

          // Lista das adicionadas
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

          // Formulário
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
              onPressed: () => _irPara(3),
              child: const Text('Próximo: Pessoas',
                  style: TextStyle(fontSize: 15)),
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

  // ── STEP 2: Pessoas ───────────────────────────────────────────────────────

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
                child: Icon(Icons.people_outlined, color: cor, size: 26),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pessoas',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('Você e sua família',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          if (_pessoasAdicionadas.isNotEmpty) ...[
            const Text('Adicionadas:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ..._pessoasAdicionadas.asMap().entries.map((e) => Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      backgroundColor: cor.withValues(alpha: 0.15),
                      radius: 16,
                      child: Text(
                        e.value.nome.isNotEmpty
                            ? e.value.nome[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                            color: cor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                    ),
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
                        ? 'Adicione a primeira pessoa'
                        : 'Adicionar outra',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nomeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nome',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _parentescos.first,
                    decoration: const InputDecoration(
                      labelText: 'Parentesco',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _parentescos
                        .map((p) =>
                            DropdownMenuItem(value: p, child: Text(p)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) _parentescoCtrl.text = v;
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _adicionarPessoa,
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
              onPressed: () => _irPara(4),
              child:
                  const Text('Concluir', style: TextStyle(fontSize: 15)),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => _irPara(2),
              child: Text('Voltar',
                  style: TextStyle(color: Colors.grey[500])),
            ),
          ),
        ],
      ),
    );
  }

  // ── STEP 3: Pronto ────────────────────────────────────────────────────────

  Widget _buildPronto(Color cor) {
    final totalItens =
        _formasAdicionadas.length + _pessoasAdicionadas.length;
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
            totalItens == 0
                ? 'Você pode adicionar formas de pagamento e pessoas nas Configurações a qualquer momento.'
                : 'Você adicionou ${_formasAdicionadas.length} forma${_formasAdicionadas.length == 1 ? '' : 's'} de pagamento e ${_pessoasAdicionadas.length} pessoa${_pessoasAdicionadas.length == 1 ? '' : 's'}. Agora é só começar!',
            textAlign: TextAlign.center,
            style:
                TextStyle(fontSize: 15, color: Colors.grey[600], height: 1.6),
          ),
          if (totalItens == 0) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: Colors.orange, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Sem formas de pagamento e pessoas não será possível registrar gastos.',
                      style: TextStyle(
                          fontSize: 12, color: Colors.orange[800]),
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
          if (totalItens == 0) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => _irPara(2),
              child: const Text('Voltar e configurar'),
            ),
          ],
        ],
      ),
    );
  }
}
