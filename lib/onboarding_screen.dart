import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';
import 'fade_route.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _pagina = 0;

  static const _paginas = [
    _PaginaData(
      icone: Icons.account_balance_wallet_outlined,
      titulo: 'Bem-vindo ao Controlaí',
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

  void _proximo() {
    if (_pagina < _paginas.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _concluir();
    }
  }

  Future<void> _concluir() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completo', true);
    if (mounted) {
      Navigator.pushReplacement(context, FadeRoute(page: const HomeScreen()));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme.primary;
    final ultima = _pagina == _paginas.length - 1;

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
                itemCount: _paginas.length,
                itemBuilder: (context, i) => _PaginaWidget(
                  dados: _paginas[i],
                  cor: cor,
                ),
              ),
            ),

            // Indicadores de página
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _paginas.length,
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

            // Botão avançar / começar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _proximo,
                  child: Text(
                    ultima ? 'Começar' : 'Próximo',
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
