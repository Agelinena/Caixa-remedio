// Primeira tela: achar a caixa e conectar o app a ela. Se a caixa ainda não tem
// Wi-Fi (rede "CaixaRemedios-XXXX"), o Wi-Fi da casa é configurado aqui no app.
import 'package:flutter/material.dart';

import 'api.dart';
import 'rede.dart';
import 'store.dart';
import 'tela_wifi.dart';

class TelaConectar extends StatefulWidget {
  const TelaConectar({super.key});

  @override
  State<TelaConectar> createState() => _TelaConectarState();
}

class _TelaConectarState extends State<TelaConectar> {
  bool _buscando = false;
  bool _conectando = false;
  double _prog = 0;
  List<Map<String, dynamic>> _achadas = [];
  String? _msg;
  final _ip = TextEditingController();

  Future<void> _buscar() async {
    setState(() {
      _buscando = true;
      _prog = 0;
      _msg = null;
      _achadas = [];
    });
    // Na rede da caixa não há internet: sem isso o Android usaria os dados móveis.
    await Rede.usarWifi();
    final r = await BoxApi.procurar((p) {
      if (mounted) setState(() => _prog = p);
    });
    await Rede.liberar();
    if (!mounted) return;
    setState(() {
      _buscando = false;
      _achadas = r;
      if (r.isEmpty) {
        _msg = 'Nenhuma caixa encontrada. Caixa nova: entre na rede "CaixaRemedios-..." (senha remedios). '
            'Caixa já configurada: deixe o celular no mesmo Wi-Fi que ela.';
      }
    });
    // Uma só caixa e ela está esperando o Wi-Fi: já segue para a configuração.
    if (r.length == 1 && r.first['modo'] == 'config') await _conectar('${r.first['host']}');
  }

  Future<void> _conectar(String host) async {
    setState(() {
      _conectando = true;
      _msg = null;
    });
    try {
      await Rede.usarWifi();
      final info = await BoxApi.sondar(host, ms: 3000);
      if (info == null) throw ApiException(0, 'Não encontrei a caixa nesse endereço.');
      final t = await BoxApi.parear(host);
      if (info['modo'] == 'config') {
        // Caixa sem Wi-Fi: configura o Wi-Fi da casa por aqui (a tela cuida do resto).
        await Rede.liberar();
        if (!mounted) return;
        setState(() => _conectando = false);
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => TelaWifi(host: host, token: t, caixaId: '${info['id'] ?? ''}'),
        ));
        return;
      }
      await Rede.liberar();
      await Store.I.salvarConexao(host, t, '${info['id'] ?? ''}');
    } on ApiException catch (e) {
      await Rede.liberar();
      if (!mounted) return;
      setState(() {
        _msg = e.code == 403
            ? 'Esta caixa já foi conectada antes. Segure o botão da caixa por 3 segundos (as luzes começam a correr) e toque em Conectar de novo.'
            : e.msg;
      });
    } catch (_) {
      await Rede.liberar();
      if (!mounted) return;
      setState(() => _msg = 'Não consegui falar com a caixa.');
    }
    if (mounted) setState(() => _conectando = false);
  }

  Widget _passo(String n, String texto) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(radius: 16, child: Text(n)),
            const SizedBox(width: 12),
            Expanded(child: Text(texto, style: const TextStyle(fontSize: 17))),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conectar a caixa')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Primeira vez?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _passo('1', 'Ligue a caixa na tomada. Sem Wi-Fi configurado, a luz do meio fica piscando.'),
          _passo('2', 'Nas configurações do celular, entre na rede Wi-Fi "CaixaRemedios-..." (senha: remedios). '
              'Se o Android avisar que a rede não tem internet, escolha continuar conectado.'),
          _passo('3', 'Volte aqui e toque em Procurar caixa. O Wi-Fi da sua casa é escolhido aqui mesmo, no app.'),
          const SizedBox(height: 8),
          const Text('A caixa já tem Wi-Fi? Deixe o celular no mesmo Wi-Fi que ela e toque em Procurar caixa.',
              style: TextStyle(fontSize: 15, color: Colors.black54)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _buscando || _conectando ? null : _buscar,
            icon: const Icon(Icons.search),
            label: Text(_buscando ? 'Procurando...' : 'Procurar caixa'),
          ),
          if (_buscando) Padding(padding: const EdgeInsets.only(top: 12), child: LinearProgressIndicator(value: _prog)),
          if (_msg != null)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              margin: const EdgeInsets.only(top: 16),
              child: Padding(padding: const EdgeInsets.all(14), child: Text(_msg!, style: const TextStyle(fontSize: 16))),
            ),
          for (final c in _achadas)
            Card(
              margin: const EdgeInsets.only(top: 16),
              child: ListTile(
                leading: const Icon(Icons.medication, size: 36),
                title: Text('${c['nome'] ?? 'Caixa de remédios'}'),
                subtitle: Text('${c['host']}'),
                trailing: FilledButton(
                  onPressed: _conectando ? null : () => _conectar('${c['host']}'),
                  child: const Text('Conectar'),
                ),
              ),
            ),
          const SizedBox(height: 28),
          const Divider(),
          const Text('Ou digite o endereço da caixa (IP):'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ip,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(hintText: '192.168.0.50', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _conectando || _ip.text.trim().isEmpty ? null : () => _conectar(_ip.text.trim()),
                child: const Text('Conectar'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Este app é um lembrete. Ele não substitui orientação médica.',
            style: TextStyle(fontSize: 14, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _ip.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ip.dispose();
    super.dispose();
  }
}
