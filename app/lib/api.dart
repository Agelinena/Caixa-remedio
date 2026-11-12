// Comunicação com a caixa (API HTTP do ESP32 na rede Wi-Fi de casa).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const int portaApi = 8080;

class ApiException implements Exception {
  final int code;
  final String msg;
  ApiException(this.code, this.msg);
  @override
  String toString() => msg;
}

class BoxApi {
  final String host;
  final String token;
  BoxApi(this.host, this.token);

  static Future<dynamic> _chama(
    String metodo,
    String host,
    String caminho, {
    String token = '',
    Object? corpo,
    Map<String, String>? q,
    Duration limite = const Duration(seconds: 8),
  }) async {
    final uri = Uri(scheme: 'http', host: host, port: portaApi, path: caminho, queryParameters: q);
    final req = http.Request(metodo, uri);
    if (token.isNotEmpty) req.headers['X-Token'] = token;
    if (corpo != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(corpo);
    }
    final res = await http.Response.fromStream(await req.send().timeout(limite)).timeout(limite);
    final txt = utf8.decode(res.bodyBytes, allowMalformed: true);
    dynamic j;
    try {
      j = txt.isEmpty ? null : jsonDecode(txt);
    } catch (_) {
      j = null;
    }
    if (res.statusCode >= 400) {
      final m = (j is Map && j['erro'] != null) ? '${j['erro']}' : 'Erro ${res.statusCode}';
      throw ApiException(res.statusCode, m);
    }
    return j;
  }

  /// Pergunta "você é uma caixa de remédios?" para um endereço. Null se não for.
  static Future<Map<String, dynamic>?> sondar(String host, {int ms = 900}) async {
    try {
      final j = await _chama('GET', host, '/api/info', limite: Duration(milliseconds: ms));
      if (j is Map && j['caixa_remedios'] == true) {
        final m = Map<String, dynamic>.from(j);
        m['host'] = host;
        return m;
      }
    } catch (_) {}
    return null;
  }

  /// Procura caixas em todas as redes locais do celular.
  static Future<List<Map<String, dynamic>>> procurar(void Function(double) progresso) async {
    final prefixos = <String>{};
    try {
      final ifs = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false);
      for (final i in ifs) {
        for (final a in i.addresses) {
          final p = a.address.split('.');
          final local = a.address.startsWith('192.168.') || a.address.startsWith('10.') || a.address.startsWith('172.');
          if (p.length == 4 && local) prefixos.add('${p[0]}.${p[1]}.${p[2]}');
        }
      }
    } catch (_) {}
    final hosts = <String>[];
    for (final p in prefixos) {
      for (var n = 1; n < 255; n++) {
        hosts.add('$p.$n');
      }
    }
    final achadas = <Map<String, dynamic>>[];
    const lote = 48;
    for (var i = 0; i < hosts.length; i += lote) {
      final fim = (i + lote < hosts.length) ? i + lote : hosts.length;
      final r = await Future.wait(hosts.sublist(i, fim).map((h) => sondar(h)));
      for (final m in r) {
        if (m != null) achadas.add(m);
      }
      progresso(fim / hosts.length);
    }
    return achadas;
  }

  static Future<String> parear(String host) async {
    final j = await _chama('POST', host, '/api/parear');
    return '${(j as Map)['token']}';
  }

  Future<dynamic> _eu(String metodo, String caminho, {Object? corpo, Map<String, String>? q, int seg = 8}) =>
      _chama(metodo, host, caminho, token: token, corpo: corpo, q: q, limite: Duration(seconds: seg));

  Future<Map<String, dynamic>> estado() async => Map<String, dynamic>.from(await _eu('GET', '/api/estado', seg: 4) as Map);
  Future<Map<String, dynamic>> config() async => Map<String, dynamic>.from(await _eu('GET', '/api/config') as Map);
  Future<void> gravarConfig(Map<String, dynamic> c) async => _eu('PUT', '/api/config', corpo: c);
  Future<List<Map<String, dynamic>>> eventos({int limite = 200}) async {
    final j = await _eu('GET', '/api/eventos', q: {'limite': '$limite'}, seg: 12);
    return (j as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> silenciar() async => _eu('POST', '/api/silenciar');
  Future<void> tomei() async => _eu('POST', '/api/tomei');
  Future<void> reabastecer(int min) async => _eu('POST', '/api/reabastecer', corpo: {'min': min});
  Future<void> teste() async => _eu('POST', '/api/teste');
  Future<void> acertarHora() async =>
      _eu('POST', '/api/hora', corpo: {'epoch': DateTime.now().millisecondsSinceEpoch ~/ 1000});
  Future<void> telegramTeste(String tk, String chat) async =>
      _eu('POST', '/api/telegram/teste', corpo: {'token': tk, 'chat': chat}, seg: 20);
  Future<Map<String, dynamic>> telegramChat(String tk) async =>
      Map<String, dynamic>.from(await _eu('POST', '/api/telegram/chat', corpo: {'token': tk}, seg: 20) as Map);
}
