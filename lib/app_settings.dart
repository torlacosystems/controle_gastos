import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(
  ThemeMode.system,
);

const _kRendaMensal = 'renda_mensal_familiar';

Future<double?> carregarRendaMensal() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.containsKey(_kRendaMensal) ? prefs.getDouble(_kRendaMensal) : null;
}

Future<void> salvarRendaMensal(double valor) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setDouble(_kRendaMensal, valor);
}

const _kTemaUsuario = 'tema_usuario'; // escolha do usuário: 'dark' | 'light'
const _kTemaCelularNaEscolha =
    'tema_celular_na_escolha'; // tema do celular quando o usuário escolheu

/// Carrega a preferência ao iniciar.
/// - Se o celular mudou de tema desde a última escolha do usuário → segue o celular (ThemeMode.system)
/// - Se o celular não mudou → aplica a escolha do usuário
Future<void> carregarTema(Brightness brightnessAtual) async {
  final prefs = await SharedPreferences.getInstance();

  final temaUsuario = prefs.getString(_kTemaUsuario);
  final temaCelularNaEscolha = prefs.getString(_kTemaCelularNaEscolha);

  // Nunca houve escolha do usuário → segue o sistema
  if (temaUsuario == null || temaCelularNaEscolha == null) {
    themeModeNotifier.value = ThemeMode.system;
    return;
  }

  final brightnessAtualStr = brightnessAtual == Brightness.dark
      ? 'dark'
      : 'light';

  // O celular mudou desde a última escolha → segue o sistema
  if (temaCelularNaEscolha != brightnessAtualStr) {
    await prefs.remove(_kTemaUsuario);
    await prefs.remove(_kTemaCelularNaEscolha);
    themeModeNotifier.value = ThemeMode.system;
    return;
  }

  // Celular não mudou → aplica a escolha do usuário
  themeModeNotifier.value = temaUsuario == 'dark'
      ? ThemeMode.dark
      : ThemeMode.light;
}

/// Salva a escolha do usuário junto com o tema atual do celular.
Future<void> salvarTema(bool isDark, Brightness brightnessAtual) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kTemaUsuario, isDark ? 'dark' : 'light');
  await prefs.setString(
    _kTemaCelularNaEscolha,
    brightnessAtual == Brightness.dark ? 'dark' : 'light',
  );
}
