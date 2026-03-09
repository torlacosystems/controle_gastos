import 'dart:math';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'subscription_service.dart';
import 'paywall_screen.dart';
import 'gasto.dart';
import 'receita.dart';
import 'forma_pagamento.dart';
import 'pessoa.dart';
import 'orcamento.dart';
import 'backup_screen.dart';
import 'onboarding_screen.dart';
import 'configuracoes_screen.dart';
import 'fade_route.dart';
import 'app_settings.dart';
import 'auth_service.dart';

// Template de gasto: (descricao, valorBase, categoria, forma, estabelecimento, tipoGasto, gastoEsperado)
typedef _GT = (String, double, String, String, String, String, bool);

class ConfiguracoesSistemaScreen extends StatefulWidget {
  const ConfiguracoesSistemaScreen({super.key});

  @override
  State<ConfiguracoesSistemaScreen> createState() =>
      _ConfiguracoesSistemaScreenState();
}

class _ConfiguracoesSistemaScreenState
    extends State<ConfiguracoesSistemaScreen> {
  bool _bloqueioAtivo = false;

  @override
  void initState() {
    super.initState();
    _carregarBloqueio();
  }

  Future<void> _carregarBloqueio() async {
    final ativo = await AuthService.bloqueioAtivo;
    if (mounted) setState(() => _bloqueioAtivo = ativo);
  }

  Future<void> _toggleBloqueio(bool ativo) async {
    if (ativo) {
      final disponivel = await AuthService.disponivel;
      if (!disponivel) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Seu dispositivo não suporta biometria ou PIN.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      // Autentica uma vez para confirmar que funciona antes de ativar
      final autenticado = await AuthService.autenticar();
      if (!autenticado) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Autenticação necessária para ativar o bloqueio.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
    }
    await AuthService.setBloqueio(ativo);
    setState(() => _bloqueioAtivo = ativo);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ativo ? 'Bloqueio ativado.' : 'Bloqueio desativado.'),
          backgroundColor: ativo ? Colors.green : Colors.grey,
        ),
      );
    }
  }

  Future<void> _gerarDadosTeste() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gerar dados de teste'),
        content: const Text(
          'Serão inseridos ~3.700 gastos e 40 receitas equivalentes a 1 ano de histórico '
          '(mar/2025 → fev/2026).\n\nOs dados atuais serão apagados antes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Gerar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    final gastosBox = Hive.box<Gasto>('gastos');
    final receitasBox = Hive.box<Receita>('receitas');
    final formasBox = Hive.box<FormaPagamento>('formas_pagamento');
    final pessoasBox = Hive.box<Pessoa>('pessoas');
    final orcamentosBox = Hive.box<Orcamento>('orcamentos');

    await gastosBox.clear();
    await receitasBox.clear();
    await formasBox.clear();
    await pessoasBox.clear();
    await orcamentosBox.clear();

    await formasBox.addAll([
      FormaPagamento(id: 'fp1', descricao: 'Nubank Débito', tipo: 'Débito', banco: 'Nubank'),
      FormaPagamento(id: 'fp2', descricao: 'Inter Débito', tipo: 'Débito', banco: 'Inter'),
      FormaPagamento(id: 'fp3', descricao: 'Nubank Crédito', tipo: 'Crédito', banco: 'Nubank'),
      FormaPagamento(id: 'fp4', descricao: 'XP Crédito', tipo: 'Crédito', banco: 'XP Investimentos'),
    ]);

    await pessoasBox.addAll([
      Pessoa(id: 'p1', nome: 'Eu', parentesco: 'Eu mesmo'),
      Pessoa(id: 'p2', nome: 'Ana', parentesco: 'Cônjuge'),
      Pessoa(id: 'p3', nome: 'Pedro', parentesco: 'Filho'),
    ]);

    await orcamentosBox.addAll([
      Orcamento(id: 'o1', categoria: 'Alimentação', limite: 800),
      Orcamento(id: 'o2', categoria: 'Moradia', limite: 2500),
      Orcamento(id: 'o3', categoria: 'Transporte', limite: 500),
      Orcamento(id: 'o4', categoria: 'Saúde', limite: 600),
      Orcamento(id: 'o5', categoria: 'Educação', limite: 400),
      Orcamento(id: 'o6', categoria: 'Lazer', limite: 400),
      Orcamento(id: 'o7', categoria: 'Vestuário', limite: 300),
      Orcamento(id: 'o8', categoria: 'Tecnologia', limite: 500),
      Orcamento(id: 'o9', categoria: 'Pets', limite: 200),
      Orcamento(id: 'o10', categoria: 'Assinaturas', limite: 150),
    ]);

    final rng = Random(42);

    // varia valor em ±15%
    double vr(double base) =>
        double.parse((base * (0.85 + rng.nextDouble() * 0.3)).toStringAsFixed(2));

    // Templates: (desc, valorBase, categoria, forma, estabelecimento, tipoGasto, gastoEsperado)
    

    // Gastos fixos mensais de "Eu" — lançados no dia 5 de cada mês (10 itens)
    final euFixed = <_GT>[
      ('Aluguel', 1800, 'Moradia', 'Inter Débito', 'Imobiliária Silva', 'Essencial', true),
      ('Conta de luz', 195, 'Moradia', 'Inter Débito', 'CPFL', 'Essencial', true),
      ('Conta de água', 92, 'Moradia', 'Inter Débito', 'Sabesp', 'Essencial', true),
      ('Internet fibra', 120, 'Moradia', 'Inter Débito', 'Vivo Fibra', 'Essencial', true),
      ('Plano de saúde', 380, 'Saúde', 'Inter Débito', 'Unimed', 'Essencial', true),
      ('Academia', 99, 'Saúde', 'Nubank Débito', 'Smart Fit', 'Essencial', true),
      ('Escola Pedro', 800, 'Educação', 'Inter Débito', 'Colégio São José', 'Essencial', true),
      ('Condomínio', 350, 'Moradia', 'Inter Débito', 'Condomínio Res.', 'Essencial', true),
      ('Netflix', 55.9, 'Assinaturas', 'Nubank Crédito', 'Netflix', 'Supérfluo', true),
      ('Spotify', 21.9, 'Assinaturas', 'Nubank Crédito', 'Spotify', 'Supérfluo', true),
    ];

    // Gastos variáveis de "Eu" — 6/dia nos outros dias (18 templates rotacionados)
    final euVar = <_GT>[
      ('iFood pedido', 42, 'Alimentação', 'Nubank Crédito', 'iFood', 'Supérfluo', false),
      ('Restaurante almoço', 38, 'Alimentação', 'Nubank Débito', 'Restaurante Central', 'Essencial', true),
      ('Supermercado', 185, 'Alimentação', 'Inter Débito', 'Carrefour', 'Essencial', true),
      ('Gasolina', 155, 'Transporte', 'Inter Débito', 'Posto Shell', 'Essencial', true),
      ('Uber', 24, 'Transporte', 'Nubank Crédito', 'Uber', 'Essencial', true),
      ('Estacionamento', 16, 'Transporte', 'Nubank Débito', 'Estacionamento 24h', 'Essencial', true),
      ('Farmácia', 72, 'Saúde', 'Nubank Débito', 'Drogasil', 'Essencial', false),
      ('Cinema', 58, 'Lazer', 'Nubank Crédito', 'Cinemark', 'Lazer', false),
      ('Bar happy hour', 85, 'Lazer', 'Nubank Crédito', 'Bar do Alemão', 'Supérfluo', false),
      ('Roupa masculina', 160, 'Vestuário', 'XP Crédito', 'Renner', 'Supérfluo', false),
      ('Eletrônico', 220, 'Tecnologia', 'XP Crédito', 'Magazine Luiza', 'Supérfluo', false),
      ('Ração cachorro', 125, 'Pets', 'Inter Débito', 'Petz', 'Essencial', true),
      ('Consulta médica', 260, 'Saúde', 'XP Crédito', 'Clínica São Lucas', 'Essencial', false),
      ('Padaria lanche', 22, 'Alimentação', 'Nubank Débito', 'Padaria Central', 'Essencial', true),
      ('Pizza delivery', 68, 'Alimentação', 'Nubank Crédito', 'Dominos', 'Supérfluo', false),
      ('Curso online', 147, 'Educação', 'XP Crédito', 'Udemy', 'Essencial', true),
      ('Banho pet shop', 82, 'Pets', 'Nubank Débito', 'Pet Shop Amigo', 'Essencial', true),
      ('Lanche rápido', 28, 'Alimentação', 'Nubank Débito', "Bob's", 'Supérfluo', false),
    ];

    // Gastos de "Ana" — 3/dia todos os dias (10 templates)
    final anaVar = <_GT>[
      ('Supermercado', 125, 'Alimentação', 'Nubank Débito', 'Extra', 'Essencial', true),
      ('Restaurante almoço', 42, 'Alimentação', 'Nubank Crédito', 'Restaurante Sabor', 'Essencial', true),
      ('Farmácia', 58, 'Saúde', 'Nubank Débito', 'Farmácias São João', 'Essencial', false),
      ('Roupa', 185, 'Vestuário', 'Nubank Crédito', 'Zara', 'Supérfluo', false),
      ('Transporte app', 19, 'Transporte', 'Nubank Crédito', 'Uber', 'Essencial', true),
      ('Mercadinho', 48, 'Alimentação', 'Nubank Débito', 'Mercado Bom Preço', 'Essencial', true),
      ('Salão de beleza', 125, 'Saúde', 'Nubank Crédito', 'Salão da Mari', 'Supérfluo', false),
      ('iFood', 45, 'Alimentação', 'Nubank Crédito', 'iFood', 'Supérfluo', false),
      ('Academia Ana', 89, 'Saúde', 'Nubank Débito', 'Bio Ritmo', 'Essencial', true),
      ('Loja de roupas', 95, 'Vestuário', 'Nubank Crédito', 'C&A', 'Supérfluo', false),
    ];

    // Gastos de "Pedro" — 1/dia todos os dias (7 templates)
    final pedroVar = <_GT>[
      ('Lanche escola', 16, 'Alimentação', 'Nubank Débito', 'Cantina Escolar', 'Essencial', true),
      ('Material escolar', 48, 'Educação', 'Nubank Débito', 'Livraria Cultura', 'Essencial', true),
      ('Brinquedo', 85, 'Lazer', 'Nubank Crédito', 'Ri Happy', 'Supérfluo', false),
      ('Cinema kids', 38, 'Lazer', 'Nubank Crédito', 'Cinemark', 'Lazer', false),
      ('Jogo PS5', 65, 'Tecnologia', 'Nubank Crédito', 'PlayStation Store', 'Supérfluo', false),
      ("McDonald's", 36, 'Alimentação', 'Nubank Débito', "McDonald's", 'Supérfluo', false),
      ('Roupa infantil', 72, 'Vestuário', 'Nubank Crédito', 'Zara Kids', 'Essencial', true),
    ];

    int gId = 0;
    final gastos = <Gasto>[];
    final start = DateTime(2025, 3, 1);

    Gasto mkG(_GT t, DateTime date, String pessoa, {bool recorrente = false}) => Gasto(
          id: 'g${++gId}',
          descricao: t.$1,
          valor: vr(t.$2),
          categoria: t.$3,
          data: date,
          formaPagamento: t.$4,
          pessoa: pessoa,
          tipoGasto: t.$6,
          parcelado: false,
          numeroParcelas: 1,
          estabelecimento: t.$5,
          recorrente: recorrente,
          gastoEsperado: t.$7,
        );

    // 365 dias: mar/2025 → fev/2026
    // Dia 5 de cada mês: 10 fixos Eu + 3 Ana + 1 Pedro = 14  → 12 × 14 = 168
    // Demais 353 dias:    6 Eu + 3 Ana + 1 Pedro = 10         → 353 × 10 = 3530
    // Total: 3698 gastos
    for (int day = 0; day < 365; day++) {
      final date = start.add(Duration(days: day));
      final isFixed = date.day == 5;

      if (isFixed) {
        for (final t in euFixed) {
          gastos.add(mkG(t, date, 'Eu', recorrente: true));
        }
      } else {
        for (int i = 0; i < 6; i++) {
          gastos.add(mkG(euVar[(day * 6 + i) % euVar.length], date, 'Eu'));
        }
      }
      for (int i = 0; i < 3; i++) {
        gastos.add(mkG(anaVar[(day * 3 + i) % anaVar.length], date, 'Ana'));
      }
      gastos.add(mkG(pedroVar[day % pedroVar.length], date, 'Pedro'));
    }

    await gastosBox.addAll(gastos);

    // ── Receitas (40 total) ──────────────────────────────────────────────────
    int rId = 0;
    final receitas = <Receita>[];

    Receita mkR(String desc, double val, String cat, DateTime date, String pessoa,
            {bool recorrente = false, String tipo = 'Extra'}) =>
        Receita(
          id: 'r${++rId}',
          descricao: desc,
          valor: vr(val),
          categoria: cat,
          data: date,
          pessoa: pessoa,
          recorrente: recorrente,
          tipoReceita: tipo,
        );

    // Salários Eu + Ana — 12 meses × 2 = 24
    for (int m = 0; m < 12; m++) {
      final d = DateTime(2025, 3 + m, 5);
      receitas.add(mkR('Salário', 6500, 'Salário', d, 'Eu', recorrente: true, tipo: 'Fixo'));
      receitas.add(mkR('Salário', 4200, 'Salário', d, 'Ana', recorrente: true, tipo: 'Fixo'));
    }

    // Freelance Eu — 8 registros (meses alternados)
    for (int i = 0; i < 8; i++) {
      receitas.add(mkR('Freelance desenvolvimento', 1500, 'Freelance',
          DateTime(2025, 3 + i, 15), 'Eu'));
    }

    // Dividendos Eu — 4 registros (trimestral)
    for (int q = 0; q < 4; q++) {
      receitas.add(mkR('Dividendos ações', 350, 'Investimentos',
          DateTime(2025, 3 + q * 3, 20), 'Eu'));
    }

    // Bônus Ana — 4 registros (trimestral: abr, jul, out, jan)
    for (int q = 0; q < 4; q++) {
      receitas.add(mkR('Bônus trimestral', 800, 'Bônus',
          DateTime(2025, 4 + q * 3, 20), 'Ana'));
    }

    // Total: 24 + 8 + 4 + 4 = 40
    await receitasBox.addAll(receitas);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${gastos.length} gastos e ${receitas.length} receitas gerados!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _limparDados() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar todos os dados'),
        content: const Text(
          'Esta ação é irreversível. Todos os gastos, receitas, formas de pagamento, pessoas e orçamentos serão excluídos.\n\nTem certeza?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Limpar tudo'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    await Hive.box<Gasto>('gastos').clear();
    await Hive.box<Receita>('receitas').clear();
    await Hive.box<FormaPagamento>('formas_pagamento').clear();
    await Hive.box<Pessoa>('pessoas').clear();
    await Hive.box<Orcamento>('orcamentos').clear();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Todos os dados foram removidos.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          // ── MINHA CONTA ──────────────────────────────────────────────────
          _cabecalhoSecao('Minha Conta'),
          ListenableBuilder(
            listenable: SubscriptionService.instance,
            builder: (context, _) {
              final service = SubscriptionService.instance;
              if (service.isSubscriptionActive) {
                return Column(
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.workspace_premium,
                        color: Colors.amber,
                      ),
                      title: const Text(
                        'Premium ativo',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text('Você tem acesso a todos os recursos'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.restore),
                      title: const Text('Restaurar compra'),
                      subtitle: const Text('Sincroniza sua assinatura com a Play Store'),
                      onTap: () async {
                        await SubscriptionService.instance.restorePurchases();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Compra restaurada.')),
                          );
                        }
                      },
                    ),
                  ],
                );
              }
              if (service.isTrialActive) {
                return ListTile(
                  leading: const Icon(Icons.workspace_premium_outlined),
                  title: const Text('Período de teste'),
                  subtitle: Text(
                    '${service.trialDaysRemaining} dia(s) restante(s) — Assine para continuar',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    FadeRoute(page: const PaywallScreen()),
                  ),
                );
              }
              return ListTile(
                leading: const Icon(Icons.workspace_premium_outlined),
                title: const Text('Seja Premium'),
                subtitle: const Text('Desbloqueie todos os recursos do app'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  FadeRoute(page: const PaywallScreen()),
                ),
              );
            },
          ),
          const Divider(),

          // ── APARÊNCIA ───────────────────────────────────────────────────
          _cabecalhoSecao('Aparência'),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeModeNotifier,
            builder: (context, themeMode, _) {
              final brightnessAtual = MediaQuery.platformBrightnessOf(context);
              final isDark =
                  themeMode == ThemeMode.dark ||
                  (themeMode == ThemeMode.system &&
                      brightnessAtual == Brightness.dark);
              return SwitchListTile(
                secondary: const Icon(Icons.dark_mode),
                title: const Text('Modo escuro'),
                subtitle: const Text('Ativar tema dark no app'),
                value: isDark,
                onChanged: (v) {
                  themeModeNotifier.value = v
                      ? ThemeMode.dark
                      : ThemeMode.light;
                  salvarTema(v, brightnessAtual);
                },
              );
            },
          ),
          const Divider(),

          // ── SEGURANÇA ───────────────────────────────────────────────────
          // ── CONFIGURAÇÃO ─────────────────────────────────────────────────
          _cabecalhoSecao('Configuração'),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Cadastro Inicial'),
            subtitle: const Text('Formas de pagamento, pessoas e orçamentos'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              FadeRoute(page: const ConfiguracoesScreen()),
            ),
          ),
          const Divider(),

          _cabecalhoSecao('Segurança'),
          SwitchListTile(
            secondary: const Icon(Icons.lock_outline),
            title: const Text('Bloquear app'),
            subtitle: const Text('Pedir biometria ou PIN ao abrir o app'),
            value: _bloqueioAtivo,
            onChanged: _toggleBloqueio,
          ),
          const Divider(),

          // ── DADOS ────────────────────────────────────────────────────────
          _cabecalhoSecao('Dados'),
          ListTile(
            leading: const Icon(Icons.backup),
            title: const Text('Exportar backup'),
            subtitle: const Text('Salvar ou compartilhar seus dados'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              if (!SubscriptionService.instance.isPremium) {
                Navigator.push(context, FadeRoute(page: const PaywallScreen()));
              } else {
                Navigator.push(context, FadeRoute(page: const BackupScreen()));
              }
            },
          ),
          if (kDebugMode)
            ListTile(
              leading: const Icon(Icons.science_outlined, color: Colors.purple),
              title: const Text(
                'Gerar dados de teste',
                style: TextStyle(color: Colors.purple),
              ),
              subtitle: const Text('Insere registros de exemplo no app'),
              onTap: _gerarDadosTeste,
            ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text(
              'Limpar todos os dados',
              style: TextStyle(color: Colors.red),
            ),
            subtitle: const Text('Remove todos os registros do app'),
            onTap: _limparDados,
          ),
          const Divider(),

          // ── SOBRE ────────────────────────────────────────────────────────
          _cabecalhoSecao('Sobre'),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Ver tutorial'),
            subtitle: const Text('Revisitar as instruções de uso do app'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              FadeRoute(page: const OnboardingScreen()),
            ),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Versão'),
            subtitle: Text('1.0.0'),
          ),
          const ListTile(
            leading: Icon(Icons.person_outline),
            title: Text('Desenvolvedor'),
            subtitle: Text('Torlaco Systems'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _cabecalhoSecao(String titulo) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        titulo.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
