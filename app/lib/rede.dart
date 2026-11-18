// Prende o app ao Wi-Fi enquanto ele fala com a rede da caixa (que não tem
// internet). Sem isso o Android manda o tráfego pelos dados móveis.
// O código nativo está em android_extra/.../MainActivity.kt.
import 'package:flutter/services.dart';

class Rede {
  static const _canal = MethodChannel('caixa/rede');

  static Future<bool> usarWifi() async {
    try {
      return await _canal.invokeMethod<bool>('usarWifi') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> liberar() async {
    try {
      await _canal.invokeMethod('liberar');
    } catch (_) {}
  }
}
