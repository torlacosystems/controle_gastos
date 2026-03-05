import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'gasto.dart';
import 'receita.dart';
import 'forma_pagamento.dart';
import 'pessoa.dart';
import 'orcamento.dart';
import 'backup_screen.dart';
import 'fade_route.dart';
import 'app_settings.dart';
import 'background_task.dart';
import 'notification_service.dart';
import 'auth_service.dart';

class ConfiguracoesSistemaScreen extends StatefulWidget {
  const ConfiguracoesSistemaScreen({super.key});

  @override
  State<ConfiguracoesSistemaScreen> createState() =>
      _ConfiguracoesSistemaScreenState();
}

class _ConfiguracoesSistemaScreenState
    extends State<ConfiguracoesSistemaScreen> {
  bool _lembreteAtivo = false;
  TimeOfDay _horarioLembrete = const TimeOfDay(hour: 21, minute: 0);
  bool _bloqueioAtivo = false;

  static const _kLembreteAtivo = 'lembrete_ativo';
  static const _kLembreteHora = 'lembrete_hora';
  static const _kLembreteMinuto = 'lembrete_minuto';

  @override
  void initState() {
    super.initState();
    _carregarConfiguracoes();
    _carregarBloqueio();
  }

  Future<void> _carregarConfiguracoes() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lembreteAtivo = prefs.getBool(_kLembreteAtivo) ?? false;
      final hora = prefs.getInt(_kLembreteHora) ?? 21;
      final minuto = prefs.getInt(_kLembreteMinuto) ?? 0;
      _horarioLembrete = TimeOfDay(hour: hora, minute: minuto);
    });
  }

  Future<void> _carregarBloqueio() async {
    final ativo = await AuthService.bloqueioAtivo;
    if (mounted) setState(() => _bloqueioAtivo = ativo);
  }

  Future<void> _salvarConfiguracoes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kLembreteAtivo, _lembreteAtivo);
    await prefs.setInt(_kLembreteHora, _horarioLembrete.hour);
    await prefs.setInt(_kLembreteMinuto, _horarioLembrete.minute);
  }

  Future<void> _toggleLembrete(bool ativo) async {
    setState(() => _lembreteAtivo = ativo);
    await _salvarConfiguracoes();

    if (ativo) {
      await _agendarLembrete();
      if (mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Lembrete ativado!'),
            content: const Text(
              'Para garantir que o lembrete funcione corretamente, desative a otimização de bateria para este app nas configurações do Android.\n\nCaminho: Configurações → Aplicativos → Controle de Gastos → Bateria → Sem restrições.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Entendi'),
              ),
            ],
          ),
        );
      }
    } else {
      await Workmanager().cancelByUniqueName(taskLembreteGasto);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Lembrete desativado.')));
      }
    }
  }

  Future<void> _agendarLembrete() async {
    await Workmanager().cancelByUniqueName(taskLembreteGasto);

    final agora = DateTime.now();
    var alvo = DateTime(
      agora.year,
      agora.month,
      agora.day,
      _horarioLembrete.hour,
      _horarioLembrete.minute,
    );
    if (agora.isAfter(alvo)) {
      alvo = alvo.add(const Duration(days: 1));
    }
    final delay = alvo.difference(agora);

    await Workmanager().registerPeriodicTask(
      taskLembreteGasto,
      taskLembreteGasto,
      frequency: const Duration(hours: 24),
      initialDelay: delay,
      constraints: Constraints(networkType: NetworkType.notRequired),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    );
  }

  Future<void> _escolherHorario() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _horarioLembrete,
      helpText: 'Horário do lembrete diário',
    );
    if (picked == null) return;

    setState(() => _horarioLembrete = picked);
    await _salvarConfiguracoes();

    if (_lembreteAtivo) {
      await _agendarLembrete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Lembrete reagendado para ${picked.format(context)}.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
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
          _cabecalhoSecao('Segurança'),
          SwitchListTile(
            secondary: const Icon(Icons.lock_outline),
            title: const Text('Bloquear app'),
            subtitle: const Text('Pedir biometria ou PIN ao abrir o app'),
            value: _bloqueioAtivo,
            onChanged: _toggleBloqueio,
          ),
          const Divider(),

          // ── NOTIFICAÇÕES ────────────────────────────────────────────────
          _cabecalhoSecao('Notificações'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('Lembrete diário'),
            subtitle: const Text(
              'Notificar se nenhum gasto for registrado no dia',
            ),
            value: _lembreteAtivo,
            onChanged: _toggleLembrete,
          ),
          if (_lembreteAtivo) ...[
            ListTile(
              leading: const Icon(Icons.access_time),
              title: const Text('Horário do lembrete'),
              subtitle: Text(_horarioLembrete.format(context)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _escolherHorario,
            ),
            ListTile(
              leading: const Icon(
                Icons.notifications_active_outlined,
                color: Colors.orange,
              ),
              title: const Text('Testar notificação agora'),
              subtitle: const Text('Dispara o lembrete imediatamente'),
              onTap: () async {
                await NotificationService.mostrarNotificacaoSemRegistro();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Notificação enviada!'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
            ),
          ],
          const Divider(),

          // ── DADOS ────────────────────────────────────────────────────────
          _cabecalhoSecao('Dados'),
          ListTile(
            leading: const Icon(Icons.backup),
            title: const Text('Exportar backup'),
            subtitle: const Text('Salvar ou compartilhar seus dados'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                Navigator.push(context, FadeRoute(page: const BackupScreen())),
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
