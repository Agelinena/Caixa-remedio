// Agenda: lista de remédios e, para cada dia, a hora e quais remédios estão no compartimento.
import 'package:flutter/material.dart';

import 'store.dart';
import 'util.dart';

class TelaAgenda extends StatefulWidget {
  const TelaAgenda({super.key});

  @override
  State<TelaAgenda> createState() => _TelaAgendaState();
}

class _TelaAgendaState extends State<TelaAgenda> {
  Map<String, dynamic>? _c; // cópia em edição
  bool _mudou = false;
  bool _gravando = false;

  @override
  void initState() {
    super.initState();
    Store.I.addListener(_sincroniza);
    _sincroniza();
  }

  @override
  void dispose() {
    Store.I.removeListener(_sincroniza);
    super.dispose();
  }

  // Enquanto não há edição pendente, acompanha a agenda da caixa.
  void _sincroniza() {
    if (_mudou || !mounted) return;
    final c = Store.I.config;
    setState(() => _c = c == null ? null : copia(c));
  }

  List get _remedios => (_c!['remedios'] as List?) ?? (_c!['remedios'] = []);
  List get _dias => _c!['dias'] as List;

  void _editou() => setState(() => _mudou = true);

  Future<void> _gravar() async {
    setState(() => _gravando = true);
    try {
      await Store.I.gravarConfig(copia(_c!));
      _mudou = false;
      if (mounted) aviso(context, 'Agenda gravada na caixa.');
    } catch (e) {
      if (mounted) aviso(context, 'Não consegui gravar: $e');
    }
    if (mounted) setState(() => _gravando = false);
  }

  void _descartar() {
    _mudou = false;
    _sincroniza();
  }

  Future<void> _editarRemedio([Map? r]) async {
    final nome = TextEditingController(text: '${r?['nome'] ?? ''}');
    final dose = TextEditingController(text: '${r?['dose'] ?? ''}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(r == null ? 'Novo remédio' : 'Editar remédio'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nome,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nome', hintText: 'Losartana', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: dose,
              decoration: const InputDecoration(
                labelText: 'Dose (opcional)',
                hintText: '50 mg, 1 comprimido',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('OK')),
        ],
      ),
    );
    if (ok != true || nome.text.trim().isEmpty) return;
    if (r == null) {
      _remedios.add({
        'id': 'r${DateTime.now().millisecondsSinceEpoch}',
        'nome': nome.text.trim(),
        'dose': dose.text.trim(),
      });
    } else {
      r['nome'] = nome.text.trim();
      r['dose'] = dose.text.trim();
    }
    _editou();
  }

  Future<void> _apagarRemedio(Map r) async {
    final ok = await confirmar(context, 'Apagar remédio?', 'Apagar "${r['nome']}" da lista e de todos os dias.', sim: 'Apagar');
    if (!ok) return;
    _remedios.remove(r);
    for (final d in _dias) {
      ((d as Map)['remedios'] as List?)?.remove(r['id']);
    }
    _editou();
  }

  Future<void> _escolherHora(Map d) async {
    final hm = '${d['hora'] ?? '08:00'}'.split(':');
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.tryParse(hm[0]) ?? 8, minute: hm.length > 1 ? (int.tryParse(hm[1]) ?? 0) : 0),
      helpText: 'Hora do remédio',
      builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (t == null) return;
    d['hora'] = '${dois(t.hour)}:${dois(t.minute)}';
    _editou();
  }

  Future<void> _escolherRemedios(Map d, int i) async {
    if (_remedios.isEmpty) {
      aviso(context, 'Cadastre um remédio primeiro, no botão "Novo remédio".');
      return;
    }
    final marcados = ((d['remedios'] as List?) ?? []).map((e) => '$e').toSet();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: Text('Remédios de ${diasNomes[i].toLowerCase()}'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final r in _remedios)
                  CheckboxListTile(
                    value: marcados.contains('${(r as Map)['id']}'),
                    title: Text('${r['nome']}'),
                    subtitle: '${r['dose'] ?? ''}'.isEmpty ? null : Text('${r['dose']}'),
                    onChanged: (v) => setD(() {
                      if (v == true) {
                        marcados.add('${r['id']}');
                      } else {
                        marcados.remove('${r['id']}');
                      }
                    }),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('OK')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    d['remedios'] = marcados.toList();
    if (marcados.isNotEmpty) d['ativo'] = true;
    _editou();
  }

  Future<void> _copiarParaTodos(int origem) async {
    final o = _dias[origem] as Map;
    final ok = await confirmar(
      context,
      'Copiar para todos os dias?',
      'Todos os dias vão ficar iguais a ${diasNomes[origem].toLowerCase()}: ${o['hora']}, mesmos remédios.',
      sim: 'Copiar',
    );
    if (!ok) return;
    for (final d in _dias) {
      final m = d as Map;
      m['ativo'] = o['ativo'];
      m['hora'] = o['hora'];
      m['remedios'] = List.from((o['remedios'] as List?) ?? []);
    }
    _editou();
  }

  @override
  Widget build(BuildContext context) {
    if (_c == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Ainda não consegui ler a agenda da caixa. Confira se ela está ligada e no Wi-Fi.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 18)),
        ),
      );
    }
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Remédios', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              if (_remedios.isEmpty) const Text('Nenhum remédio cadastrado ainda.'),
              for (final r in _remedios)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.medication),
                    title: Text('${(r as Map)['nome']}'),
                    subtitle: '${r['dose'] ?? ''}'.isEmpty ? null : Text('${r['dose']}'),
                    onTap: () => _editarRemedio(r),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Apagar',
                      onPressed: () => _apagarRemedio(r),
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => _editarRemedio(),
                  icon: const Icon(Icons.add),
                  label: const Text('Novo remédio'),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Dias da semana', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const Text('Cada dia é um compartimento da caixa.'),
              const SizedBox(height: 8),
              for (var i = 0; i < 7 && i < _dias.length; i++) _cartaoDia(i),
              const SizedBox(height: 80),
            ],
          ),
        ),
        if (_mudou)
          Material(
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  TextButton(onPressed: _gravando ? null : _descartar, child: const Text('Desfazer')),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _gravando ? null : _gravar,
                      icon: const Icon(Icons.save),
                      label: Text(_gravando ? 'Gravando...' : 'Gravar na caixa'),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _cartaoDia(int i) {
    final d = _dias[i] as Map;
    final ativo = d['ativo'] == true;
    final rem = nomesRemedios(_c!, Map<String, dynamic>.from(d));
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(diasNomes[i], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                Switch(
                  value: ativo,
                  onChanged: (v) {
                    d['ativo'] = v;
                    _editou();
                  },
                ),
              ],
            ),
            if (ativo) ...[
              Row(
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => _escolherHora(d),
                    icon: const Icon(Icons.schedule),
                    label: Text('${d['hora']}'),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.copy_all),
                    tooltip: 'Copiar para todos os dias',
                    onPressed: () => _copiarParaTodos(i),
                  ),
                ],
              ),
              InkWell(
                onTap: () => _escolherRemedios(d, i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.medication_outlined),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(rem.isEmpty ? 'Toque para escolher os remédios' : rem, style: const TextStyle(fontSize: 17)),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
