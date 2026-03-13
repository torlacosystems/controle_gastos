import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class ConfiguracoesSistemaScreen extends StatefulWidget {
  const ConfiguracoesSistemaScreen({super.key});

  @override
  State<ConfiguracoesSistemaScreen> createState() =>
      _ConfiguracoesSistemaScreenState();
}

class _ConfiguracoesSistemaScreenState
    extends State<ConfiguracoesSistemaScreen> {
  bool _bloqueioAtivo = false;
  bool _bloqueioWidget = false;

  @override
  void initState() {
    super.initState();
    _carregarBloqueio();
  }

  Future<void> _carregarBloqueio() async {
    final ativo = await AuthService.bloqueioAtivo;
    final widget = await AuthService.bloqueioWidgetAtivo;
    if (mounted) setState(() { _bloqueioAtivo = ativo; _bloqueioWidget = widget; });
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

  Future<void> _gerarMassaDados() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gerar massa de dados'),
        content: const Text(
          'Serão inseridos gastos e receitas fictícios dos últimos 3 meses para testes.\n\nOs dados existentes serão mantidos. Deseja continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
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

    // Usa formas/pessoas existentes ou cria genéricas
    final formas = formasBox.values.map((f) => f.descricao).toList();
    if (formas.isEmpty) formas.addAll(['Cartão Débito', 'Cartão Crédito', 'Dinheiro', 'Pix']);

    final pessoas = pessoasBox.values.map((p) => p.nome).toList();
    if (pessoas.isEmpty) pessoas.addAll(['Eu', 'Família']);

    final rng = Random(42);
    double v(double base) => double.parse((base * (0.85 + rng.nextDouble() * 0.3)).toStringAsFixed(2));

    final agora = DateTime.now();

    // Template de gastos: [descrição, categoria, valor-base, tipoGasto, esperado, evitável, forma-índice]
    final templateGastos = [
      ['Aluguel',          'Moradia',           1200.0, 'Fixo',    true,  false, 0],
      ['Condomínio',       'Moradia',             350.0, 'Fixo',    true,  false, 2],
      ['Internet',         'Assinaturas',         120.0, 'Fixo',    true,  false, 1],
      ['Netflix',          'Assinaturas',          45.0, 'Fixo',    true,  false, 1],
      ['Spotify',          'Assinaturas',          22.0, 'Fixo',    true,  false, 1],
      ['Energia elétrica', 'Moradia',             220.0, 'Fixo',    true,  false, 2],
      ['Supermercado',     'Mercado',             310.0, 'Variável',true,  false, 0],
      ['Supermercado',     'Mercado',             280.0, 'Variável',true,  false, 2],
      ['Feira',            'Mercado',             120.0, 'Variável',true,  false, 2],
      ['Restaurante',      'Alimentação',          95.0, 'Variável',false, true,  1],
      ['Lanche delivery',  'Alimentação',          55.0, 'Variável',false, true,  1],
      ['Combustível',      'Transporte',          180.0, 'Variável',true,  false, 0],
      ['Estacionamento',   'Transporte',           35.0, 'Variável',false, true,  2],
      ['Farmácia',         'Saúde',                70.0, 'Variável',true,  false, 0],
      ['Consulta médica',  'Saúde',               200.0, 'Variável',true,  false, 1],
      ['Academia',         'Saúde',               110.0, 'Fixo',    true,  false, 0],
      ['Cinema',           'Lazer',                80.0, 'Variável',false, true,  1],
      ['Bar / saída',      'Lazer',                90.0, 'Variável',false, true,  2],
      ['Roupas',           'Vestuário',           250.0, 'Variável',false, true,  1],
      ['Produtos higiene', 'Cuidados Pessoais',    65.0, 'Variável',true,  false, 2],
      ['Presente',         'Presentes',           120.0, 'Variável',false, false, 1],
      ['Curso online',     'Educação',            197.0, 'Variável',true,  false, 1],
      ['Outros gastos',    'Outros',               80.0, 'Variável',false, false, 2],
    ];

    // Template de receitas: [descrição, categoria, valor-base, tipo]
    final templateReceitas = [
      ['Salário',        'Salário',       5200.0, 'Fixo'],
      ['Freelance',      'Freelance',     1100.0, 'Variável'],
      ['Venda online',   'Outros',         350.0, 'Variável'],
    ];

    for (int mes = 2; mes >= 0; mes--) {
      final mesAlvo = agora.month - mes;
      final anoAlvo = mesAlvo <= 0 ? agora.year - 1 : agora.year;
      final mesReal = mesAlvo <= 0 ? mesAlvo + 12 : mesAlvo;

      // Distribui os gastos ao longo do mês (dias 1–28)
      int diaGasto = 1;
      for (final t in templateGastos) {
        final desc   = t[0] as String;
        final cat    = t[1] as String;
        final base   = t[2] as double;
        final tipo   = t[3] as String;
        final esp    = t[4] as bool;
        final evit   = t[5] as bool;
        final fIdx   = t[6] as int;
        final forma  = formas[fIdx % formas.length];
        final pessoa = pessoas[rng.nextInt(pessoas.length)];
        final data   = DateTime(anoAlvo, mesReal, diaGasto.clamp(1, 28));
        diaGasto += rng.nextInt(2) + 1;

        await gastosBox.add(Gasto(
          id: '${DateTime.now().microsecondsSinceEpoch}_${rng.nextInt(9999)}',
          descricao: desc,
          valor: v(base),
          categoria: cat,
          data: data,
          formaPagamento: forma,
          pessoa: pessoa,
          tipoGasto: tipo,
          parcelado: false,
          numeroParcelas: 1,
          estabelecimento: '',
          recorrente: tipo == 'Fixo',
          gastoEsperado: esp,
          gastoEvitavel: evit,
          detalhado: true,
        ));
      }

      // Receitas no dia 5 (salário) e dias variados
      int diaReceita = 5;
      for (final t in templateReceitas) {
        final desc  = t[0] as String;
        final cat   = t[1] as String;
        final base  = t[2] as double;
        final tipo  = t[3] as String;
        final pessoa = pessoas.first;
        final data  = DateTime(anoAlvo, mesReal, diaReceita.clamp(1, 28));
        diaReceita += 8;

        await receitasBox.add(Receita(
          id: '${DateTime.now().microsecondsSinceEpoch}_r${rng.nextInt(9999)}',
          descricao: desc,
          valor: v(base),
          categoria: cat,
          data: data,
          pessoa: pessoa,
          recorrente: tipo == 'Fixo',
          tipoReceita: tipo,
          detalhado: true,
        ));
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Massa de dados gerada: 3 meses de gastos e receitas.'),
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
          SwitchListTile(
            secondary: const Icon(Icons.widgets_outlined),
            title: const Text('Biometria no widget'),
            subtitle: const Text('Pedir biometria ou PIN ao usar o widget'),
            value: _bloqueioWidget,
            onChanged: _bloqueioAtivo
                ? (v) async {
                    await AuthService.setBloqueioWidget(v);
                    setState(() => _bloqueioWidget = v);
                  }
                : null,
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
          ListTile(
            leading: const Icon(Icons.science_outlined, color: Colors.teal),
            title: const Text('Gerar massa de dados'),
            subtitle: const Text('Insere gastos e receitas fictícios de 3 meses'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _gerarMassaDados,
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
            leading: const Icon(Icons.widgets_outlined),
            title: const Text('Adicionar widget'),
            subtitle: const Text('Adicione o atalho de gasto/receita na tela inicial'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              try {
                final channel = MethodChannel('com.example.controle_gastos/widget');
                final jaInstalado = await channel.invokeMethod<bool>('check_widget_installed') ?? false;
                if (jaInstalado && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('O widget já está instalado na tela inicial.')),
                  );
                  return;
                }
                final suportado = await channel.invokeMethod<bool>('pin_widget') ?? false;
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(suportado
                          ? 'Widget adicionado! Você pode arrastá-lo para o local desejado.'
                          : 'Seu dispositivo não suporta adição automática. Adicione manualmente pela tela inicial.'),
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
              } catch (_) {}
            },
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Ver tutorial'),
            subtitle: const Text('Revisitar as instruções de uso do app'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              FadeRoute(page: const OnboardingScreen(somenteTutorial: true)),
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
