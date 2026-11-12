// Ajustes: pessoa, alarme, aviso ao cuidador (Telegram), manutenção da caixa.
import 'package:flutter/material.dart';

import 'store.dart';
import 'util.dart';

class TelaAjustes extends StatelessWidget {
  const TelaAjustes({super.key});

  Future<void> _muda(BuildContext context, void Function(Map<String, dynamic> c) f) async {
    final atual = Store.I.config;
    if (atual == null) {
      aviso(context, 'Sem contato com a caixa.');
      return;
    }
    final c = copia(atual);
    f(c);
    try {
      await Store.I.gravarConfig(c);
      if (context.mounted) aviso(context, 'Gravado na caixa.');
    } catch (e) {
      if (context.mounted) aviso(context, 'Não consegui gravar: $e');
    }
  }

  Future<void> _numero(BuildContext context, String titulo, String chave, int atual, int min, int max, String ajuda) async {
    final r = await pedirTexto(context, titulo, '$atual', numero: true, ajuda: ajuda);
    if (r == null || !context.mounted) return;
    final v = int.tryParse(r);
    if (v == null || v < min || v > max) {
      aviso(context, 'Use um número entre $min e $max.');
      return;
    }
    await _muda(context, (c) => c[chave] = v);
  }

  Future<void> _acao(BuildContext context, Future<void> Function() f, String ok) async {
    try {
      await f();
      if (context.mounted) aviso(context, ok);
    } catch (e) {
      if (context.mounted) aviso(context, 'Não deu certo: $e');
    }
  }

  Widget _titulo(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
        child: Text(t, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Store.I,
      builder: (context, _) {
        final s = Store.I;
        final c = s.config ?? <String, dynamic>{};
        final tg = Map<String, dynamic>.from((c['telegram'] as Map?) ?? {});
        final tol = (c['tolerancia_min'] as num?)?.toInt() ?? 30;
        final ant = (c['antecipa_min'] as num?)?.toInt() ?? 60;
        final rep = (c['repete_min'] as num?)?.toInt() ?? 5;
        final dur = (c['alarme_seg'] as num?)?.toInt() ?? 60;
        final est = s.estado;

        return ListView(
          children: [
            _titulo('Pessoa'),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Nome de quem toma o remédio'),
              subtitle: Text('${c['paciente'] ?? ''}'.isEmpty ? 'Não informado' : '${c['paciente']}'),
              onTap: () async {
                final r = await pedirTexto(context, 'Nome', '${c['paciente'] ?? ''}', dica: 'Maria',
                    ajuda: 'Aparece nos avisos ao cuidador.');
                if (r != null && context.mounted) await _muda(context, (x) => x['paciente'] = r);
              },
            ),
            _titulo('Alarme'),
            SwitchListTile(
              secondary: const Icon(Icons.volume_up),
              title: const Text('Som na caixa'),
              subtitle: const Text('Se desligar, só a luz avisa.'),
              value: c['som'] != false,
              onChanged: (v) => _muda(context, (x) => x['som'] = v),
            ),
            ListTile(
              leading: const Icon(Icons.timer),
              title: const Text('Tempo até considerar atrasado'),
              subtitle: Text('$tol minutos depois do horário'),
              onTap: () => _numero(context, 'Tolerância (minutos)', 'tolerancia_min', tol, 5, 240,
                  'Depois desse tempo a dose fica "atrasada" e o cuidador é avisado.'),
            ),
            ListTile(
              leading: const Icon(Icons.fast_forward),
              title: const Text('Pode tomar antes do horário'),
              subtitle: Text('Até $ant minutos antes'),
              onTap: () => _numero(context, 'Antecipação (minutos)', 'antecipa_min', ant, 0, 720,
                  'Abrir a tampa até esse tempo antes do horário conta como tomado.'),
            ),
            ListTile(
              leading: const Icon(Icons.repeat),
              title: const Text('Repetir o alarme'),
              subtitle: Text('A cada $rep minutos, tocando $dur segundos'),
              onTap: () async {
                await _numero(context, 'Repetir a cada (minutos)', 'repete_min', rep, 1, 60,
                    'Enquanto ninguém abrir a tampa, o alarme volta a tocar nesse intervalo.');
                if (context.mounted) {
                  await _numero(context, 'Tocar por (segundos)', 'alarme_seg', dur, 5, 300,
                      'Quanto tempo cada toque dura.');
                }
              },
            ),
            _titulo('Aviso ao cuidador (Telegram)'),
            SwitchListTile(
              secondary: const Icon(Icons.send),
              title: const Text('Avisar pelo Telegram'),
              subtitle: Text(tg['ativo'] == true && '${tg['chat'] ?? ''}'.isNotEmpty
                  ? 'Ligado'
                  : 'Avisa quando a dose atrasa ou não é tomada'),
              value: tg['ativo'] == true,
              onChanged: (v) async {
                if (v && ('${tg['token'] ?? ''}'.isEmpty || '${tg['chat'] ?? ''}'.isEmpty)) {
                  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TelaTelegram()));
                  return;
                }
                await _muda(context, (x) => (x['telegram'] = {...tg, 'ativo': v}));
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_suggest),
              title: const Text('Configurar o Telegram'),
              subtitle: Text('${tg['chat'] ?? ''}'.isEmpty ? 'Não configurado' : 'Conversa ${tg['chat']}'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TelaTelegram())),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.check),
              title: const Text('Avisar também quando tomar'),
              value: tg['avisa_tomada'] == true,
              onChanged: (v) => _muda(context, (x) => (x['telegram'] = {...tg, 'avisa_tomada': v})),
            ),
            _titulo('Caixa'),
            ListTile(
              leading: const Icon(Icons.inventory_2),
              title: const Text('Reabastecer'),
              subtitle: const Text('Acende todas as luzes por 10 minutos. Abrir as tampas não conta como dose.'),
              onTap: () => _acao(context, () => s.api.reabastecer(10), 'Pode encher a caixa. Toque em "Terminar" na tela Hoje.'),
            ),
            ListTile(
              leading: const Icon(Icons.lightbulb),
              title: const Text('Testar luzes e som'),
              onTap: () => _acao(context, s.api.teste, 'Olhe a caixa: as luzes acendem uma a uma e ela apita.'),
            ),
            ListTile(
              leading: const Icon(Icons.access_time),
              title: const Text('Acertar a hora pelo celular'),
              subtitle: const Text('A caixa também acerta sozinha pela internet.'),
              onTap: () => _acao(context, s.api.acertarHora, 'Hora acertada.'),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Informações'),
              subtitle: Text(s.online && est != null
                  ? 'Endereço ${s.host} · versão ${est['fw']} · Wi-Fi ${est['wifi']} dBm${est['rtc'] == true ? '' : ' · sem RTC'}'
                  : 'Endereço ${s.host} · sem contato'),
            ),
            ListTile(
              leading: const Icon(Icons.link_off, color: Colors.red),
              title: const Text('Desconectar desta caixa'),
              onTap: () async {
                final ok = await confirmar(context, 'Desconectar?',
                    'O app esquece esta caixa e para os lembretes. A agenda continua gravada na caixa.',
                    sim: 'Desconectar');
                if (ok) await s.desconectar();
              },
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Este app e a caixa são um lembrete. Não substituem orientação médica nem garantem que o remédio foi engolido.',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Passo a passo para ligar o aviso pelo Telegram.
class TelaTelegram extends StatefulWidget {
  const TelaTelegram({super.key});

  @override
  State<TelaTelegram> createState() => _TelaTelegramState();
}

class _TelaTelegramState extends State<TelaTelegram> {
  final _token = TextEditingController();
  final _chat = TextEditingController();
  bool _ocupado = false;

  @override
  void initState() {
    super.initState();
    final tg = (Store.I.config?['telegram'] as Map?) ?? {};
    _token.text = '${tg['token'] ?? ''}';
    _chat.text = '${tg['chat'] ?? ''}';
  }

  @override
  void dispose() {
    _token.dispose();
    _chat.dispose();
    super.dispose();
  }

  Future<void> _roda(Future<void> Function() f) async {
    setState(() => _ocupado = true);
    try {
      await f();
    } catch (e) {
      if (mounted) aviso(context, '$e');
    }
    if (mounted) setState(() => _ocupado = false);
  }

  Widget _passo(String n, String t) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(child: Text(n)),
        title: Text(t),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aviso pelo Telegram')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _passo('1', 'No Telegram do cuidador, abra o @BotFather, mande /newbot e siga as instruções.'),
          _passo('2', 'Copie o token que ele mostrar e cole abaixo.'),
          TextField(
            controller: _token,
            decoration: const InputDecoration(labelText: 'Token do bot', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          _passo('3', 'Abra a conversa com o seu bot novo e mande "oi". Depois toque em "Achar conversa".'),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chat,
                  decoration: const InputDecoration(labelText: 'Conversa (chat id)', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _ocupado
                    ? null
                    : () => _roda(() async {
                          final r = await Store.I.api.telegramChat(_token.text.trim());
                          _chat.text = '${r['chat']}';
                          if (mounted) aviso(context, 'Achei a conversa de ${r['nome']}.');
                        }),
                child: const Text('Achar conversa'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _passo('4', 'Toque em "Testar". O cuidador deve receber uma mensagem.'),
          OutlinedButton.icon(
            onPressed: _ocupado
                ? null
                : () => _roda(() async {
                      await Store.I.api.telegramTeste(_token.text.trim(), _chat.text.trim());
                      if (mounted) aviso(context, 'Mensagem de teste enviada.');
                    }),
            icon: const Icon(Icons.send),
            label: const Text('Testar'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _ocupado
                ? null
                : () => _roda(() async {
                      final c = copia(Store.I.config!);
                      final tg = Map<String, dynamic>.from((c['telegram'] as Map?) ?? {});
                      tg['token'] = _token.text.trim();
                      tg['chat'] = _chat.text.trim();
                      tg['ativo'] = tg['token'] != '' && tg['chat'] != '';
                      c['telegram'] = tg;
                      await Store.I.gravarConfig(c);
                      if (mounted) Navigator.of(context).pop();
                    }),
            child: const Text('Salvar e ligar'),
          ),
          const SizedBox(height: 16),
          const Text(
            'A caixa manda os avisos sozinha pela internet, mesmo com o celular desligado. '
            'Ela avisa quando a dose passa da tolerância e quando o dia termina sem a dose.',
          ),
        ],
      ),
    );
  }
}
