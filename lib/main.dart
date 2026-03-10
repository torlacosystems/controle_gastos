import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'gasto.dart';
import 'receita.dart';
import 'forma_pagamento.dart';
import 'pessoa.dart';
import 'orcamento.dart';
import 'categoria.dart';
import 'configuracoes_sistema_screen.dart';
import 'todos_registros_screen.dart';
import 'meus_gastos_screen.dart';
import 'minhas_receitas_screen.dart';
import 'splash_screen.dart';
import 'onboarding_screen.dart';
import 'relatorios_screen.dart';
import 'insights_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'atualizar_parcelas_result.dart';
import 'fade_route.dart';
import 'app_settings.dart';
import 'lock_screen.dart';
import 'auth_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'subscription_service.dart';
import 'paywall_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(GastoAdapter());
  Hive.registerAdapter(ReceitaAdapter());
  Hive.registerAdapter(FormaPagamentoAdapter());
  Hive.registerAdapter(PessoaAdapter());
  Hive.registerAdapter(OrcamentoAdapter());
  Hive.registerAdapter(CategoriaAdapter());
  await Hive.openBox<Gasto>('gastos');
  await Hive.openBox<Receita>('receitas');
  await Hive.openBox<FormaPagamento>('formas_pagamento');
  await Hive.openBox<Pessoa>('pessoas');
  await Hive.openBox<Orcamento>('orcamentos');
  try {
    await Hive.openBox<Categoria>('categorias');
  } catch (e) {
    await Hive.deleteBoxFromDisk('categorias');
    await Hive.openBox<Categoria>('categorias');
  }
  await SubscriptionService.instance.initialize();
  final brightness =
      WidgetsBinding.instance.platformDispatcher.platformBrightness;
  await carregarTema(brightness);
  runApp(const MyApp());
}

/// Ação do widget capturada na SplashScreen antes do HomeScreen estar montado
String? widgetAcaoPendente;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'Granix',
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('pt', 'BR')],
          locale: const Locale('pt', 'BR'),
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          themeMode: themeMode,
          home: const LockScreen(child: _BootScreen()),
        );
      },
    );
  }
}
// ── BOOT ROUTER ───────────────────────────────────────────────────────────────
/// Tela inicial mínima: detecta ação do widget antes de qualquer UI visível.
/// - Se aberto pelo widget → vai direto para HomeScreen (sem splash)
/// - Caso contrário → exibe a SplashScreen normalmente
class _BootScreen extends StatefulWidget {
  const _BootScreen();

  @override
  State<_BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<_BootScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _rotear());
  }

  Future<void> _rotear() async {
    try {
      const channel = MethodChannel('com.example.controle_gastos/widget');
      final acao = await channel.invokeMethod<String?>('get_pending_action');
      if (acao != null && mounted) {
        widgetAcaoPendente = acao;
        final prefs = await SharedPreferences.getInstance();
        final onboardingCompleto = prefs.getBool('onboarding_completo') ?? false;
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => onboardingCompleto ? const HomeScreen() : const OnboardingScreen(),
          ),
        );
        return;
      }
    } catch (_) {}

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SplashScreen()),
    );
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(backgroundColor: Colors.white);
}

// ── HOME ──────────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Box<Gasto> _gastosBox;
  late Box<Receita> _receitasBox;
  late Box<FormaPagamento> _formasPagamentoBox;
  late Box<Pessoa> _pessoasBox;
  late Box<Orcamento> _orcamentosBox;
  double? _rendaMensal;
  final TextEditingController _buscaHomeController = TextEditingController();

  static final _widgetChannel = MethodChannel('com.example.controle_gastos/widget');

  @override
  void initState() {
    super.initState();
    _gastosBox = Hive.box<Gasto>('gastos');
    _receitasBox = Hive.box<Receita>('receitas');
    _formasPagamentoBox = Hive.box<FormaPagamento>('formas_pagamento');
    _pessoasBox = Hive.box<Pessoa>('pessoas');
    _orcamentosBox = Hive.box<Orcamento>('orcamentos');
    carregarRendaMensal().then((v) {
      if (mounted && v != null) setState(() => _rendaMensal = v);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final service = SubscriptionService.instance;
      if (!service.isTrialActive && !service.isSubscriptionActive) {
        Navigator.push(context, FadeRoute(page: const PaywallScreen()))
            .then((_) { if (mounted) setState(() {}); });
      }
    });
    _widgetChannel.setMethodCallHandler((call) async {
      if (call.method == 'novo_gasto' || call.method == 'nova_receita') {
        await _executarAcaoWidget(call.method);
      }
    });
    // Ação pendente capturada pela SplashScreen antes do HomeScreen montar
    if (widgetAcaoPendente != null) {
      final acao = widgetAcaoPendente!;
      widgetAcaoPendente = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _executarAcaoWidget(acao));
    }
  }

  Future<void> _executarAcaoWidget(String method) async {
    final bloqueado = await AuthService.bloqueioWidgetAtivo;
    if (bloqueado && !AuthService.sessaoAutenticada) {
      final ok = await AuthService.autenticar();
      if (!ok) return;
      AuthService.marcarSessaoAutenticada();
    }
    if (!mounted) return;
    final isGasto = method == 'novo_gasto';
    WidgetsBinding.instance.addPostFrameCallback((_) => isGasto
        ? _abrirQuickAddGasto(fromWidget: true)
        : _abrirQuickAddReceita(fromWidget: true));
  }

  @override
  void dispose() {
    _buscaHomeController.dispose();
    super.dispose();
  }

  double get _totalGastosMes {
    final agora = DateTime.now();
    return _gastosBox.values
        .where((g) => g.data.month == agora.month && g.data.year == agora.year)
        .fold(0, (soma, g) => soma + g.valor);
  }

  double get _totalReceitasMes {
    final agora = DateTime.now();
    return _receitasBox.values
        .where((r) => r.data.month == agora.month && r.data.year == agora.year)
        .fold(0, (soma, r) => soma + r.valor);
  }

  double get _saldo => _totalReceitasMes - _totalGastosMes;

  String _formatarValor(double valor) =>
      valor.toStringAsFixed(2).replaceAll('.', ',');

  double _gastosMesPorCategoria(String categoria) {
    final agora = DateTime.now();
    return _gastosBox.values
        .where((g) =>
            g.categoria == categoria &&
            g.data.month == agora.month &&
            g.data.year == agora.year)
        .fold(0, (s, g) => s + g.valor);
  }

  Widget _appBarAcao(IconData icone, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, color: Colors.white, size: 20),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  // limite == null → categoria sem orçamento configurado
  Widget _orcBarRow(String categoria, double gasto, double? limite) {
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
      padding: const EdgeInsets.only(bottom: 12),
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
                          height: 18,
                          color: Colors.blueGrey.shade200,
                        ),
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
                              height: 18,
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
                        height: 18,
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
                  'R\$ ${_formatarValor(gasto)}',
                  style: TextStyle(
                      fontSize: 10,
                      color: corPct,
                      fontWeight: FontWeight.w600),
                ),
                const Text(' / ',
                    style: TextStyle(fontSize: 10, color: Colors.grey)),
                Text(
                  semLimite ? 'sem limite' : 'R\$ ${_formatarValor(limite!)}',
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

  Widget _metaCard({
    required String titulo,
    required double valor,
    required double? meta,
    required IconData icone,
  }) {
    final ok = meta == null || valor <= meta;
    final cor = ok ? Colors.green[700]! : Colors.red[700]!;
    final bgCor = ok
        ? Colors.green.withValues(alpha: 0.08)
        : Colors.red.withValues(alpha: 0.08);
    final borderCor = ok
        ? Colors.green.withValues(alpha: 0.25)
        : Colors.red.withValues(alpha: 0.25);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgCor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderCor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icone, size: 14, color: cor),
              const SizedBox(width: 4),
              Text(titulo,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'R\$ ${_formatarValor(valor)}',
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold, color: cor),
          ),
          if (meta != null)
            Text(
              'Meta: R\$ ${_formatarValor(meta)}',
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            )
          else
            Text(
              'Meta: não configurada',
              style: TextStyle(fontSize: 10, color: Colors.grey[400]),
            ),
        ],
      ),
    );
  }

  bool get _cadastroCompleto =>
      _formasPagamentoBox.isNotEmpty && _pessoasBox.isNotEmpty;

  void _abrirQuickAddGasto({bool fromWidget = false}) {
    final valorCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom +
                MediaQuery.of(ctx).padding.bottom +
                16,
            top: 24,
            left: 24,
            right: 24,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Novo Gasto Rápido',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: valorCtrl,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Valor R\$',
                    prefixText: 'R\$ ',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Informe o valor';
                    final d = double.tryParse(v.replaceAll(',', '.'));
                    if (d == null || d <= 0) return 'Valor inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Descrição',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: () {
                          if (!formKey.currentState!.validate()) return;
                          final valor = double.parse(
                              valorCtrl.text.replaceAll(',', '.'));
                          final g = Gasto(
                            id: DateTime.now()
                                .millisecondsSinceEpoch
                                .toString(),
                            descricao: descCtrl.text,
                            valor: valor,
                            categoria: 'Outros',
                            data: DateTime.now(),
                            formaPagamento: '',
                            pessoa: '',
                            tipoGasto: 'Variável',
                            parcelado: false,
                            numeroParcelas: 1,
                            estabelecimento: '',
                            recorrente: false,
                            gastoEsperado: false,
                            detalhado: false,
                          );
                          _gastosBox.add(g);
                          Navigator.pop(ctx);
                          setState(() {});
                          if (fromWidget) SystemNavigator.pop();
                        },
                        child: const Text(
                          'Salvar e Detalhar Depois',
                          style: TextStyle(fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          final valor = double.parse(
                              valorCtrl.text.replaceAll(',', '.'));
                          final gTemp = Gasto(
                            id: DateTime.now()
                                .millisecondsSinceEpoch
                                .toString(),
                            descricao: descCtrl.text,
                            valor: valor,
                            categoria: 'Outros',
                            data: DateTime.now(),
                            formaPagamento: '',
                            pessoa: '',
                            tipoGasto: 'Variável',
                            parcelado: false,
                            numeroParcelas: 1,
                            estabelecimento: '',
                            recorrente: false,
                            gastoEsperado: false,
                            detalhado: false,
                          );
                          _gastosBox.add(gTemp);
                          final boxIndex = _gastosBox.length - 1;
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          await _abrirAdicionarGasto(
                              gasto: gTemp, index: boxIndex);
                        },
                        child: const Text(
                          'Detalhar Agora',
                          style: TextStyle(fontSize: 11),
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _abrirAdicionarGasto({Gasto? gasto, int? index}) async {
    if (!_cadastroCompleto) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cadastre ao menos uma forma de pagamento e uma pessoa nas Configurações Iniciais',
          ),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    final resultado = await Navigator.push(
      context,
      FadeRoute(page: AdicionarGastoScreen(gasto: gasto)),
    );
    if (resultado != null) {
      if (resultado is List<Gasto>) {
        for (final parcela in resultado) {
          await _gastosBox.add(parcela);
        }
      } else if (resultado is Gasto) {
        if (index != null) {
          await _gastosBox.putAt(index, resultado);
        } else {
          await _gastosBox.add(resultado);
        }
      } else if (resultado is AtualizarParcelasResult) {
        await _gastosBox.putAt(index!, resultado.gastoAtual);
        for (final entry in resultado.proximas) {
          await _gastosBox.putAt(entry.key, entry.value);
        }
      }
      setState(() {});
    }
  }

  Future<void> _abrirAdicionarReceita({Receita? receita, int? index}) async {
    if (!_cadastroCompleto) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cadastre ao menos uma forma de pagamento e uma pessoa nas Configurações Iniciais',
          ),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    final resultado = await Navigator.push<dynamic>(
      context,
      FadeRoute(page: AdicionarReceitaScreen(receita: receita)),
    );
    if (resultado != null) {
      if (resultado is List<Receita>) {
        for (final r in resultado) {
          await _receitasBox.add(r);
        }
      } else if (resultado is Receita) {
        if (index != null) {
          await _receitasBox.putAt(index, resultado);
        } else {
          await _receitasBox.add(resultado);
        }
      }
      setState(() {});
    }
  }

  void _abrirConfiguracoesSistema() async {
    await Navigator.push(
      context,
      FadeRoute(page: const ConfiguracoesSistemaScreen()),
    );
    final v = await carregarRendaMensal();
    if (mounted) setState(() => _rendaMensal = v);
  }

  void _abrirMeusGastos() async {
    await Navigator.push(context, FadeRoute(page: const MeusGastosScreen()));
    setState(() {});
  }

  void _abrirMinhasReceitas() async {
    await Navigator.push(
        context, FadeRoute(page: const MinhasReceitasScreen()));
    setState(() {});
  }

  void _abrirQuickAddReceita({bool fromWidget = false}) {
    final valorCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom +
                MediaQuery.of(ctx).padding.bottom +
                16,
            top: 24,
            left: 24,
            right: 24,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Nova Receita Rápida',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: valorCtrl,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Valor R\$',
                    prefixText: 'R\$ ',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Informe o valor';
                    final d = double.tryParse(v.replaceAll(',', '.'));
                    if (d == null || d <= 0) return 'Valor inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Descrição',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: () {
                          if (!formKey.currentState!.validate()) return;
                          final valor = double.parse(
                              valorCtrl.text.replaceAll(',', '.'));
                          final r = Receita(
                            id: DateTime.now()
                                .millisecondsSinceEpoch
                                .toString(),
                            descricao: descCtrl.text,
                            valor: valor,
                            categoria: 'Outros',
                            data: DateTime.now(),
                            pessoa: '',
                            recorrente: false,
                            tipoReceita: 'Variável',
                            detalhado: false,
                          );
                          _receitasBox.add(r);
                          Navigator.pop(ctx);
                          setState(() {});
                          if (fromWidget) SystemNavigator.pop();
                        },
                        child: const Text(
                          'Salvar e Detalhar Depois',
                          style: TextStyle(fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          final valor = double.parse(
                              valorCtrl.text.replaceAll(',', '.'));
                          final rTemp = Receita(
                            id: DateTime.now()
                                .millisecondsSinceEpoch
                                .toString(),
                            descricao: descCtrl.text,
                            valor: valor,
                            categoria: 'Outros',
                            data: DateTime.now(),
                            pessoa: '',
                            recorrente: false,
                            tipoReceita: 'Variável',
                            detalhado: false,
                          );
                          _receitasBox.add(rTemp);
                          final boxIndex = _receitasBox.length - 1;
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          await _abrirAdicionarReceita(
                              receita: rTemp, index: boxIndex);
                        },
                        child: const Text(
                          'Detalhar Agora',
                          style: TextStyle(fontSize: 11),
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _abrirTodosRegistros({String termoBusca = ''}) async {
    await Navigator.push(
      context,
      FadeRoute(page: TodosRegistrosScreen(termoBuscaInicial: termoBusca)),
    );
    _buscaHomeController.clear();
    setState(() {});
  }

  void _abrirRelatorios() async {
    if (!SubscriptionService.instance.isPremium) {
      await Navigator.push(context, FadeRoute(page: const PaywallScreen()));
      setState(() {});
      return;
    }
    await Navigator.push(context, FadeRoute(page: const RelatoriosScreen()));
  }

  void _abrirInsights() async {
    if (!SubscriptionService.instance.isPremium) {
      await Navigator.push(context, FadeRoute(page: const PaywallScreen()));
      setState(() {});
      return;
    }
    await Navigator.push(context, FadeRoute(page: const InsightsScreen()));
  }


  Map<String, double> get _graficoData {
    final agora = DateTime.now();
    final mapa = <String, double>{};
    for (final g in _gastosBox.values) {
      if (g.data.month == agora.month && g.data.year == agora.year) {
        mapa[g.categoria] = (mapa[g.categoria] ?? 0) + g.valor;
      }
    }
    // Ordenar por valor desc, manter só top 6
    final sorted = mapa.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted.take(6));
  }

  Widget _botaoNavegacao(IconData icone, String label, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 9),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.home, color: Colors.white),
            SizedBox(width: 8),
            Text('Home'),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          _appBarAcao(Icons.trending_down, 'Novo Gasto', _abrirQuickAddGasto),
          _appBarAcao(Icons.trending_up, 'Nova Receita', _abrirQuickAddReceita),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            tooltip: 'Configurações',
            onPressed: _abrirConfiguracoesSistema,
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _botaoNavegacao(
              Icons.receipt_long,
              'Meus Gastos',
              _abrirMeusGastos,
            ),
            _botaoNavegacao(
              Icons.attach_money,
              'Minhas Receitas',
              _abrirMinhasReceitas,
            ),
            _botaoNavegacao(
              Icons.list_alt,
              'Registros',
              () => _abrirTodosRegistros(),
            ),
            _botaoNavegacao(Icons.bar_chart, 'Relatórios', _abrirRelatorios),
            _botaoNavegacao(Icons.lightbulb, 'Insights', _abrirInsights),
          ],
        ),
      ),
      body: Column(
            children: [
              Container(
                width: double.infinity,
            padding: const EdgeInsets.all(24),
            color: Theme.of(context).colorScheme.primary,
            child: Column(
              children: [
                const Text(
                  'Total de Gastos do Mês',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  'R\$ ${_formatarValor(_totalGastosMes)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        const Text(
                          'Receitas',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        Text(
                          'R\$ ${_formatarValor(_totalReceitasMes)}',
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        const Text(
                          'Saldo',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        Text(
                          'R\$ ${_formatarValor(_saldo)}',
                          style: TextStyle(
                            color: _saldo >= 0
                                ? Colors.greenAccent
                                : Colors.redAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Builder(builder: (context) {
              final agora = DateTime.now();
              final diasNoMes = DateUtils.getDaysInMonth(agora.year, agora.month);
              final metaDiaria = _rendaMensal != null ? _rendaMensal! / diasNoMes : null;
              final hoje = DateTime(agora.year, agora.month, agora.day);
              final totalHoje = _gastosBox.values.where((g) {
                final d = DateTime(g.data.year, g.data.month, g.data.day);
                return d == hoje;
              }).fold(0.0, (s, g) => s + g.valor);
              final mediaDiaria = agora.day > 0 ? _totalGastosMes / agora.day : 0.0;
              return Row(
                children: [
                  // Card 1: Gasto do dia
                  Expanded(
                    child: _metaCard(
                      titulo: 'Gasto hoje',
                      valor: totalHoje,
                      meta: metaDiaria,
                      icone: Icons.today,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Card 2: Média diária acumulada
                  Expanded(
                    child: _metaCard(
                      titulo: 'Média diária',
                      valor: mediaDiaria,
                      meta: metaDiaria,
                      icone: Icons.show_chart,
                    ),
                  ),
                ],
              );
            }),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _buscaHomeController,
              decoration: InputDecoration(
                hintText: 'Buscar registros...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _buscaHomeController,
                  builder: (_, value, __) => value.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => _buscaHomeController.clear(),
                        )
                      : const SizedBox.shrink(),
                ),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onSubmitted: (termo) {
                if (termo.isNotEmpty) _abrirTodosRegistros(termoBusca: termo);
              },
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── GRÁFICO DE CATEGORIAS ──────────────────────────────
                  if (_graficoData.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Text(
                        'Gastos por Categoria',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 200,
                      child: Row(
                        children: [
                          Expanded(
                            child: PieChart(
                              PieChartData(
                                sections: _graficoData.entries.map((e) {
                                  final cores = [
                                    Colors.blue,
                                    Colors.red,
                                    Colors.orange,
                                    Colors.green,
                                    Colors.purple,
                                    Colors.teal,
                                    Colors.pink,
                                  ];
                                  final idx = _graficoData.keys
                                      .toList()
                                      .indexOf(e.key);
                                  return PieChartSectionData(
                                    value: e.value,
                                    color: cores[idx % cores.length],
                                    title: '',
                                    radius: 55,
                                  );
                                }).toList(),
                                centerSpaceRadius: 36,
                                sectionsSpace: 2,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: _graficoData.entries.map((e) {
                                  final cores = [
                                    Colors.blue,
                                    Colors.red,
                                    Colors.orange,
                                    Colors.green,
                                    Colors.purple,
                                    Colors.teal,
                                    Colors.pink,
                                  ];
                                  final idx = _graficoData.keys
                                      .toList()
                                      .indexOf(e.key);
                                  final pct = _totalGastosMes > 0
                                      ? (e.value / _totalGastosMes * 100)
                                            .toStringAsFixed(1)
                                      : '0';
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 3,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: cores[idx % cores.length],
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            '${e.key} $pct%',
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── ORÇAMENTO POR CATEGORIA ───────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Orçamento por Categoria',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () => _abrirRelatorios(),
                          child: const Text('Ver mais'),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Builder(builder: (ctx) {
                      final agora = DateTime.now();
                      final orcamentos = _orcamentosBox.values.toList()
                        ..sort((a, b) {
                            if (a.categoria == 'Outros') return 1;
                            if (b.categoria == 'Outros') return -1;
                            return a.categoria.compareTo(b.categoria);
                          });
                      final catsSemLimite = _gastosBox.values
                          .where((g) =>
                              g.data.month == agora.month &&
                              g.data.year == agora.year)
                          .map((g) => g.categoria)
                          .toSet()
                          .where((c) => !orcamentos.any((o) => o.categoria == c))
                          .toList()
                        ..sort((a, b) {
                            if (a == 'Outros') return 1;
                            if (b == 'Outros') return -1;
                            return a.compareTo(b);
                          });
                      if (orcamentos.isEmpty && catsSemLimite.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'Nenhum gasto ou orçamento este mês.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        );
                      }
                      return Column(
                        children: [
                          ...orcamentos.map((orc) => _orcBarRow(
                                orc.categoria,
                                _gastosMesPorCategoria(orc.categoria),
                                orc.limite,
                              )),
                          ...catsSemLimite.map((cat) => _orcBarRow(
                                cat,
                                _gastosMesPorCategoria(cat),
                                null,
                              )),
                        ],
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
            ],
          ),
    );
  }
}

// ── RESULTADO ATUALIZAR PARCELAS// ── RESULTADO ATUALIZAR PARCELAS ──────────────────────────────────────────────

// ── ADICIONAR GASTO ───────────────────────────────────────────────────────────

class AdicionarGastoScreen extends StatefulWidget {
  final Gasto? gasto;
  const AdicionarGastoScreen({super.key, this.gasto});

  @override
  State<AdicionarGastoScreen> createState() => _AdicionarGastoScreenState();
}

class _AdicionarGastoScreenState extends State<AdicionarGastoScreen> {
  late TextEditingController _valorController;
  late TextEditingController _descricaoController;
  late TextEditingController _estabelecimentoController;
  late String _categoriaSelecionada;
  late DateTime _dataSelecionada;
  FormaPagamento? _formaPagamentoSelecionada;
  Pessoa? _pessoaSelecionada;
  late String _tipoGasto;
  late bool _parcelado;
  late int _numeroParcelas;
  late bool _recorrente;
  late bool _gastoEsperado;
  late bool _gastoEvitavel;

  bool _formaPagamentoOrfa = false;
  bool _pessoaOrfa = false;

  late Box<FormaPagamento> _formasPagamentoBox;
  late Box<Pessoa> _pessoasBox;
  late Box<Gasto> _gastosBox;
  late Box<Categoria> _categoriasBox;

  static const List<Map<String, dynamic>> _categoriasFixas = [
    {'nome': 'Alimentação', 'icone': Icons.restaurant},
    {'nome': 'Mercado', 'icone': Icons.shopping_cart},
    {'nome': 'Transporte', 'icone': Icons.directions_car},
    {'nome': 'Saúde', 'icone': Icons.health_and_safety},
    {'nome': 'Lazer', 'icone': Icons.movie},
    {'nome': 'Moradia', 'icone': Icons.home},
    {'nome': 'Educação', 'icone': Icons.school},
    {'nome': 'Assinaturas', 'icone': Icons.subscriptions},
    {'nome': 'Outros', 'icone': Icons.category},
  ];

  List<Map<String, dynamic>> get _categorias {
    final fixasSemOutros =
        _categoriasFixas.where((c) => c['nome'] != 'Outros').toList();
    final outros = _categoriasFixas.firstWhere((c) => c['nome'] == 'Outros');
    final custom = _categoriasBox.values
        .map((c) => {'nome': c.nome, 'icone': c.icone})
        .toList();
    return [...fixasSemOutros, ...custom, outros];
  }

  @override
  void initState() {
    super.initState();
    _formasPagamentoBox = Hive.box<FormaPagamento>('formas_pagamento');
    _pessoasBox = Hive.box<Pessoa>('pessoas');
    _gastosBox = Hive.box<Gasto>('gastos');
    _categoriasBox = Hive.box<Categoria>('categorias');

    final g = widget.gasto;
    _valorController = TextEditingController(
      text: g != null ? g.valor.toStringAsFixed(2).replaceAll('.', ',') : '',
    );
    _descricaoController = TextEditingController(text: g?.descricao ?? '');
    _estabelecimentoController = TextEditingController(
      text: g?.estabelecimento ?? '',
    );
    _categoriaSelecionada = g?.categoria ?? 'Alimentação';
    _dataSelecionada = g?.data ?? DateTime.now();
    _tipoGasto = g?.tipoGasto ?? 'Variável';
    _parcelado = g?.parcelado ?? false;
    _numeroParcelas = g?.numeroParcelas ?? 2;
    _recorrente = g?.recorrente ?? false;
    _gastoEsperado = g?.gastoEsperado ?? true;
    _gastoEvitavel = g?.gastoEvitavel ?? false;

    final formas = _formasPagamentoBox.values.toList();
    if (g != null && g.formaPagamento.isNotEmpty) {
      final existe = formas.any((f) => f.descricao == g.formaPagamento);
      if (existe) {
        _formaPagamentoSelecionada = formas.firstWhere(
          (f) => f.descricao == g.formaPagamento,
        );
      } else {
        _formaPagamentoSelecionada = null;
        _formaPagamentoOrfa = true;
      }
    } else {
      _formaPagamentoSelecionada = formas.isNotEmpty ? formas.first : null;
    }

    final pessoas = _pessoasBox.values.toList()
      ..sort((a, b) {
        if (a.parentesco == 'Eu Mesmo') return -1;
        if (b.parentesco == 'Eu Mesmo') return 1;
        return a.nome.compareTo(b.nome);
      });
    if (g != null && g.pessoa.isNotEmpty) {
      final existe = pessoas.any((p) => p.nome == g.pessoa);
      if (existe) {
        _pessoaSelecionada = pessoas.firstWhere((p) => p.nome == g.pessoa);
      } else {
        _pessoaSelecionada = null;
        _pessoaOrfa = true;
      }
    } else {
      _pessoaSelecionada = pessoas.isNotEmpty ? pessoas.first : null;
    }
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

  String _formatarData(DateTime data) =>
      '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';

  Future<void> _selecionarData() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataSelecionada,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _dataSelecionada = picked);
  }

  List<MapEntry<int, Gasto>> _buscarProximasParcelas(
    String grupoId,
    int parcelaAtual,
  ) {
    final List<MapEntry<int, Gasto>> resultado = [];
    for (int i = 0; i < _gastosBox.length; i++) {
      final g = _gastosBox.getAt(i);
      if (g != null &&
          g.grupoId == grupoId &&
          g.grupoId.isNotEmpty &&
          g.numeroParcela > parcelaAtual) {
        resultado.add(MapEntry(i, g));
      }
    }
    resultado.sort(
      (a, b) => a.value.numeroParcela.compareTo(b.value.numeroParcela),
    );
    return resultado;
  }

  Future<void> _salvarGasto() async {
    String textoValor = _valorController.text.replaceAll('.', ',');
    if (!textoValor.contains(',')) textoValor = '$textoValor,00';
    final valor = double.tryParse(textoValor.replaceAll(',', '.'));

    if (valor == null || valor <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Informe um valor válido')));
      return;
    }

    final isEdicao = widget.gasto != null;

    if (_parcelado && !isEdicao) {
      final grupoId = DateTime.now().millisecondsSinceEpoch.toString();
      final valorParcela = valor / _numeroParcelas;
      final List<Gasto> parcelas = [];
      for (int i = 0; i < _numeroParcelas; i++) {
        parcelas.add(
          Gasto(
            id: '${grupoId}_$i',
            descricao:
                '${_descricaoController.text} (${i + 1}/$_numeroParcelas)',
            valor: double.parse(valorParcela.toStringAsFixed(2)),
            categoria: _categoriaSelecionada,
            data: DateTime(
              _dataSelecionada.year,
              _dataSelecionada.month + i,
              _dataSelecionada.day,
            ),
            formaPagamento: _formaPagamentoSelecionada!.descricao,
            pessoa: _pessoaSelecionada!.nome,
            tipoGasto: _tipoGasto,
            parcelado: true,
            numeroParcelas: _numeroParcelas,
            estabelecimento: _estabelecimentoController.text,
            recorrente: _recorrente,
            gastoEsperado: _gastoEsperado,
            gastoEvitavel: _gastoEvitavel,
            grupoId: grupoId,
            numeroParcela: i + 1,
          ),
        );
      }
      _mostrarSnackbarSucesso('Gasto salvo com sucesso!');
      await Future.delayed(const Duration(milliseconds: 300));
      Navigator.pop(context, parcelas);
      return;
    }

    if (isEdicao &&
        widget.gasto!.parcelado &&
        widget.gasto!.grupoId.isNotEmpty) {
      final gastoOriginal = widget.gasto!;
      final proximasParcelas = _buscarProximasParcelas(
        gastoOriginal.grupoId,
        gastoOriginal.numeroParcela,
      );

      final gastoAtualizado = Gasto(
        id: gastoOriginal.id,
        descricao: gastoOriginal.descricao,
        valor: valor,
        categoria: _categoriaSelecionada,
        data: _dataSelecionada,
        formaPagamento: _formaPagamentoSelecionada!.descricao,
        pessoa: _pessoaSelecionada!.nome,
        tipoGasto: _tipoGasto,
        parcelado: true,
        numeroParcelas: gastoOriginal.numeroParcelas,
        estabelecimento: _estabelecimentoController.text,
        recorrente: _recorrente,
        gastoEsperado: _gastoEsperado,
        gastoEvitavel: _gastoEvitavel,
        grupoId: gastoOriginal.grupoId,
        numeroParcela: gastoOriginal.numeroParcela,
      );

      if (proximasParcelas.isNotEmpty) {
        final escolha = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Editar parcelas'),
            content: Text(
              'Esta é a parcela ${gastoOriginal.numeroParcela} de ${gastoOriginal.numeroParcelas}.\n\n'
              'Deseja atualizar só esta parcela ou também as ${proximasParcelas.length} parcela(s) seguinte(s)?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'soEsta'),
                child: const Text('Só esta'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, 'estaEProximas'),
                child: Text('Esta e as próximas (${proximasParcelas.length})'),
              ),
            ],
          ),
        );

        if (escolha == null) return;

        if (escolha == 'estaEProximas') {
          final List<MapEntry<int, Gasto>> proximasAtualizadas = [];
          for (final entry in proximasParcelas) {
            final p = entry.value;
            proximasAtualizadas.add(
              MapEntry(
                entry.key,
                Gasto(
                  id: p.id,
                  descricao: p.descricao,
                  valor: valor,
                  categoria: _categoriaSelecionada,
                  data: p.data,
                  formaPagamento: _formaPagamentoSelecionada!.descricao,
                  pessoa: _pessoaSelecionada!.nome,
                  tipoGasto: _tipoGasto,
                  parcelado: true,
                  numeroParcelas: p.numeroParcelas,
                  estabelecimento: _estabelecimentoController.text,
                  recorrente: _recorrente,
                  gastoEsperado: _gastoEsperado,
                  gastoEvitavel: _gastoEvitavel,
                  grupoId: p.grupoId,
                  numeroParcela: p.numeroParcela,
                ),
              ),
            );
          }
          _mostrarSnackbarSucesso('Gasto atualizado com sucesso!');
          await Future.delayed(const Duration(milliseconds: 300));
          Navigator.pop(
            context,
            AtualizarParcelasResult(
              gastoAtual: gastoAtualizado,
              proximas: proximasAtualizadas,
            ),
          );
          return;
        }
      }

      _mostrarSnackbarSucesso('Gasto atualizado com sucesso!');
      await Future.delayed(const Duration(milliseconds: 300));
      Navigator.pop(context, gastoAtualizado);
      return;
    }

    final novoGasto = Gasto(
      id: widget.gasto?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      descricao: _descricaoController.text,
      valor: valor,
      categoria: _categoriaSelecionada,
      data: _dataSelecionada,
      formaPagamento: _formaPagamentoSelecionada!.descricao,
      pessoa: _pessoaSelecionada!.nome,
      tipoGasto: _tipoGasto,
      parcelado: false,
      numeroParcelas: 1,
      estabelecimento: _estabelecimentoController.text,
      recorrente: _recorrente,
      gastoEsperado: _gastoEsperado,
      gastoEvitavel: _gastoEvitavel,
    );

    if (_tipoGasto == 'Fixo' && _recorrente && !isEdicao) {
      int mesesSelecionados = 1;
      final confirmar = await showDialog<int>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            title: const Text('Replicar para próximos meses?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Este gasto é fixo e recorrente. Deseja criá-lo para os próximos meses?',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: mesesSelecionados > 1
                          ? () => setStateDialog(() => mesesSelecionados--)
                          : null,
                    ),
                    Column(
                      children: [
                        Text(
                          '$mesesSelecionados',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'meses',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: mesesSelecionados < 24
                          ? () => setStateDialog(() => mesesSelecionados++)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, 1),
                child: const Text('Só este mês'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, mesesSelecionados),
                child: Text(
                  'Replicar $mesesSelecionados ${mesesSelecionados == 1 ? 'mês' : 'meses'}',
                ),
              ),
            ],
          ),
        ),
      );

      if (confirmar != null && confirmar > 1) {
        final List<Gasto> gastosMeses = [];
        for (int i = 0; i < confirmar; i++) {
          gastosMeses.add(
            Gasto(
              id: '${DateTime.now().millisecondsSinceEpoch}_$i',
              descricao: novoGasto.descricao,
              valor: novoGasto.valor,
              categoria: novoGasto.categoria,
              data: DateTime(
                _dataSelecionada.year,
                _dataSelecionada.month + i,
                _dataSelecionada.day,
              ),
              formaPagamento: novoGasto.formaPagamento,
              pessoa: novoGasto.pessoa,
              tipoGasto: novoGasto.tipoGasto,
              parcelado: false,
              numeroParcelas: 1,
              estabelecimento: novoGasto.estabelecimento,
              recorrente: true,
              gastoEsperado: novoGasto.gastoEsperado,
            ),
          );
        }
        _mostrarSnackbarSucesso('Gasto salvo com sucesso!');
        await Future.delayed(const Duration(milliseconds: 300));
        Navigator.pop(context, gastosMeses);
        return;
      }
    }

    _mostrarSnackbarSucesso(
      isEdicao ? 'Gasto atualizado com sucesso!' : 'Gasto salvo com sucesso!',
    );
    await Future.delayed(const Duration(milliseconds: 300));
    Navigator.pop(context, novoGasto);
  }

  Widget _chipOpcao(String label, bool selecionado, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selecionado
              ? Theme.of(context).colorScheme.primary
              : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selecionado ? Colors.white : Colors.grey[700],
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _avisoOrfao(String mensagem) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        border: Border.all(color: Colors.orange),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Colors.orange, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mensagem,
              style: const TextStyle(fontSize: 13, color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formas = _formasPagamentoBox.values.toList();
    final pessoas = _pessoasBox.values.toList()
      ..sort((a, b) {
        if (a.parentesco == 'Eu Mesmo') return -1;
        if (b.parentesco == 'Eu Mesmo') return 1;
        return a.nome.compareTo(b.nome);
      });
    final podeSalvar = _formaPagamentoSelecionada != null &&
        _pessoaSelecionada != null &&
        _descricaoController.text.trim().isNotEmpty;

    final isEdicaoParcela = widget.gasto != null && widget.gasto!.parcelado;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(widget.gasto == null ? 'Novo Gasto' : 'Editar Gasto'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom +
                MediaQuery.of(context).padding.bottom +
                24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Valor (R\$)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _valorController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
                decoration: const InputDecoration(
                  hintText: '0,00',
                  border: OutlineInputBorder(),
                  prefixText: 'R\$ ',
                ),
                autofocus: true,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 24),

              const Text(
                'Categoria',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categorias.map((cat) {
                  final sel = cat['nome'] == _categoriaSelecionada;
                  return GestureDetector(
                    onTap: () =>
                        setState(() => _categoriaSelecionada = cat['nome']),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: sel
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            cat['icone'],
                            size: 18,
                            color: sel ? Colors.white : Colors.grey[700],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            cat['nome'],
                            style: TextStyle(
                              color: sel ? Colors.white : Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

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
                        'Tipo de Gasto',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _chipOpcao(
                            'Valor Fixo',
                            _tipoGasto == 'Fixo',
                            () => setState(() => _tipoGasto = 'Fixo'),
                          ),
                          const SizedBox(width: 8),
                          _chipOpcao(
                            'Valor Variável',
                            _tipoGasto == 'Variável',
                            () => setState(() => _tipoGasto = 'Variável'),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Recorrente',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Repete todo mês',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          Switch(
                            value: _recorrente,
                            onChanged: (v) => setState(() => _recorrente = v),
                          ),
                        ],
                      ),
                      const Divider(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Gasto Esperado',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Já estava previsto',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          Switch(
                            value: _gastoEsperado,
                            onChanged: (v) =>
                                setState(() => _gastoEsperado = v),
                          ),
                        ],
                      ),
                      const Divider(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Gasto Evitável',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Poderia ter sido evitado',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          Switch(
                            value: _gastoEvitavel,
                            onChanged: (v) =>
                                setState(() => _gastoEvitavel = v),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Forma de Pagamento',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (_formaPagamentoOrfa && _formaPagamentoSelecionada == null)
                _avisoOrfao(
                  'A forma de pagamento "${widget.gasto?.formaPagamento}" foi removida. Selecione uma nova.',
                ),
              DropdownButtonFormField<FormaPagamento>(
                initialValue: _formaPagamentoSelecionada,
                hint: const Text('Selecione a forma de pagamento'),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  enabledBorder:
                      _formaPagamentoOrfa && _formaPagamentoSelecionada == null
                      ? const OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.orange,
                            width: 2,
                          ),
                        )
                      : const OutlineInputBorder(),
                ),
                items: formas.map((forma) {
                  return DropdownMenuItem(
                    value: forma,
                    child: Text(
                      '${forma.descricao} • ${forma.tipo} • ${forma.banco}',
                    ),
                  );
                }).toList(),
                onChanged: (value) => setState(() {
                  _formaPagamentoSelecionada = value;
                  _formaPagamentoOrfa = false;
                }),
              ),
              const SizedBox(height: 24),

              if (!isEdicaoParcela) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Parcelado',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Switch(
                      value: _parcelado,
                      onChanged: (v) => setState(() => _parcelado = v),
                    ),
                  ],
                ),
                if (_parcelado) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text(
                        'Número de parcelas: ',
                        style: TextStyle(fontSize: 16),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: _numeroParcelas > 2
                            ? () => setState(() => _numeroParcelas--)
                            : null,
                      ),
                      Text(
                        '$_numeroParcelas',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: _numeroParcelas < 48
                            ? () => setState(() => _numeroParcelas++)
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _valorController.text.isNotEmpty
                        ? 'Valor por parcela: R\$ ${(() {
                            final v = double.tryParse(_valorController.text.replaceAll('.', '').replaceAll(',', '.'));
                            if (v == null) return '0,00';
                            return (v / _numeroParcelas).toStringAsFixed(2).replaceAll('.', ',');
                          })()}'
                        : 'Informe o valor para calcular a parcela',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 24),
              ],

              if (isEdicaoParcela) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    border: Border.all(color: Colors.blue),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.blue,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Parcela ${widget.gasto!.numeroParcela} de ${widget.gasto!.numeroParcelas}. '
                          'Você poderá atualizar só esta ou esta e as próximas ao salvar.',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Text(
                'Pessoa',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (_pessoaOrfa && _pessoaSelecionada == null)
                _avisoOrfao(
                  'A pessoa "${widget.gasto?.pessoa}" foi removida. Selecione uma nova.',
                ),
              DropdownButtonFormField<Pessoa>(
                initialValue: _pessoaSelecionada,
                hint: const Text('Selecione a pessoa'),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  enabledBorder: _pessoaOrfa && _pessoaSelecionada == null
                      ? const OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.orange,
                            width: 2,
                          ),
                        )
                      : const OutlineInputBorder(),
                ),
                items: pessoas.map((pessoa) {
                  return DropdownMenuItem(
                    value: pessoa,
                    child: Text('${pessoa.nome} • ${pessoa.parentesco}'),
                  );
                }).toList(),
                onChanged: (value) => setState(() {
                  _pessoaSelecionada = value;
                  _pessoaOrfa = false;
                }),
              ),
              const SizedBox(height: 24),

              const Text(
                'Estabelecimento (opcional)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _estabelecimentoController,
                decoration: const InputDecoration(
                  hintText: 'Ex: Supermercado Extra',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Data',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _selecionarData,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _formatarData(_dataSelecionada),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Descrição',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descricaoController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Ex: almoço no trabalho',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: podeSalvar ? _salvarGasto : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    widget.gasto == null ? 'Salvar Gasto' : 'Atualizar Gasto',
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
}

// ── ADICIONAR RECEITA ─────────────────────────────────────────────────────────

class AdicionarReceitaScreen extends StatefulWidget {
  final Receita? receita;
  const AdicionarReceitaScreen({super.key, this.receita});

  @override
  State<AdicionarReceitaScreen> createState() => _AdicionarReceitaScreenState();
}

class _AdicionarReceitaScreenState extends State<AdicionarReceitaScreen> {
  late TextEditingController _valorController;
  late TextEditingController _descricaoController;
  late String _categoriaSelecionada;
  late DateTime _dataSelecionada;
  late bool _recorrente;
  late String _tipoReceita;

  final List<Map<String, dynamic>> _categorias = [
    {'nome': 'Salário', 'icone': Icons.work},
    {'nome': 'Freelance', 'icone': Icons.computer},
    {'nome': 'Investimento', 'icone': Icons.trending_up},
    {'nome': 'Aluguel', 'icone': Icons.home},
    {'nome': 'Presente', 'icone': Icons.card_giftcard},
    {'nome': 'Benefício', 'icone': Icons.volunteer_activism},
    {'nome': 'Outros', 'icone': Icons.category},
  ];

  @override
  void initState() {
    super.initState();
    final r = widget.receita;
    _valorController = TextEditingController(
      text: r != null ? r.valor.toStringAsFixed(2).replaceAll('.', ',') : '',
    );
    _descricaoController = TextEditingController(text: r?.descricao ?? '');
    _categoriaSelecionada = r?.categoria ?? 'Salário';
    _dataSelecionada = r?.data ?? DateTime.now();
    _recorrente = r?.recorrente ?? false;
    _tipoReceita = r?.tipoReceita ?? 'Fixo';
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

  String _formatarData(DateTime data) =>
      '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';

  Future<void> _selecionarData() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataSelecionada,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _dataSelecionada = picked);
  }

  Widget _chipOpcao(String label, bool selecionado, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selecionado
              ? Theme.of(context).colorScheme.primary
              : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selecionado ? Colors.white : Colors.grey[700],
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Future<void> _salvarReceita() async {
    String textoValor = _valorController.text.replaceAll('.', ',');
    if (!textoValor.contains(',')) textoValor = '$textoValor,00';
    final valor = double.tryParse(textoValor.replaceAll(',', '.'));

    if (valor == null || valor <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Informe um valor válido')));
      return;
    }

    final isEdicao = widget.receita != null;

    final novaReceita = Receita(
      id:
          widget.receita?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      descricao: _descricaoController.text,
      valor: valor,
      categoria: _categoriaSelecionada,
      data: _dataSelecionada,
      pessoa: '',
      recorrente: _recorrente,
      tipoReceita: _tipoReceita,
      detalhado: true,
    );

    if (_tipoReceita == 'Fixo' && _recorrente && !isEdicao) {
      int mesesSelecionados = 1;
      final confirmar = await showDialog<int>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            title: const Text('Replicar para próximos meses?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Esta receita é fixa e recorrente. Deseja criá-la para os próximos meses?',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: mesesSelecionados > 1
                          ? () => setStateDialog(() => mesesSelecionados--)
                          : null,
                    ),
                    Column(
                      children: [
                        Text(
                          '$mesesSelecionados',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'meses',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: mesesSelecionados < 24
                          ? () => setStateDialog(() => mesesSelecionados++)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, 1),
                child: const Text('Só este mês'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, mesesSelecionados),
                child: Text(
                  'Replicar $mesesSelecionados ${mesesSelecionados == 1 ? 'mês' : 'meses'}',
                ),
              ),
            ],
          ),
        ),
      );

      if (confirmar != null && confirmar > 1) {
        final List<Receita> receitasMeses = [];
        for (int i = 0; i < confirmar; i++) {
          receitasMeses.add(
            Receita(
              id: '${DateTime.now().millisecondsSinceEpoch}_$i',
              descricao: novaReceita.descricao,
              valor: novaReceita.valor,
              categoria: novaReceita.categoria,
              data: DateTime(
                _dataSelecionada.year,
                _dataSelecionada.month + i,
                _dataSelecionada.day,
              ),
              pessoa: novaReceita.pessoa,
              recorrente: true,
              tipoReceita: novaReceita.tipoReceita,
              detalhado: true,
            ),
          );
        }
        _mostrarSnackbarSucesso('Receita salva com sucesso!');
        await Future.delayed(const Duration(milliseconds: 300));
        Navigator.pop(context, receitasMeses);
        return;
      }
    }

    _mostrarSnackbarSucesso(
      isEdicao
          ? 'Receita atualizada com sucesso!'
          : 'Receita salva com sucesso!',
    );
    await Future.delayed(const Duration(milliseconds: 300));
    Navigator.pop(context, novaReceita);
  }

  @override
  Widget build(BuildContext context) {
    final podeSalvar = _descricaoController.text.trim().isNotEmpty;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(widget.receita == null ? 'Nova Receita' : 'Editar Receita'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom +
                MediaQuery.of(context).padding.bottom +
                24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Valor (R\$)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _valorController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
                decoration: const InputDecoration(
                  hintText: '0,00',
                  border: OutlineInputBorder(),
                  prefixText: 'R\$ ',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 24),

              const Text(
                'Categoria',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categorias.map((cat) {
                  final sel = cat['nome'] == _categoriaSelecionada;
                  return GestureDetector(
                    onTap: () =>
                        setState(() => _categoriaSelecionada = cat['nome']),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: sel
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            cat['icone'],
                            size: 18,
                            color: sel ? Colors.white : Colors.grey[700],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            cat['nome'],
                            style: TextStyle(
                              color: sel ? Colors.white : Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

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
                        'Tipo de Receita',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _chipOpcao(
                            'Fixa',
                            _tipoReceita == 'Fixo',
                            () => setState(() => _tipoReceita = 'Fixo'),
                          ),
                          const SizedBox(width: 8),
                          _chipOpcao(
                            'Variável',
                            _tipoReceita == 'Variável',
                            () => setState(() => _tipoReceita = 'Variável'),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Recorrente',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Repete todo mês',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          Switch(
                            value: _recorrente,
                            onChanged: (v) => setState(() => _recorrente = v),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Data',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _selecionarData,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _formatarData(_dataSelecionada),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Descrição',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descricaoController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Ex: salário mensal',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: podeSalvar ? _salvarReceita : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    widget.receita == null
                        ? 'Salvar Receita'
                        : 'Atualizar Receita',
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
}
