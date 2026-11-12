// Histórico: o que a caixa registrou (tomou, atrasou, não tomou, tampa errada...).
import 'package:flutter/material.dart';

import 'store.dart';
import 'util.dart';

class TelaHistorico extends StatelessWidget {
  const TelaHistorico({super.key});

  static const _visiveis = {
    'tomada',
    'tomada_atrasada',
    'atrasada',
    'perdida',
    'errada',
    'fora_horario',
    'abertura',
    'alarme',
    'reabastecer',
  };

  (IconData, Color, String) _aparencia(Map<String, dynamic> e) {
    final dia = diasNomes[((e['dia'] as num?)?.toInt() ?? 0) % 7].toLowerCase();
    final manual = e['info'] == 'manual' ? ' (marcado no app)' : '';
    switch ('${e['tipo']}') {
      case 'tomada':
        return (Icons.check_circle, const Color(0xFF2E7D32), 'Tomou o remédio de $dia$manual');
      case 'tomada_atrasada':
        return (Icons.check_circle_outline, const Color(0xFFE65100), 'Tomou com atraso o remédio de $dia$manual');
      case 'atrasada':
        return (Icons.warning_amber_rounded, const Color(0xFFE65100), 'Atrasou o remédio de $dia');
      case 'perdida':
        return (Icons.cancel, const Color(0xFFC62828), 'Não tomou o remédio de $dia');
      case 'errada':
        return (Icons.error_outline, const Color(0xFFC62828), 'Abriu a tampa errada ($dia)');
      case 'alarme':
        return (Icons.notifications_active, const Color(0xFF1565C0), 'Alarme do remédio de $dia');
      case 'reabastecer':
        return (Icons.inventory_2, const Color(0xFF616161), 'Caixa reabastecida');
      case 'fora_horario':
        return (Icons.lock_open, const Color(0xFF616161), 'Abriu a tampa de $dia fora do horário');
      default:
        return (Icons.lock_open, const Color(0xFF616161), 'Abriu a tampa de $dia');
    }
  }

  String _quando(int ts) {
    if (ts <= 0) return 'sem hora';
    final t = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    return '${diasAbrev[t.weekday % 7]}, ${dois(t.day)}/${dois(t.month)} às ${dois(t.hour)}:${dois(t.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Store.I,
      builder: (context, _) {
        final todos = Store.I.eventos.where((e) => _visiveis.contains('${e['tipo']}')).toList();
        final limite = DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch ~/ 1000;
        var tomou = 0, atrasou = 0, perdeu = 0;
        for (final e in todos) {
          if (((e['ts'] as num?)?.toInt() ?? 0) < limite) continue;
          switch ('${e['tipo']}') {
            case 'tomada':
              tomou++;
            case 'tomada_atrasada':
              atrasou++;
            case 'perdida':
              perdeu++;
          }
        }
        return RefreshIndicator(
          onRefresh: Store.I.carregarEventos,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Últimos 7 dias', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _Resumo(n: tomou, rotulo: 'no horário', cor: const Color(0xFF2E7D32)),
                  _Resumo(n: atrasou, rotulo: 'com atraso', cor: const Color(0xFFE65100)),
                  _Resumo(n: perdeu, rotulo: 'não tomou', cor: const Color(0xFFC62828)),
                ],
              ),
              const SizedBox(height: 20),
              const Text('Registros', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              if (todos.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text('Ainda não há registros. Puxe para baixo para atualizar.'),
                ),
              for (final e in todos)
                Builder(builder: (_) {
                  final (icone, cor, texto) = _aparencia(e);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(icone, color: cor, size: 32),
                    title: Text(texto),
                    subtitle: Text(_quando((e['ts'] as num?)?.toInt() ?? 0)),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}

class _Resumo extends StatelessWidget {
  final int n;
  final String rotulo;
  final Color cor;
  const _Resumo({required this.n, required this.rotulo, required this.cor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Text('$n', style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: cor)),
              Text(rotulo, style: const TextStyle(fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }
}
