// Estado do app: conexão com a caixa, agenda (com cópia guardada no celular),
// estado atual e histórico.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'notifs.dart';

class Store extends ChangeNotifier {
  Store._();
  static final Store I = Store._();

  late SharedPreferences _p;
  String host = '';
  String token = '';
  String caixaId = '';
  Map<String, dynamic>? config;
  Map<String, dynamic>? estado;
  List<Map<String, dynamic>> eventos = [];
  bool online = false;
  int _falhas = 0;
  DateTime _ultimaBusca = DateTime.fromMillisecondsSinceEpoch(0);
  String? _statusAnterior;

  bool get pareado => host.isNotEmpty && token.isNotEmpty;
  BoxApi get api => BoxApi(host, token);

  Future<void> carregar() async {
    _p = await SharedPreferences.getInstance();
    host = _p.getString('host') ?? '';
    token = _p.getString('token') ?? '';
    caixaId = _p.getString('caixaId') ?? '';
    final c = _p.getString('config');
    if (c != null) {
      try {
        config = Map<String, dynamic>.from(jsonDecode(c) as Map);
      } catch (_) {}
    }
  }

  Future<void> salvarConexao(String h, String t, String id) async {
    host = h;
    token = t;
    caixaId = id;
    await _p.setString('host', h);
    await _p.setString('token', t);
    await _p.setString('caixaId', id);
    notifyListeners();
    await carregarTudo();
  }

  Future<void> desconectar() async {
    host = token = caixaId = '';
    config = null;
    estado = null;
    eventos = [];
    online = false;
    await _p.remove('host');
    await _p.remove('token');
    await _p.remove('caixaId');
    await _p.remove('config');
    await Notifs.reagendar(null, null);
    notifyListeners();
  }

  /// Chamado a cada poucos segundos enquanto o app está aberto.
  Future<void> atualizarEstado() async {
    if (!pareado) return;
    try {
      estado = await api.estado();
      online = true;
      _falhas = 0;
      final s = '${estado!['status']}';
      if (_statusAnterior != null && _statusAnterior != s) {
        if (s == 'tomada') await Notifs.cancelarLembreteDeHoje();
        carregarEventos();
      }
      _statusAnterior = s;
    } catch (_) {
      online = false;
      _falhas++;
      // O endereço da caixa pode ter mudado: procura de novo, no máximo 1 vez por minuto.
      if (_falhas >= 4 && DateTime.now().difference(_ultimaBusca).inSeconds > 60) {
        _ultimaBusca = DateTime.now();
        reencontrar();
      }
    }
    notifyListeners();
  }

  Future<bool> reencontrar() async {
    final r = await BoxApi.procurar((_) {});
    for (final m in r) {
      if (m['host'] == ipRedeCaixa) continue; // rede de configuração da caixa, não é endereço fixo
      if (caixaId.isEmpty || '${m['id']}' == caixaId) {
        host = '${m['host']}';
        await _p.setString('host', host);
        _falhas = 0;
        notifyListeners();
        return true;
      }
    }
    return false;
  }

  Future<void> carregarTudo() async {
    if (!pareado) return;
    try {
      estado = await api.estado();
      online = true;
      final c = await api.config();
      config = c;
      await _p.setString('config', jsonEncode(c));
      await carregarEventos();
    } catch (_) {
      online = false;
    }
    await Notifs.reagendar(config, estado);
    notifyListeners();
  }

  Future<void> carregarEventos() async {
    try {
      eventos = await api.eventos();
      notifyListeners();
    } catch (_) {}
  }

  /// Grava a agenda/ajustes na caixa e reagenda os lembretes do celular.
  Future<void> gravarConfig(Map<String, dynamic> c) async {
    await api.gravarConfig(c);
    config = c;
    await _p.setString('config', jsonEncode(c));
    try {
      estado = await api.estado();
    } catch (_) {}
    await Notifs.reagendar(config, estado);
    notifyListeners();
  }
}
