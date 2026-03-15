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
      icone: Icons.tune,
      titulo: 'Configure antes de começar',
      descricao:
          'Em Configurações › Cadastro Inicial, defina suas formas de pagamento (débito, crédito, VA, VR…), pessoas e orçamentos mensais. Isso torna o registro muito mais rápido.',
    ),
    _PaginaData(
      icone: Icons.add_circle_outline,
      titulo: 'Registre um gasto',
      descricao:
          'Toque em "Novo Gasto" na tela inicial. Preencha o valor, descrição, categoria e forma de pagamento. Para compras parceladas, ative a opção de parcelamento e informe o número de parcelas.',
    ),
    _PaginaData(
      icone: Icons.south_west,
      titulo: 'Registre uma receita',
      descricao:
          'Toque em "Nova Receita" na tela inicial para lançar salário, freelance ou qualquer entrada. Informe o valor, descrição e, se quiser, a pessoa relacionada.',
    ),
    _PaginaData(
      icone: Icons.date_range,
      titulo: 'Gastos e Receitas por Datas',
      descricao:
          'Na tela de Gastos ou Receitas, use o botão "por Datas" para lançar vários registros de uma só vez em datas diferentes — ideal para organizar o mês inteiro rapidamente.',
    ),
    _PaginaData(
      icone: Icons.dashboard_outlined,
      titulo: 'Painel mensal',
      descricao:
          'A tela inicial mostra o resumo do mês atual: total de entradas, saídas e saldo. Acompanhe em tempo real quanto ainda tem disponível no mês.',
    ),
    _PaginaData(
      icone: Icons.receipt_long_outlined,
      titulo: 'Meus Gastos e Receitas',
      descricao:
          'Acesse a lista completa de gastos ou receitas pelo menu inferior. Toque em qualquer item para editar ou excluir. Use o filtro para ocultar registros já detalhados.',
    ),
    _PaginaData(
      icone: Icons.list_alt_outlined,
      titulo: 'Todos os Registros',
      descricao:
          'Visualize gastos e receitas juntos em uma só lista. Use a busca para localizar registros, selecione múltiplos itens para editar em massa, excluir em lote ou exporte os dados filtrados em CSV.',
    ),
    _PaginaData(
      icone: Icons.bar_chart_outlined,
      titulo: 'Relatórios e Gráficos',
      descricao:
          'Analise seus gastos por categoria, forma de pagamento e período. Os gráficos mostram onde seu dinheiro está indo e insights destacam os maiores gastos do mês.',
    ),
    _PaginaData(
      icone: Icons.savings_outlined,
      titulo: 'Orçamentos',
      descricao:
          'Defina um limite mensal por categoria ou geral. O app avisa quando você está se aproximando do teto, ajudando a manter o controle antes de extrapolar.',
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

            const SizedBox(height: 20),

            // Banner de privacidade
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline, size: 16, color: Colors.green),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Valorizamos sua privacidade. Todos os seus dados ficam armazenados apenas no seu dispositivo — ninguém tem acesso a eles.',
                        style: TextStyle(fontSize: 12, color: Colors.green, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

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
