// Tela principal: o remédio de hoje, com botões grandes.
import 'package:flutter/material.dart';

import 'store.dart';
import 'util.dart';

class TelaHoje extends StatelessWidget {
  const TelaHoje({super.key});

  Future<void> _acao(BuildContext context, Future<void> Function() f, String ok) async {
    try {
      await f();
      await Store.I.atualizarEstado();
      if (context.mounted) aviso(context, ok);
    } catch (e) {
      if (context.mounted) aviso(context, 'Não deu certo: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Store.I,
      builder: (context, _) {
        final s = Store.I;
        final cfg = s.config;
        final est = s.estado;
        final hojeIdx = est != null && s.online ? (est['dia'] as num).toInt() : DateTime.now().weekday % 7;
        final dias = (cfg?['dias'] as List?) ?? const [];
        final dia = dias.length > hojeIdx ? Map<String, dynamic>.from(dias[hojeIdx] as Map) : <String, dynamic>{};
        final ativo = dia['ativo'] == true;
        final status = s.online ? '${est?['status']}' : null;
        final cor = statusCor(status);
        final remedios = cfg == null ? '' : nomesRemedios(cfg, dia);
        final pendente = status == 'aguardando' || status == 'alarme' || status == 'atrasada';
        final tocando = est?['tocando'] == true && s.online;
        final tampas = (est?['tampas'] as List?) ?? const [];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!s.online)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: ListTile(
                  leading: const Icon(Icons.wifi_off),
                  title: const Text('Sem contato com a caixa'),
                  subtitle: const Text('Os lembretes do celular continuam funcionando.'),
                  trailing: IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Procurar a caixa',
                    onPressed: () async {
                      aviso(context, 'Procurando a caixa...');
                      final ok = await s.reencontrar();
                      await s.carregarTudo();
                      if (context.mounted) aviso(context, ok ? 'Caixa encontrada.' : 'Não encontrei a caixa nesta rede.');
                    },
                  ),
                ),
              ),
            if (s.online && est?['relogio_ok'] != true)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: ListTile(
                  leading: const Icon(Icons.access_time),
                  title: const Text('A caixa está sem hora'),
                  subtitle: const Text('Sem a hora certa ela não avisa. Toque para acertar pelo celular.'),
                  onTap: () => _acao(context, s.api.acertarHora, 'Relógio da caixa acertado.'),
                ),
              ),
            if (s.online && est?['reabastecendo'] == true)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.inventory_2),
                  title: const Text('Reabastecendo'),
                  subtitle: const Text('As aberturas não estão sendo contadas.'),
                  trailing: TextButton(
                    onPressed: () => _acao(context, () => s.api.reabastecer(0), 'Pronto.'),
                    child: const Text('Terminar'),
                  ),
                ),
              ),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: cor, width: 3),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(diasNomes[hojeIdx], style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    if (ativo) ...[
                      Text('${dia['hora']}', style: TextStyle(fontSize: 56, fontWeight: FontWeight.bold, color: cor)),
                      Text(
                        remedios.isEmpty ? 'Remédio do dia' : remedios,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ] else
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Hoje não tem remédio na agenda.', style: TextStyle(fontSize: 22)),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(statusIcone(status), color: cor, size: 34),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            s.online ? statusTexto(status) : 'Sem contato com a caixa',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: cor),
                          ),
                        ),
                      ],
                    ),
                    if (status == 'tomada' && (est?['tomada_em'] as num? ?? 0) > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Builder(builder: (_) {
                          final t = DateTime.fromMillisecondsSinceEpoch((est!['tomada_em'] as num).toInt() * 1000);
                          return Text('Tomado às ${dois(t.hour)}:${dois(t.minute)}', style: const TextStyle(fontSize: 20));
                        }),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (s.online && pendente && ativo)
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  minimumSize: const Size.fromHeight(76),
                  textStyle: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                onPressed: () async {
                  final ok = await confirmar(context, 'Tomou o remédio?', 'Marcar o remédio de hoje como tomado.', sim: 'Tomei');
                  if (ok && context.mounted) await _acao(context, s.api.tomei, 'Marcado como tomado.');
                },
                icon: const Icon(Icons.check, size: 34),
                label: const Text('Tomei'),
              ),
            if (tocando) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(64),
                  textStyle: const TextStyle(fontSize: 22),
                ),
                onPressed: () => _acao(context, s.api.silenciar, 'Alarme silenciado. A luz continua acesa.'),
                icon: const Icon(Icons.volume_off, size: 30),
                label: const Text('Silenciar alarme'),
              ),
            ],
            const SizedBox(height: 24),
            const Text('Semana', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < 7; i++)
                  _Bolinha(
                    letra: diasCurtos[i],
                    hoje: i == hojeIdx,
                    ativo: dias.length > i && (dias[i] as Map)['ativo'] == true,
                    aberta: s.online && tampas.length > i && tampas[i] == 1,
                    cor: i == hojeIdx ? cor : null,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Cadeado aberto = tampa aberta agora. Dias em cinza não têm remédio.',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ],
        );
      },
    );
  }
}

class _Bolinha extends StatelessWidget {
  final String letra;
  final bool hoje;
  final bool ativo;
  final bool aberta;
  final Color? cor;
  const _Bolinha({required this.letra, required this.hoje, required this.ativo, required this.aberta, this.cor});

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final fundo = hoje ? (cor ?? esquema.primary) : (ativo ? esquema.primaryContainer : Colors.grey.shade300);
    final texto = hoje ? Colors.white : (ativo ? esquema.onPrimaryContainer : Colors.grey.shade600);
    return Column(
      children: [
        CircleAvatar(
          radius: 21,
          backgroundColor: fundo,
          child: Text(letra, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: texto)),
        ),
        const SizedBox(height: 4),
        Icon(aberta ? Icons.lock_open : Icons.lock_outline, size: 18, color: aberta ? Colors.orange.shade800 : Colors.grey),
      ],
    );
  }
}
