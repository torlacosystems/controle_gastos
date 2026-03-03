import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'gasto.dart';
import 'receita.dart';
import 'forma_pagamento.dart';
import 'pessoa.dart';
import 'orcamento.dart';
import 'backup_screen.dart';
import 'fade_route.dart';
import 'app_settings.dart';

class ConfiguracoesSistemaScreen extends StatefulWidget {
  const ConfiguracoesSistemaScreen({super.key});

  @override
  State<ConfiguracoesSistemaScreen> createState() =>
      _ConfiguracoesSistemaScreenState();
}

class _ConfiguracoesSistemaScreenState
    extends State<ConfiguracoesSistemaScreen> {
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
          _cabecalhoSecao('Aparência'),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeModeNotifier,
            builder: (context, themeMode, _) {
              return SwitchListTile(
                secondary: const Icon(Icons.dark_mode),
                title: const Text('Modo escuro'),
                subtitle: const Text('Ativar tema dark no app'),
                value: themeMode == ThemeMode.dark,
                onChanged: (v) {
                  themeModeNotifier.value = v
                      ? ThemeMode.dark
                      : ThemeMode.light;
                },
              );
            },
          ),
          const Divider(),

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
