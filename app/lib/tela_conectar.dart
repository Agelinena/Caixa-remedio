// Primeira tela: ligar a caixa no Wi-Fi e conectar o app a ela.
import 'package:flutter/material.dart';

import 'api.dart';
import 'store.dart';

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
    final r = await BoxApi.procurar((p) {
      if (mounted) setState(() => _prog = p);
    });
    if (!mounted) return;
    setState(() {
      _buscando = false;
      _achadas = r;
      if (r.isEmpty) {
        _msg = 'Nenhuma caixa encontrada. Confira se a caixa está ligada e se o celular está no mesmo Wi-Fi que ela.';
      }
    });
  }

  Future<void> _conectar(String host) async {
    setState(() {
      _conectando = true;
      _msg = null;
    });
    try {
      final info = await BoxApi.sondar(host, ms: 3000);
      if (info == null) throw ApiException(0, 'Não encontrei a caixa nesse endereço.');
      final t = await BoxApi.parear(host);
      await Store.I.salvarConexao(host, t, '${info['id'] ?? ''}');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _msg = e.code == 403
            ? 'Esta caixa já foi conectada antes. Segure o botão da caixa por 3 segundos (as luzes começam a correr) e toque em Conectar de novo.'
            : e.msg;
      });
    } catch (_) {
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
          _passo('1', 'Ligue a caixa na tomada.'),
          _passo('2', 'No celular, abra as redes Wi-Fi e entre na rede "CaixaRemedios-...".'),
          _passo('3', 'Vai abrir uma página. Escolha o Wi-Fi da sua casa e digite a senha.'),
          _passo('4', 'Volte o celular para o Wi-Fi da casa e toque no botão abaixo.'),
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
