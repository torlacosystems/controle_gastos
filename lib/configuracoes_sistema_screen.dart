import 'package:flutter/material.dart';
import 'app_settings.dart';

class ConfiguracoesSistemaScreen extends StatefulWidget {
  const ConfiguracoesSistemaScreen({super.key});

  @override
  State<ConfiguracoesSistemaScreen> createState() =>
      _ConfiguracoesSistemaScreenState();
}

class _ConfiguracoesSistemaScreenState
    extends State<ConfiguracoesSistemaScreen> {
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
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              'Aparência',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 0.5,
              ),
            ),
          ),
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
        ],
      ),
    );
  }
}
