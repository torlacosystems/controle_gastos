import 'package:flutter/material.dart';
import 'auth_service.dart';

class LockScreen extends StatefulWidget {
  final Widget child;

  const LockScreen({super.key, required this.child});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> with WidgetsBindingObserver {
  bool _bloqueado = false;
  bool _verificando = true;
  bool _erro = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _inicializar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _inicializar() async {
    final ativo = await AuthService.bloqueioAtivo;
    if (!ativo) {
      if (mounted) setState(() { _bloqueado = false; _verificando = false; });
      return;
    }

    // Se aberto pelo widget e bloqueio de widget está desativado, pula autenticação
    if (AuthService.abertoPeloWidget) {
      final bloqueioWidget = await AuthService.bloqueioWidgetAtivo;
      if (!bloqueioWidget) {
        if (mounted) setState(() { _bloqueado = false; _verificando = false; });
        return;
      }
    }

    // Pede a biometria imediatamente, antes de mostrar qualquer tela
    final sucesso = await AuthService.autenticar();
    if (!mounted) return;

    if (sucesso) {
      AuthService.marcarSessaoAutenticada();
      setState(() { _bloqueado = false; _verificando = false; });
    } else {
      // Falhou: mostra a tela de bloqueio com botão para tentar novamente
      setState(() { _bloqueado = true; _verificando = false; _erro = true; });
    }
  }

  Future<void> _autenticar() async {
    setState(() => _erro = false);
    final sucesso = await AuthService.autenticar();
    if (!mounted) return;
    if (sucesso) {
      AuthService.marcarSessaoAutenticada();
      setState(() => _bloqueado = false);
    } else {
      setState(() => _erro = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_verificando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_bloqueado) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 72,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Granix',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Controle de Gastos',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Autentique-se para continuar',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                  ),
                  const SizedBox(height: 40),
                  if (_erro)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Autenticação falhou. Tente novamente.',
                        style: TextStyle(color: Colors.red[600], fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  FilledButton.icon(
                    onPressed: _autenticar,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Autenticar'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(200, 48),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}
