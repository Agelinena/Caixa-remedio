// Textos e ajudas usados em várias telas.
import 'dart:convert';

import 'package:flutter/material.dart';

const List<String> diasNomes = ['Domingo', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado'];
const List<String> diasCurtos = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
const List<String> diasAbrev = ['dom', 'seg', 'ter', 'qua', 'qui', 'sex', 'sáb'];

String dois(int n) => n.toString().padLeft(2, '0');

Map<String, dynamic> copia(Map<String, dynamic> m) => Map<String, dynamic>.from(jsonDecode(jsonEncode(m)) as Map);

/// Nomes dos remédios de um dia, separados por vírgula.
String nomesRemedios(Map<String, dynamic> cfg, Map<String, dynamic> dia) {
  final ids = ((dia['remedios'] as List?) ?? const []).map((e) => '$e').toSet();
  final nomes = <String>[];
  for (final r in (cfg['remedios'] as List?) ?? const []) {
    final m = r as Map;
    if (ids.contains('${m['id']}')) {
      final dose = '${m['dose'] ?? ''}'.trim();
      nomes.add(dose.isEmpty ? '${m['nome']}' : '${m['nome']} ($dose)');
    }
  }
  return nomes.join(', ');
}

String statusTexto(String? s) {
  switch (s) {
    case 'aguardando':
      return 'Ainda não é a hora';
    case 'alarme':
      return 'Hora de tomar!';
    case 'atrasada':
      return 'Atrasado: tome agora';
    case 'tomada':
      return 'Já tomou hoje';
    case 'perdida':
      return 'Não tomou';
    case 'sem_dose':
      return 'Sem remédio hoje';
    default:
      return 'Sem informação';
  }
}

Color statusCor(String? s) {
  switch (s) {
    case 'alarme':
      return const Color(0xFFE65100);
    case 'atrasada':
    case 'perdida':
      return const Color(0xFFC62828);
    case 'tomada':
      return const Color(0xFF2E7D32);
    case 'aguardando':
      return const Color(0xFF1565C0);
    default:
      return const Color(0xFF616161);
  }
}

IconData statusIcone(String? s) {
  switch (s) {
    case 'alarme':
      return Icons.notifications_active;
    case 'atrasada':
      return Icons.warning_amber_rounded;
    case 'perdida':
      return Icons.cancel;
    case 'tomada':
      return Icons.check_circle;
    case 'aguardando':
      return Icons.schedule;
    default:
      return Icons.remove_circle_outline;
  }
}

void aviso(BuildContext context, String texto) {
  final m = ScaffoldMessenger.maybeOf(context);
  m?.hideCurrentSnackBar();
  m?.showSnackBar(SnackBar(content: Text(texto, style: const TextStyle(fontSize: 16))));
}

/// Caixa de diálogo para digitar um texto ou número. Null se cancelar.
Future<String?> pedirTexto(
  BuildContext context,
  String titulo,
  String valor, {
  bool numero = false,
  String? dica,
  String? ajuda,
}) {
  final ctl = TextEditingController(text: valor);
  return showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(titulo),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ajuda != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(ajuda)),
          TextField(
            controller: ctl,
            autofocus: true,
            keyboardType: numero ? TextInputType.number : TextInputType.text,
            decoration: InputDecoration(hintText: dica, border: const OutlineInputBorder()),
            onSubmitted: (v) => Navigator.pop(c, v.trim()),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(c, ctl.text.trim()), child: const Text('OK')),
      ],
    ),
  );
}

Future<bool> confirmar(BuildContext context, String titulo, String texto, {String sim = 'Sim'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(titulo),
      content: Text(texto),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(sim)),
      ],
    ),
  );
  return r == true;
}
