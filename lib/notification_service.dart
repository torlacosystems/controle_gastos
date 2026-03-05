import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(initSettings);
  }

  static Future<void> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestNotificationsPermission();
  }

  static Future<void> mostrarNotificacaoSemRegistro() async {
    const androidDetails = AndroidNotificationDetails(
      'lembrete_gasto',
      'Lembrete de Gastos',
      channelDescription: 'Notificação diária para registrar seus gastos',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(
      0,
      '💰 Sem registros hoje!',
      'Você ainda não registrou nenhum gasto hoje. Toque para registrar.',
      details,
    );
  }
}
