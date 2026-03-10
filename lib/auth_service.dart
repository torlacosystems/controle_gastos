import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static final _auth = LocalAuthentication();

  static const _kBloqueioAtivo = 'bloqueio_ativo';
  static const _kBloqueioWidget = 'bloqueio_widget';

  /// True quando a biometria já foi validada nesta sessão (evita pedir duas vezes)
  static bool _sessaoAutenticada = false;
  static bool get sessaoAutenticada => _sessaoAutenticada;
  static void marcarSessaoAutenticada() => _sessaoAutenticada = true;

  /// Se o dispositivo suporta biometria ou PIN
  static Future<bool> get disponivel async {
    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// Se o usuário ativou o bloqueio
  static Future<bool> get bloqueioAtivo async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kBloqueioAtivo) ?? false;
  }

  /// Ativa ou desativa o bloqueio
  static Future<void> setBloqueio(bool ativo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kBloqueioAtivo, ativo);
    // Ao desativar o bloqueio principal, desativa o do widget também
    if (!ativo) await prefs.setBool(_kBloqueioWidget, false);
  }

  /// Se o usuário ativou o bloqueio no widget
  static Future<bool> get bloqueioWidgetAtivo async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kBloqueioWidget) ?? false;
  }

  /// Ativa ou desativa o bloqueio no widget
  static Future<void> setBloqueioWidget(bool ativo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kBloqueioWidget, ativo);
  }

  /// Autentica o usuário — biometria com fallback para PIN do dispositivo
  /// Retorna true se autenticado com sucesso
  static Future<bool> autenticar() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Autentique-se para acessar o Granix',
        options: const AuthenticationOptions(
          biometricOnly:
              false, // permite PIN/padrão do dispositivo como fallback
          stickyAuth: true, // mantém o prompt aberto se o app for minimizado
          useErrorDialogs: true,
        ),
      );
    } on PlatformException {
      return false;
    }
  }
}
