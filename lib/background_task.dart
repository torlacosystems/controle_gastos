import 'package:hive_flutter/hive_flutter.dart';
import 'package:workmanager/workmanager.dart';
import 'gasto.dart';
import 'notification_service.dart';

const taskLembreteGasto = 'lembrete_gasto_diario';

// Executado em background, fora do contexto do Flutter normal
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == taskLembreteGasto) {
      try {
        await Hive.initFlutter();

        // Registra apenas o adapter de Gasto (o mínimo necessário)
        if (!Hive.isAdapterRegistered(GastoAdapter().typeId)) {
          Hive.registerAdapter(GastoAdapter());
        }

        final box = await Hive.openBox<Gasto>('gastos');

        final hoje = DateTime.now();
        final temGastoHoje = box.values.any(
          (g) =>
              g.data.year == hoje.year &&
              g.data.month == hoje.month &&
              g.data.day == hoje.day,
        );

        if (!temGastoHoje) {
          await NotificationService.initialize();
          await NotificationService.mostrarNotificacaoSemRegistro();
        }

        await box.close();
      } catch (e) {
        // Falha silenciosa — não impede o app de funcionar
        return Future.value(false);
      }
    }
    return Future.value(true);
  });
}
