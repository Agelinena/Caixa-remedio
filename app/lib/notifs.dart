// Lembretes agendados no próprio celular: tocam mesmo com o app fechado
// e mesmo longe da caixa.
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'util.dart';

class Notifs {
  static final FlutterLocalNotificationsPlugin _fln = FlutterLocalNotificationsPlugin();

  static const NotificationDetails _det = NotificationDetails(
    android: AndroidNotificationDetails(
      'doses',
      'Hora do remédio',
      channelDescription: 'Lembretes das doses da caixa de remédios',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
    ),
  );

  /// Agenda com horário exato; se o Android não permitir, agenda aproximado.
  static Future<void> _agenda(int id, String titulo, String texto, DateTime quando, {bool semanal = false}) async {
    for (final modo in [AndroidScheduleMode.exactAllowWhileIdle, AndroidScheduleMode.inexactAllowWhileIdle]) {
      try {
        await _fln.zonedSchedule(
          id,
          titulo,
          texto,
          tz.TZDateTime.from(quando, tz.UTC),
          _det,
          androidScheduleMode: modo,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: semanal ? DateTimeComponents.dayOfWeekAndTime : null,
        );
        return;
      } catch (_) {}
    }
  }

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      await _fln.initialize(
        const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      );
    } catch (_) {}
  }

  static Future<void> pedirPermissao() async {
    try {
      final a = _fln.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await a?.requestNotificationsPermission();
    } catch (_) {}
  }

  /// Apaga tudo e agenda de novo a partir da agenda atual.
  /// 100+dia = lembrete semanal na hora da dose.
  /// 200+dia = "já tomou?" depois da tolerância (só a próxima ocorrência).
  static Future<void> reagendar(Map<String, dynamic>? cfg, Map<String, dynamic>? estado) async {
    try {
      await _fln.cancelAll();
      if (cfg == null) return;
      final dias = (cfg['dias'] as List?) ?? const [];
      final tol = (cfg['tolerancia_min'] as num?)?.toInt() ?? 30;
      final agora = DateTime.now();
      final hojeIdx = agora.weekday % 7; // 0 = domingo
      for (var i = 0; i < 7 && i < dias.length; i++) {
        final d = Map<String, dynamic>.from(dias[i] as Map);
        if (d['ativo'] != true) continue;
        final hm = '${d['hora'] ?? '08:00'}'.split(':');
        final h = int.tryParse(hm[0]) ?? 8;
        final m = hm.length > 1 ? (int.tryParse(hm[1]) ?? 0) : 0;
        final delta = (i - hojeIdx + 7) % 7;
        final base = DateTime(agora.year, agora.month, agora.day, h, m).add(Duration(days: delta));
        final proxima = base.isAfter(agora) ? base : base.add(const Duration(days: 7));
        final rem = nomesRemedios(cfg, d);
        final texto = rem.isEmpty ? '${diasNomes[i]} às ${d['hora']}' : '${diasNomes[i]} às ${d['hora']}: $rem';

        await _agenda(100 + i, 'Hora do remédio', texto, proxima, semanal: true);

        final jaTomou = i == hojeIdx && estado != null && estado['status'] == 'tomada';
        final lembrete = base.add(Duration(minutes: tol));
        if (!jaTomou && lembrete.isAfter(agora)) {
          await _agenda(
            200 + i,
            'Você já tomou o remédio?',
            'O remédio de ${diasNomes[i].toLowerCase()} (${d['hora']}) ainda não foi retirado da caixa.',
            lembrete,
          );
        }
      }
    } catch (_) {}
  }

  static Future<void> cancelarLembreteDeHoje() async {
    try {
      await _fln.cancel(200 + DateTime.now().weekday % 7);
    } catch (_) {}
  }
}
