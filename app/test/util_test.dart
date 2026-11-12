import 'package:caixa_remedios/util.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nomesRemedios junta nome e dose dos remédios do dia', () {
    final cfg = {
      'remedios': [
        {'id': 'r1', 'nome': 'Losartana', 'dose': '50 mg'},
        {'id': 'r2', 'nome': 'Vitamina D', 'dose': ''},
        {'id': 'r3', 'nome': 'Outro', 'dose': ''},
      ],
    };
    final dia = {
      'remedios': ['r1', 'r2'],
    };
    expect(nomesRemedios(cfg, dia), 'Losartana (50 mg), Vitamina D');
  });

  test('dois completa com zero', () {
    expect(dois(7), '07');
    expect(dois(12), '12');
  });
}
