# Caixa de remédios inteligente (IoT) — contexto para o Claude Code

Projeto final de uma cadeira de IoT (faculdade, Brasil). Caixa de remédios semanal com ESP32 que
indica o dia de tomar (LED), alerta (buzzer + app), **confirma a retirada por sensor de abertura
(reed switch + ímã em cada tampa)** e avisa um cuidador se a dose não for retirada.
Público-alvo do produto: pessoas com perda de memória, Alzheimer e esquecimento.

**Leia `docs/DOCUMENTACAO.md` antes de qualquer tarefa.** Ele tem decisões, hardware, pinagem,
modelo 3D, máquina de estados, arquitetura e pendências.

## Regras de trabalho
- Responda e comente código **em português (BR)**. O usuário é estudante, tom informal.
- Escopo atual = **MVP de fileira única (7 dias)**. A versão de 3 turnos é evolução futura; não
  complique o MVP por causa dela, mas mantenha o código fácil de expandir (arrays, constantes).
- O projeto é um **lembrete, não um dispositivo médico**. Não afirmar finalidade clínica.
- Dados de saúde: autenticação e regras de acesso por usuário em qualquer backend.
- A pinagem em `docs/DOCUMENTACAO.md` (seção 5) é a **fonte da verdade**. Não mude pinos sem
  atualizar o documento. Evite GPIO 0, 2, 5, 12, 15 (boot) e 34–39 (só entrada) para saídas.
- Não invente medidas de peças físicas. O que não foi medido está marcado como **ASSUMIDO**.
- Nada foi testado em hardware ainda. Não declare que algo "funciona" sem teste físico.

## Estrutura
```
CLAUDE.md
docs/DOCUMENTACAO.md          documentação completa (fonte da verdade)
cad/caixa_remedios.scad       modelo 3D paramétrico (OpenSCAD 2021.01)
cad/stl/                      STLs gerados (corpo, base, 7 tampas, 3 peças de teste de 1 dia)
cad/preview/                  prévias do modelo (montada, aberta, interior, tampas)
cad/caixa_remedios_v1.scad    versão antiga, com parafusos (só referência)
firmware/                     PlatformIO, ESP32 (src/main.cpp, include/pins.h)
app/                          app Flutter (Android); android_extra/ sobrepõe o android/ gerado no Actions
.github/workflows/            APK do app e .bin do firmware
```

## Comandos úteis
```bash
# Regenerar STLs (OpenSCAD 2021.01)
openscad -o cad/stl/caixa_corpo.stl      -D 'part="body"'  cad/caixa_remedios.scad
openscad -o cad/stl/caixa_base.stl       -D 'part="base"'  cad/caixa_remedios.scad
openscad -o cad/stl/caixa_tampas_x7.stl  -D 'part="lids"'  cad/caixa_remedios.scad
# Peça de teste de 1 dia
openscad -o cad/stl/teste_corpo_1dia.stl -D n=1 -D 'part="body"' cad/caixa_remedios.scad
openscad -o cad/stl/teste_tampa_1dia.stl -D n=1 -D 'part="lid1"' cad/caixa_remedios.scad
openscad -o cad/stl/teste_base_1dia.stl  -D n=1 -D 'part="base"'  cad/caixa_remedios.scad
```

## Próximas tarefas sugeridas (ordem)
1. Firmware do MVP (máquina de estados, leitura dos reeds, LEDs via 74HC595, RTC, buzzer, botão).
2. Diagrama de ligações (esquema elétrico) a partir da pinagem.
3. Persistência da agenda (NVS) e sincronização com Firebase.
4. App (agenda, histórico, notificações, cuidador).
5. Iterar o modelo 3D depois do teste de impressão de 1 dia.
