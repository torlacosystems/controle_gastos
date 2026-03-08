import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static final _auth = LocalAuthentication();

  static const _kBloqueioAtivo = 'bloqueio_ativo';

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
  }

  /// Autentica o usuário — biometria com fallback para PIN do dispositivo
  /// Retorna true se autenticado com sucesso
  static Future<bool> autenticar() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Autentique-se para acessar o Controlaí',
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
