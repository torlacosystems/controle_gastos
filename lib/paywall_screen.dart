import 'package:flutter/material.dart';
import 'subscription_service.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _processando = false;

  Future<void> _assinar() async {
    setState(() => _processando = true);
    try {
      final ok = await SubscriptionService.instance.subscribe();
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível iniciar a assinatura. Tente novamente.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  Future<void> _restaurar() async {
    setState(() => _processando = true);
    try {
      await SubscriptionService.instance.restorePurchases();
      // Aguarda um momento para o listener processar
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        if (SubscriptionService.instance.isSubscriptionActive) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Assinatura restaurada com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nenhuma assinatura ativa encontrada.'),
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = SubscriptionService.instance;
    final emTrial = service.isTrialActive;
    final diasRestantes = service.trialDaysRemaining;
    final cor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Botão fechar
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ),

              // Ícone premium
              const Icon(Icons.workspace_premium, size: 72, color: Colors.amber),
              const SizedBox(height: 16),

              // Título
              Text(
                emTrial && diasRestantes <= 3
                    ? 'Seu período de teste\nestá acabando!'
                    : 'Desbloqueie o\nControlaí Premium',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              if (emTrial && diasRestantes <= 3) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Text(
                    'Restam $diasRestantes dia${diasRestantes == 1 ? '' : 's'} de acesso completo',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.orange[800],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ] else if (emTrial) ...[
                const SizedBox(height: 8),
                Text(
                  'Você tem $diasRestantes dias de acesso gratuito',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                ),
              ],

              const SizedBox(height: 32),

              // Benefícios
              _beneficio(
                cor,
                Icons.bar_chart,
                'Relatórios completos',
                'Gráficos detalhados de gastos e receitas por período',
              ),
              _beneficio(
                cor,
                Icons.lightbulb,
                'Insights inteligentes',
                'Análises e dicas personalizadas para economizar mais',
              ),
              _beneficio(
                cor,
                Icons.people,
                'Múltiplas pessoas',
                'Controle gastos e receitas de toda a família',
              ),
              _beneficio(
                cor,
                Icons.category,
                'Categorias personalizadas',
                'Crie categorias adaptadas à sua rotina',
              ),
              _beneficio(
                cor,
                Icons.backup,
                'Backup dos dados',
                'Exporte e importe seus registros com segurança',
              ),

              const SizedBox(height: 32),

              // Preço
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cor.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    const Text('Apenas', style: TextStyle(fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(
                      'R\$ 9,90',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: cor,
                      ),
                    ),
                    const Text(
                      'por mês • Cancele quando quiser',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Botão assinar
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _processando ? null : _assinar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _processando
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Assinar Premium',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 12),

              // Restaurar assinatura
              TextButton(
                onPressed: _processando ? null : _restaurar,
                child: const Text('Restaurar assinatura'),
              ),

              // Continuar grátis
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Continuar com versão gratuita',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
              ),

              const SizedBox(height: 8),
              Text(
                'A assinatura é cobrada mensalmente pelo Google Play.\nO pagamento é processado pela sua conta Google.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[400], fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _beneficio(
    Color cor,
    IconData icone,
    String titulo,
    String descricao,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icone, color: cor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  descricao,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          ),
          Icon(Icons.check_circle, color: Colors.green[400], size: 20),
        ],
      ),
    );
  }
}
