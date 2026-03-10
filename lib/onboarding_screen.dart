import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'setup_wizard_screen.dart';
import 'fade_route.dart';


class OnboardingScreen extends StatefulWidget {
  final bool somenteTutorial;
  const OnboardingScreen({super.key, this.somenteTutorial = false});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _pagina = 0;

  static const _paginas = [
    _PaginaData(
      icone: Icons.account_balance_wallet_outlined,
      titulo: 'Bem-vindo ao Granix',
      descricao:
          'Seu assistente inteligente para controle de gastos pessoais. Simples, rápido e completo.',
    ),
    _PaginaData(
      icone: Icons.add_circle_outline,
      titulo: 'Registre gastos e receitas',
      descricao:
          'Cadastre seus gastos e receitas com categoria, forma de pagamento e pessoa responsável. Suporte a parcelamentos.',
    ),
    _PaginaData(
      icone: Icons.dashboard_outlined,
      titulo: 'Acompanhe seu saldo',
      descricao:
          'Veja no resumo mensal quanto entrou, quanto saiu e qual é o seu saldo. Tudo atualizado em tempo real.',
    ),
    _PaginaData(
      icone: Icons.bar_chart_outlined,
      titulo: 'Relatórios e Insights',
      descricao:
          'Analise seus gastos por categoria, período e forma de pagamento. Receba insights automáticos sobre seus hábitos financeiros.',
    ),
    _PaginaData(
      icone: Icons.workspace_premium_outlined,
      titulo: '7 dias grátis, depois R\$9,90/mês',
      descricao:
          'Aproveite todos os recursos premium durante o período de teste. Relatórios, insights e backup incluídos.',
    ),
  ];

  // índice total = _paginas.length é a página do widget (apenas no primeiro uso)
  int get _totalPaginas => widget.somenteTutorial ? _paginas.length : _paginas.length + 1;
  bool get _naPaginaWidget => !widget.somenteTutorial && _pagina == _paginas.length;

  void _proximo() {
    if (_pagina < _paginas.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else if (_pagina == _paginas.length - 1) {
      if (widget.somenteTutorial) {
        _concluir();
      } else {
        _controller.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  Future<void> _concluir() async {
    if (widget.somenteTutorial) {
      if (mounted) Navigator.pop(context);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completo', true);
    if (mounted) {
      Navigator.pushReplacement(context, FadeRoute(page: const SetupWizardScreen()));
    }
  }

  Future<void> _adicionarWidget() async {
    try {
      const channel = MethodChannel('com.example.controle_gastos/widget');
      final jaInstalado = await channel.invokeMethod<bool>('check_widget_installed') ?? false;
      if (jaInstalado && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('O widget já está instalado na tela inicial.')),
        );
        await _concluir();
        return;
      }
      final suportado = await channel.invokeMethod<bool>('pin_widget') ?? false;
      if (mounted) {
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
    await _concluir();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme.primary;
    final ultimaNormal = _pagina == _paginas.length - 1;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Botão pular
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _concluir,
                child: Text('Pular', style: TextStyle(color: Colors.grey[500])),
              ),
            ),

            // Páginas
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _pagina = i),
                itemCount: _totalPaginas,
                itemBuilder: (context, i) {
                  if (i == _paginas.length) {
                    return _PaginaWidgetConvite(cor: cor);
                  }
                  return _PaginaWidget(dados: _paginas[i], cor: cor);
                },
              ),
            ),

            // Indicadores de página
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _totalPaginas,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _pagina ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _pagina ? cor : Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Botões — página do widget tem layout diferente
            if (_naPaginaWidget) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _adicionarWidget,
                    icon: const Icon(Icons.widgets_outlined),
                    label: const Text(
                      'Sim, adicionar widget',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _concluir,
                    child: Text(
                      'Agora não',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ),
                ),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _proximo,
                    child: Text(
                      ultimaNormal ? 'Próximo' : 'Próximo',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _PaginaWidgetConvite extends StatelessWidget {
  final Color cor;
  const _PaginaWidgetConvite({required this.cor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.widgets_outlined, size: 48, color: cor),
          ),
          const SizedBox(height: 36),
          const Text(
            'Adicione o widget na tela inicial',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            'Com o widget você registra um gasto ou receita diretamente da tela inicial, sem precisar abrir o app.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey[600], height: 1.6),
          ),
        ],
      ),
    );
  }
}

class _PaginaWidget extends StatelessWidget {
  final _PaginaData dados;
  final Color cor;

  const _PaginaWidget({required this.dados, required this.cor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(dados.icone, size: 48, color: cor),
          ),
          const SizedBox(height: 36),
          Text(
            dados.titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            dados.descricao,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[600],
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaginaData {
  final IconData icone;
  final String titulo;
  final String descricao;

  const _PaginaData({
    required this.icone,
    required this.titulo,
    required this.descricao,
  });
}
