// Configura o Wi-Fi da casa na caixa, com o celular conectado na rede da
// própria caixa ("CaixaRemedios-XXXX"). Nada de página no navegador.
//
// Fluxo: lista as redes que a caixa enxerga -> pessoa escolhe e digita a senha
// -> caixa testa a senha (só salva se conectar) -> celular volta para o Wi-Fi
// de casa -> app acha a caixa pelo id e termina a conexão.
import 'dart:async';

import 'package:flutter/material.dart';

import 'api.dart';
import 'rede.dart';
import 'store.dart';

enum _Fase { redes, conectando, pronto, semContato }

class TelaWifi extends StatefulWidget {
  final String host;
  final String token;
  final String caixaId;
  const TelaWifi({super.key, required this.host, required this.token, required this.caixaId});

  @override
  State<TelaWifi> createState() => _TelaWifiState();
}

class _TelaWifiState extends State<TelaWifi> {
  _Fase _fase = _Fase.redes;
  bool _carregando = false;
  bool _verSenha = false;
  bool _terminando = false;
  List<Map<String, dynamic>> _redes = [];
  String? _escolhida;
  String? _msg;
  String? _ipNovo;
  final _senha = TextEditingController();
  final _outra = TextEditingController();

  @override
  void initState() {
    super.initState();
    Rede.usarWifi();
    _carregarRedes();
  }

  @override
  void dispose() {
    _senha.dispose();
    _outra.dispose();
    Rede.liberar();
    super.dispose();
  }

  Future<void> _carregarRedes() async {
    setState(() {
      _carregando = true;
      _msg = null;
    });
    try {
      final r = await BoxApi.redesWifi(widget.host, widget.token);
      if (!mounted) return;
      setState(() => _redes = r);
      if (r.isEmpty) setState(() => _msg = 'A caixa não encontrou nenhuma rede. Toque em "Procurar de novo".');
    } catch (_) {
      if (!mounted) return;
      setState(() => _msg = 'Não consegui falar com a caixa. Confira se o celular continua na rede "CaixaRemedios-...".');
    }
    if (mounted) setState(() => _carregando = false);
  }

  String get _ssid => _escolhida == '' ? _outra.text.trim() : (_escolhida ?? '');

  Future<void> _enviar() async {
    final ssid = _ssid;
    if (ssid.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _fase = _Fase.conectando;
      _msg = null;
    });
    try {
      await BoxApi.enviarWifi(widget.host, widget.token, ssid, _senha.text);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _fase = _Fase.redes;
        _msg = e.msg;
      });
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _fase = _Fase.redes;
        _msg = 'Não consegui falar com a caixa.';
      });
      return;
    }

    // A caixa leva até ~20 s para testar a senha. Enquanto ela troca de canal o
    // celular pode perder a rede dela por alguns segundos: isso é normal.
    final fim = DateTime.now().add(const Duration(seconds: 40));
    while (mounted && DateTime.now().isBefore(fim)) {
      await Future.delayed(const Duration(milliseconds: 1500));
      try {
        final j = await BoxApi.estadoWifi(widget.host, widget.token);
        final st = '${j['estado']}';
        if (st == 'ok') {
          _ipNovo = j['ip'] == null ? null : '${j['ip']}';
          if (mounted) setState(() => _fase = _Fase.pronto);
          return;
        }
        if (st == 'falhou') {
          if (mounted) {
            setState(() {
              _fase = _Fase.redes;
              _msg = '${j['erro'] ?? 'Não conectou.'} Tente de novo.';
            });
          }
          return;
        }
      } catch (_) {
        await Rede.usarWifi(); // o celular pode ter reconectado na rede da caixa
      }
    }
    if (mounted) setState(() => _fase = _Fase.semContato);
  }

  /// Celular de volta no Wi-Fi de casa: acha a caixa e salva a conexão.
  Future<void> _concluir() async {
    setState(() {
      _terminando = true;
      _msg = null;
    });
    await Rede.liberar();
    String? host;
    if (_ipNovo != null) {
      for (var i = 0; i < 3 && host == null; i++) {
        final info = await BoxApi.sondar(_ipNovo!, ms: 2500);
        if (info != null && '${info['id']}' == widget.caixaId) host = _ipNovo;
      }
    }
    if (host == null) {
      final achadas = await BoxApi.procurar((_) {});
      for (final m in achadas) {
        // 192.168.4.1 é a rede da caixa (que ainda fica no ar ~90 s): não serve como endereço fixo.
        if ('${m['id']}' == widget.caixaId && m['host'] != ipRedeCaixa) host = '${m['host']}';
      }
    }
    if (!mounted) return;
    if (host == null) {
      setState(() {
        _terminando = false;
        _msg = 'Ainda não achei a caixa. Confira se o celular já está no Wi-Fi da casa (o mesmo que você escolheu) '
            'e toque em Concluir de novo.';
      });
      return;
    }
    await Store.I.salvarConexao(host, widget.token, widget.caixaId);
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  IconData _iconeSinal(int rssi) {
    if (rssi >= -60) return Icons.network_wifi;
    if (rssi >= -72) return Icons.network_wifi_3_bar;
    if (rssi >= -82) return Icons.network_wifi_2_bar;
    return Icons.network_wifi_1_bar;
  }

  Widget _cartaoMsg(String texto, {bool erro = true}) => Card(
        color: erro ? Theme.of(context).colorScheme.errorContainer : Theme.of(context).colorScheme.secondaryContainer,
        margin: const EdgeInsets.only(top: 16),
        child: Padding(padding: const EdgeInsets.all(14), child: Text(texto, style: const TextStyle(fontSize: 16))),
      );

  Widget _telaRedes() {
    final precisaSenha = _escolhida == '' ||
        _redes.firstWhere((r) => r['ssid'] == _escolhida, orElse: () => {'senha': true})['senha'] == true;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Escolha o Wi-Fi da sua casa', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('A caixa vai usar esta rede todos os dias. Ela só funciona em Wi-Fi de 2,4 GHz.'),
        if (_carregando) const Padding(padding: EdgeInsets.only(top: 16), child: LinearProgressIndicator()),
        if (_msg != null) _cartaoMsg(_msg!),
        const SizedBox(height: 8),
        for (final r in _redes)
          RadioListTile<String>(
            value: '${r['ssid']}',
            groupValue: _escolhida,
            onChanged: (v) => setState(() => _escolhida = v),
            title: Text('${r['ssid']}', style: const TextStyle(fontSize: 17)),
            secondary: Icon(_iconeSinal((r['rssi'] ?? -100) as int)),
            subtitle: r['senha'] == true ? null : const Text('Rede aberta (sem senha)'),
          ),
        RadioListTile<String>(
          value: '',
          groupValue: _escolhida,
          onChanged: (v) => setState(() => _escolhida = v),
          title: const Text('Outra rede (digitar o nome)'),
          secondary: const Icon(Icons.edit),
        ),
        if (_escolhida == '')
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextField(
              controller: _outra,
              decoration: const InputDecoration(labelText: 'Nome da rede', border: OutlineInputBorder()),
              onChanged: (_) => setState(() {}),
            ),
          ),
        if (_escolhida != null && precisaSenha)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: TextField(
              controller: _senha,
              obscureText: !_verSenha,
              decoration: InputDecoration(
                labelText: 'Senha do Wi-Fi',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_verSenha ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _verSenha = !_verSenha),
                ),
              ),
            ),
          ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _ssid.isEmpty || _carregando ? null : _enviar,
          icon: const Icon(Icons.wifi),
          label: const Text('Conectar a caixa neste Wi-Fi'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _carregando ? null : _carregarRedes,
          icon: const Icon(Icons.refresh),
          label: const Text('Procurar de novo'),
        ),
      ],
    );
  }

  Widget _telaConectando() => const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text('A caixa está entrando no Wi-Fi...', style: TextStyle(fontSize: 20), textAlign: TextAlign.center),
              SizedBox(height: 8),
              Text('Pode levar até 30 segundos. Se o celular sair da rede da caixa por um instante, é normal.',
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );

  Widget _telaFim({required bool certeza}) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Icon(certeza ? Icons.check_circle : Icons.help_outline,
              size: 72, color: certeza ? Colors.green : Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            certeza ? 'A caixa entrou no Wi-Fi "$_ssid"!' : 'Perdi o contato com a caixa',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            certeza
                ? 'Agora volte o celular para o Wi-Fi da casa ("$_ssid") nas configurações do Android e toque em Concluir.'
                : 'Isso acontece quando a caixa troca de canal para entrar no Wi-Fi. Volte o celular para o Wi-Fi da casa '
                    '("$_ssid") e toque em Concluir. Se a caixa não aparecer, a senha pode estar errada: entre de novo '
                    'na rede "CaixaRemedios-..." e repita.',
            style: const TextStyle(fontSize: 17),
          ),
          if (_msg != null) _cartaoMsg(_msg!),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _terminando ? null : _concluir,
            icon: _terminando
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.done),
            label: Text(_terminando ? 'Procurando a caixa...' : 'Concluir'),
          ),
          if (!certeza) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _terminando
                  ? null
                  : () => setState(() {
                        _fase = _Fase.redes;
                        _msg = null;
                      }),
              child: const Text('Voltar e tentar de novo'),
            ),
          ],
        ],
      );

  @override
  Widget build(BuildContext context) {
    final corpo = switch (_fase) {
      _Fase.redes => _telaRedes(),
      _Fase.conectando => _telaConectando(),
      _Fase.pronto => _telaFim(certeza: true),
      _Fase.semContato => _telaFim(certeza: false),
    };
    return PopScope(
      canPop: _fase != _Fase.conectando,
      child: Scaffold(appBar: AppBar(title: const Text('Wi-Fi da caixa')), body: corpo),
    );
  }
}
