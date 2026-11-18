# Documentação do projeto: Caixa de remédios inteligente (IoT)

Versão do documento: 1.2 · Estado: **modelo 3D v2 impresso; v3 (dobradiça de encaixe, reed deitado) gerada; eletrônica não testada em hardware**

Legenda usada ao longo do texto:
- **DECIDIDO**: o usuário aprovou ou escolheu.
- **PROPOSTO**: sugerido por Claude e aceito de forma geral ("gostei de todas as sugestões"), mas sem detalhe fechado.
- **ASSUMIDO**: valor ou premissa usada sem confirmação, precisa ser medida ou verificada.
- **PENDENTE**: ainda precisa de decisão.

---

## 1. Visão geral

### 1.1 Problema e público
Pessoas com perda de memória, Alzheimer ou esquecimento comum esquecem de tomar remédios ou
tomam duas vezes. A caixa mostra fisicamente qual dia (e, na versão futura, qual turno) deve
ser tomado, avisa, e registra se a pessoa realmente abriu o compartimento certo.

### 1.2 Contexto do usuário
- Estudante, projeto final de uma cadeira de IoT. Brasil (preços em R$, lojas como Mercado Livre).
- Já tem LEDs comuns de loja de eletrônica (tamanho **não medido**).
- Vai imprimir a caixa em 3D, numa **Ender 2 ou Ender 3** (não lembra qual; Ender 2 = mesa 165×165 mm, Ender 3 = 220×220 mm).
- Botão: vai usar um **botão de pressão pequeno** por enquanto (provavelmente tátil de placa; modelo não definido).

### 1.3 Diferencial (DECIDIDO)
**Detecção de abertura do compartimento** por reed switch + ímã em cada tampa. Quem esquece de
tomar também esquece de marcar "tomei" no app, então o sensor confirma a retirada sozinho.
Soluções existentes citadas (verificar preço e disponibilidade atuais antes de citar em
apresentação): Hero, MedMinder, Pillo, Livi, Tricella, Pivotell, caixas "smart" genéricas de
marketplace, e apps sem hardware (Medisafe, MyTherapy, Dosecast). Posicionamento: baixo custo,
em português, com confirmação por sensor e aviso ao cuidador.

### 1.4 Ideia original do usuário (para referência)
- Caixa comum de remédio com 1 a 3 fileiras e 7 colunas (dias), turnos manhã/tarde/noite ou só 1 fileira.
- LED indicador por dia, ESP32 gerenciando, app de celular conectado ao ESP32 para configurar dias e remédios, marcar "tomei" e receber notificações.
- Aviso sonoro na caixa com botão para desligar, integrado ao app.

---

## 2. Escopo

### 2.1 MVP — fileira única, 7 dias (DECIDIDO como alvo da cadeira)
- 7 compartimentos (Dom a Sáb), 1 LED e 1 reed switch por compartimento.
- ESP32, RTC DS3231, buzzer, botão de silenciar.
- App com agenda, histórico, notificações.
- Aviso ao cuidador quando a dose atrasa.

### 2.2 Versão expandida — 3 turnos (evolução futura)
- Grade 7 dias × 3 turnos (manhã, tarde, noite): **21 LEDs e 21 reeds**.
- Expansores de pinos: MCP23017 (I2C, 16 pinos por chip) e/ou 74HC595 para LEDs; ou fita WS2812 (1 pino).
- Um LED por compartimento (não só por dia).

### 2.2.1 Imagens de conceito geradas (SVG inline no chat, não são arquivos)
1. **Conceito inicial**: 7 colunas × 3 turnos, LED no dia atual, ESP32 + buzzer + botão, app com lembrete.
2. **Fileira única (MVP)**: 7 compartimentos, LED acima de cada um, reed + ímã em cada tampa, ESP32 + RTC + buzzer + botão, app com "Tomado às 14:03". Dom–Ter marcados como tomados, Qua = hoje (LED âmbar aceso).
3. **Três turnos**: grade 7×3 com LED por compartimento, expansor de pinos, app + cuidador.
As prévias 3D reais do modelo estão em `cad/preview/` (ver seção 8.10).

---

## 3. Arquitetura (IMPLEMENTADA em 2026-11-12, nada testado em hardware)

```
 [Reed x7] ──┐
 [Botão]   ──┤
 [RTC I2C] ──┼──> ESP32 ──> [74HC595] ──> [LED x7]
             │        ├───> [Buzzer via transistor]
             │        └───> Telegram do cuidador (HTTPS, pela internet)
             │
             └── Wi-Fi da casa ── API HTTP porta 8080 ── App Android (Flutter)
                                                          └─> lembretes agendados no celular
```

- **Caixa (firmware)**: decide tudo sozinha. Lê reeds, aciona LEDs e buzzer, lê o botão, guarda agenda
  (LittleFS) e estado do dia (NVS), usa o RTC para manter a hora **sem internet** e acerta pelo NTP
  quando há Wi-Fi. O histórico fica na própria caixa.
- **Comunicação**: Wi-Fi configurado pelo portal "CaixaRemedios-XXXX" (WiFiManager). O app acha a caixa
  varrendo a rede local e fala com uma API HTTP. **Não usa Firebase, MQTT nem BLE** (decisão 7):
  menos peças, nada de nuvem, e a caixa funciona igual sem internet.
- **App**: Flutter, só Android, APK gerado pelo GitHub Actions.
- **Cuidador**: a própria caixa manda mensagem por um bot do Telegram quando a dose atrasa ou o dia
  termina sem a dose (opcional: também quando toma). Funciona com o celular do paciente desligado.
- **Segurança/privacidade**: os dados ficam só na caixa e no celular. A API pede um token que só é
  entregue no primeiro pareamento ou depois de segurar o botão físico da caixa por 3 s. O tráfego na
  rede local é HTTP sem criptografia (aceitável para a cadeira; ver pendências).
- **Aviso**: é um lembrete, **não um dispositivo médico**. Deixar isso explícito na apresentação e na documentação final.

---

## 4. Lista de materiais (BOM) do MVP

| Item | Qtd | Função | Observações |
|---|---|---|---|
| ESP32 DevKit (WROOM-32), **30 pinos, USB-C** | 1 (2 se quiser reserva) | Controle, Wi-Fi, BLE | Anúncio visto: R$ 43,89, 4 MB flash, 520 KB SRAM. Número de pinos (30) **inferido da foto** (15 por lado) |
| Módulo RTC DS3231 | 1 | Hora precisa sem internet | Pode vir com CR2032 ou não |
| Reed switch | 7 (comprar 9–10) | Detecta tampa aberta | Do anúncio: vidro 14 × 2,2 mm, comprimento total 45 mm, normalmente aberto, 10–20 AT de sensibilidade (pull-in), drop-out mín. 5 AT, 100k ciclos. O vidro quebra ao dobrar o terminal |
| Ímã neodímio disco **5 × 1 mm** | 7 (kit de 10) | Aciona o reed | Anúncio visto: kit de 10 por R$ 18,09 (promoção na época). Se o reed falhar, empilhar 2 (5 × 2 mm) |
| LED | 7 | Indicador do dia | Já possui. **Tamanho não medido** (3 mm ou 5 mm) |
| Resistor 220–330 Ω | 7 | Limitar corrente dos LEDs | |
| 74HC595 | 1 | Aciona os 7 LEDs com 3 pinos | Recomendado (libera pinos e facilita a expansão) |
| Buzzer ativo 5 V | 1 | Alarme sonoro | Acionar via transistor |
| Transistor NPN (BC547 ou 2N2222) + resistor 1 kΩ | 1 + 1 | Aciona o buzzer | |
| Botão de pressão pequeno | 1 | Silenciar o alarme | Tátil de placa provavelmente. Para o idoso, um botão arcade grande seria melhor (evolução) |
| Fonte USB 5 V / 1 A + cabo USB-C | 1 | Alimentação | |
| Protoboard 830 pontos, jumpers | – | Protótipo | |
| Placa perfurada ou PCB | – | Versão final soldada | |
| Fio fino 26–28 AWG, conectores (borne KF301, JST ou barra de pinos) | – | Ligação dos reeds e LEDs | |
| Solda, termorretrátil | – | | |
| ~~Parafusos M3~~ | 0 | — | Não são mais usados: a v2 do modelo fecha só por encaixe |
| Filamento 1,75 mm (PLA ou PETG), pedaço de ~152 mm | – | Pino da dobradiça | Usar um trecho do próprio filamento da impressora |
| CR2032 | 1 | Bateria do RTC | Atenção: o módulo ZS-042 tem circuito de carga. Com CR2032 (não recarregável), remover o diodo/resistor de carga ou usar LIR2032 |
| Multímetro | opcional | Testes | |

Alternativa ao reed citada: sensor Hall A3144 ou micro switch (fim de curso). O reed é mais simples
de embutir na peça impressa; o micro switch é mais robusto.

**Status de compra**: o usuário compartilhou capturas de anúncios do reed, do ímã e do ESP32.
Não foi confirmado que comprou.

---

## 5. Hardware e pinagem (FONTE DA VERDADE)

Placa: ESP32 DevKit 30 pinos. Evitar para saídas: GPIO 0, 2, 5, 12, 15 (boot/strapping) e 34–39 (só entrada).

| Função | Pinos do ESP32 | Detalhe |
|---|---|---|
| RTC DS3231 (I2C) | SDA = **21**, SCL = **22** | Padrão do ESP32. Não usar esses pinos para mais nada |
| 74HC595 (LEDs) | dados (SER) = **13**, clock (SRCLK) = **14**, latch (RCLK) = **27** | Saídas Q0..Q6 = LEDs dos dias 0..6. Q7 reserva |
| Reeds (7) | **16, 17, 18, 19, 23, 25, 26** | `INPUT_PULLUP`; cada reed entre o GPIO e GND |
| Buzzer (via transistor) | **4** | GPIO → 1 kΩ → base do NPN; emissor em GND; buzzer entre 5 V (VIN) e coletor |
| Botão | **32** | `INPUT_PULLUP`; botão entre o GPIO e GND |
| Reserva | 33 | |

### 5.1 Mapeamento sugerido (PROPOSTO)
Índice do dia 0 = Domingo … 6 = Sábado. `REED_PINS[i]` e saída `Qi` do 74HC595 correspondem ao mesmo dia.
```cpp
const uint8_t REED_PINS[7] = {16, 17, 18, 19, 23, 25, 26};
```

### 5.2 Lógica elétrica dos reeds
- Reed é **normalmente aberto**: fecha quando o ímã está perto.
- Tampa **fechada** (ímã perto) → contato fechado → pino em **LOW** (com pull-up).
- Tampa **aberta** → pino em **HIGH**.
- Aplicar debounce de 50–100 ms.

### 5.3 Cuidados conhecidos
- **LEDs azuis/brancos** (queda de ~3 V) acendem fraco com o 74HC595 em 3,3 V. Vermelho, amarelo e verde funcionam bem. Se forem azuis/brancos, rever a alimentação/ligação.
- **GPIO 14** emite um pulso PWM breve no boot: pode piscar os LEDs ao ligar. Limpar o 595 no `setup()` (e, se incomodar, usar o pino OE do 595).
- Resistor em série em cada LED (220–330 Ω).
- Se uma placa ESP32 for de 38 pinos em vez de 30, a posição física dos pinos muda; a numeração GPIO continua válida.

### 5.4 Versão de 3 turnos (futuro)
21 reeds e 21 LEDs: usar MCP23017 (I2C) para os reeds e 74HC595 em cascata (ou WS2812) para os LEDs.

---

## 6. Firmware (ESCRITO em `firmware/` — não compilado localmente, não testado em hardware)

PlatformIO, placa `esp32dev`, bibliotecas `RTClib`, `ArduinoJson 7`, `WiFiManager`. Um único arquivo
`firmware/src/main.cpp`; pinos em `firmware/include/pins.h` (cópia da seção 5).

### 6.1 Máquina de estados (uma dose por dia, MVP)
| Estado | Entrada | Caixa | Avisos |
|---|---|---|---|
| `sem_dose` | dia sem remédio na agenda | nada | — |
| `aguardando` | início do dia com dose | LED apagado | lembrete agendado no celular |
| `alarme` | chegou a hora | LED aceso; 3 bipes a cada 1,6 s por `alarme_seg` (60 s), repetindo a cada `repete_min` (5 min); para de tocar depois de 2 h | notificação do celular |
| `atrasada` | passou `tolerancia_min` (30) | LED piscando, bipes continuam | "Já tomou?" no celular + Telegram |
| `tomada` | abriu a tampa certa (ou "Tomei" no app) | LED apaga, bipe de confirmação | Telegram se estava atrasada (ou se `avisa_tomada`) |
| `perdida` | virou o dia em `alarme`/`atrasada` | — | Telegram + registro |

O estado do dia fica na NVS: se faltar luz, a caixa volta no mesmo estado.

### 6.2 Casos extras (implementados)
- Abrir até `antecipa_min` (60) **antes** da hora conta como tomada ("antecipada").
- Tampa **errada** durante o alarme: o LED certo pisca rápido por 5 s, bipes curtos, evento `errada`.
- Abrir **fora do horário**: evento `fora_horario` (ou `abertura` em outro dia), sem mexer na dose.
- **Reabastecer**: todos os LEDs acesos por N min; aberturas ignoradas.
- **Sem hora** (RTC sem bateria e sem internet): LEDs das pontas piscam, nada de alarme.
- Debounce do reed: 80 ms.

### 6.3 Botão
Toque curto = silencia (LED continua) · 3 s = libera parear um celular novo (2 min, luzes correndo) ·
10 s = apaga o Wi-Fi salvo e reinicia.

### 6.4 Dados na caixa
- `/config.json` (LittleFS): `nome`, `paciente`, `remedios[{id,nome,dose}]`,
  `dias[7]{ativo,hora,remedios[ids]}`, `tolerancia_min`, `antecipa_min`, `repete_min`, `alarme_seg`,
  `som`, `telegram{ativo,token,chat,avisa_tomada}`, `fuso_min` (−180 = Brasília).
- `/eventos.jsonl`: uma linha por evento `{ts (UTC), dia, tipo, info}`; gira em ~40 KB (guarda o
  arquivo anterior). Tipos: `ligou`, `alarme`, `atrasada`, `tomada`, `tomada_atrasada`, `perdida`,
  `errada`, `fora_horario`, `abertura`, `reabastecer`.
- NVS: token do app e estado do dia.

### 6.5 API
Ver `README.md` (tabela de rotas). Porta 8080, mDNS `caixa-remedios.local`, cabeçalho `X-Token`.

---

## 7. App (ESCRITO em `app/` — Flutter, Android; não compilado localmente)

Telas (letras maiores, botões grandes, poucas opções por tela):
1. **Conectar**: passo a passo do Wi-Fi da caixa, busca automática na rede local ou IP digitado.
2. **Hoje**: dia, hora e remédios em letras grandes; estado colorido; botão **Tomei** (com confirmação)
   e **Silenciar alarme**; semana com tampas abertas; avisos de caixa sem hora, sem contato e
   reabastecendo.
3. **Agenda**: cadastro de remédios (nome e dose); por dia: liga/desliga, hora, quais remédios,
   "copiar para todos os dias". Só grava na caixa ao tocar em "Gravar na caixa".
4. **Histórico**: resumo dos últimos 7 dias (no horário, com atraso, não tomou) e lista de eventos.
5. **Ajustes**: nome da pessoa, som, tolerância, antecipação, repetição do alarme, Telegram (passo a
   passo com "Achar conversa" e "Testar"), reabastecer, testar luzes e som, acertar hora, desconectar.

**Notificações no celular** (`flutter_local_notifications`): lembrete semanal em cada dia/hora da
agenda e um "Você já tomou?" depois da tolerância, cancelado quando a caixa informa que foi tomado.
São reagendadas toda vez que o app abre ou a agenda muda. Tentam horário exato; se o Android negar,
usam horário aproximado.

Se o endereço da caixa mudar (DHCP), o app procura de novo pelo identificador da caixa.

---

## 8. Modelo 3D (v3, tudo por encaixe — GERADO; a v2 foi impressa, a v3 ainda não)

Arquivo-fonte: `cad/caixa_remedios.scad` (OpenSCAD 2021.01, paramétrico). Os STLs em `cad/stl/` são
gerados dele e convertidos para STL binário com `cad/stl_binario.js`. Versões anteriores ficam só como
referência: v1 (parafusos) em `cad/caixa_remedios_v1.scad`, `cad/stl/v1/`, `cad/preview/v1/`;
v2 (primeira impressão) em `cad/caixa_remedios_v2.scad`, `cad/stl/v2/`, `cad/preview/v2/`.

### 8.1 O que mudou da v2 para a v3 (pedido do usuário depois de imprimir a v2, 2026-11-18)
| Tema | v2 | v3 |
|---|---|---|
| Dobradiça | pino de filamento de 152 mm atravessando orelhas | **encaixe**: cada tampa tem um eixo impresso (Ø 3,2) entre dois braços; o corpo tem um grampo em C por compartimento, boca para trás. A tampa clica e sai sem ferramenta |
| Firmeza da tampa | só a trava frontal; folga lateral livre | **saia em U** (frente + laterais, 2,4 mm) que entra no compartimento com 0,15 mm de folga por lado: a tampa não balança e fecha o compartimento |
| Trava frontal | ressalto simétrico de 0,5 mm | ressalto de 0,55 mm com **rampa longa para fechar e degrau curto para segurar**; canaleta de 0,7 mm no corpo; aba de 1,4 mm |
| Reed | em pé, entrava por baixo (não dava para colocar e, em pé, não aciona) | **deitado** (horizontal, ao longo da fileira) num canal aberto no topo da parede frontal, rente à borda da tampa; topo do vidro a 0,1 mm do topo do corpo (≈0,25 mm do ímã). As pernas dobram a 2 mm do vidro e descem por **furos fechados por dentro da parede** (Ø 2,2) até a bay, já emendadas com fio fino; nada aparece na frente |
| Ímã | em cima da ponta do reed em pé | na tampa, em cima do vidro, **deslocado 4,5 mm do centro** (`mag_dx`): com ímã de disco deitado, o centro do reed é ponto morto |
| ESP32 | 2,1 mm longe da parede, garras + 4 apoios de canto, folga grande | a ponta do lado do USB entra 0,8 mm num **rasgo da própria parede** (conector USB-C fica dentro do furo); trilho frontal no comprimento todo, a parede traseira é o outro trilho (0,15 mm de folga); 2 batentes no teto; gancho flexível na ponta da antena |
| Furo do USB-C | retangular | cantos arredondados (13 × 7,5) |
| Prévias | só a caixa | também **componentes montados** (vista de baixo, transparente e corte do reed) |

### 8.2 Medidas dos componentes usadas (e origem)
| Componente | Valor usado | Origem |
|---|---|---|
| Reed (vidro) | 14 × 2,2 mm, terminais de ~15,5 mm; canal do vidro 14,6 × 2,4 mm, furos das pernas Ø 2,2 mm por dentro da parede | Anúncio enviado pelo usuário |
| Ímã | 5 × 1 mm; bolsão de 5,15 × 1,2 mm | Anúncio enviado pelo usuário |
| LED | 5 mm, aro 5,9 mm | **ASSUMIDO** (trocar `led_d`/`led_flange` para 3 / 3,8 se for de 3 mm) |
| ESP32 DevKit V1, 30 pinos, USB-C | 51,5 × 28,3 × 1,6 mm; USB-C passando ~1 mm da borda | **ASSUMIDO** (`esp_l`, `esp_w`, `usbc_out`) |
| RTC DS3231 | módulo ZS-042, 38 × 22 × 1,6 mm | **ASSUMIDO** (`rtc_l`, `rtc_w`) |
| Placa do 74HC595 | placa perfurada cortada em 24 × 28 mm | **ASSUMIDO / a definir** (`aux_l`, `aux_w`) |
| Plugue USB-C | furo de 13 × 7,5 mm | **ASSUMIDO** |
| Botão | chave tátil 6 × 6, altura total 5 mm | **ASSUMIDO** (`btn_h`) |
| Buzzer | 12 mm de diâmetro | **ASSUMIDO** (`buz_d`) |

### 8.3 Peças geradas
| Arquivo | Conteúdo | Tamanho na mesa (mm) |
|---|---|---|
| `caixa_corpo.stl` | Corpo, já virado (topo na mesa) | 153,2 × 47,5 × 49,0 |
| `caixa_base.stl` | Tampa de baixo com lábio e ressaltos | 152,8 × 37,0 × 6,7 |
| `caixa_tampas_x7.stl` | 7 tampas (DOM…SAB), topo na mesa, em 2 fileiras | 94,6 × 101,0 × 9,2 |
| `teste_corpo_1dia.stl`, `teste_tampa_1dia.stl`, `teste_base_1dia.stl` | Mesmo projeto com 1 dia, sem eletrônica | corpo 23,2 × 47,5 × 49,0 |

Caixa montada: ~153 × 51 × 54 mm. O corpo cabe reto numa mesa de 165 mm (Ender 2 Pro) ou 220 mm (Ender 3).

### 8.4 Sistema de coordenadas (no `.scad`)
- **X**: ao longo da fileira (0 = lado do USB). **Y**: profundidade (0 = frente). **Z**: altura (0 = fundo do corpo).
- Bay da eletrônica: z 0–27. Piso dos compartimentos: z 27–29. Compartimentos: z 29–49. Tampa: z 49,15–52,15.
- Vidro do reed: deitado em z ≈ 46,8 (centro), x = centro do compartimento ± 7. Eixo da dobradiça: y 40,5, z 46.

### 8.5 Parâmetros principais (os que mais provavelmente vão precisar de ajuste)
| Parâmetro | Valor | Efeito |
|---|---|---|
| `sk_gap` | 0,15 | folga da saia da tampa no compartimento. Apertado demais → subir para 0,2; folgado → 0,1 |
| `snap_b`, `snap_g`, `apr_t` | 0,55 / 0,7 / 1,4 | força do clique da frente. Fraco → `snap_b` 0,65; duro demais → 0,45 ou `apr_t` 1,2 |
| `mouth`, `rod_d`, `rod_gap` | 2,7 / 3,2 / 0,15 | clique da dobradiça. Sai fácil → `mouth` 2,5; não entra / racha → 2,9 |
| `mag_dx` | 4,5 | posição do ímã ao longo do vidro (0 = centro = ponto morto). **Ajustar no teste**: passar o ímã sobre o reed com o multímetro e anotar onde fecha |
| `reed_sink`, `reed_cw`, `reed_bend`, `reed_hole` | 0,1 / 2,4 / 2,0 / 2,2 | fundura e largura do canal do vidro, dobra das pernas, furo das pernas (subir para 2,5 se a emenda não passar) |
| `mag_stack` | 1 | 2 = dois ímãs empilhados (bolsão mais fundo) |
| `esp_l`, `esp_w`, `esp_in`, `esp_so` | 51,5 / 28,3 / 0,8 / 5 | berço do ESP32 (medir a placa!) |
| `led_d`, `led_flange` | 5 / 5,9 | LED |
| `lip_gap`, `bsnap_b`, `bsnap_g` | 0,25 / 0,5 / 0,6 | encaixe da base |

### 8.6 Como tudo encaixa
- **Reed**: antes, emendar um fio fino (26–30 AWG) em cada perna (solda pequena, termorretrátil fino ou
  nenhum), porque os terminais (~15 mm) não chegam à bay. Dobrar as duas pernas para baixo a ~2 mm do vidro
  (nunca rente), passar os fios pelos dois furos do topo da parede frontal (com a tampa aberta) e puxar por
  baixo até o vidro deitar no canal. Tudo fica escondido dentro da parede; as pernas dobradas seguram o
  vidro. Uma gota de cola quente na saída dos furos, dentro da bay, firma os fios.
- **Ímã**: prensado no bolsão por baixo da tampa, a ~0,25 mm do vidro, deslocado 4,5 mm do centro do reed
  (`mag_dx`). Tampa fechada → reed fechado. Se não acionar, mudar `mag_dx` (testar antes com a mão).
- **Tampa**: saia em U entra no compartimento (alinha e fecha); a aba da frente desce pela frente do
  corpo e o ressalto clica na canaleta. Para abrir, puxar a aba para cima.
- **Dobradiça**: colocar a tampa em pé (aberta, ~90°) atrás da caixa e empurrar o eixo para a frente,
  para dentro da boca do grampo, até clicar. O arco de cima do grampo flexiona. Para tirar, puxar a tampa
  aberta para trás. A tampa aberta para em ~95–100° encostando na prateleira traseira.
- **ESP32**: pendurado no teto da bay, componentes para cima, pinos para baixo. Inclinar a placa, enfiar
  a ponta do USB no rasgo da parede esquerda (o conector entra no furo do USB-C) e girar até o gancho da
  outra ponta clicar. Os trilhos impedem que ela ande para os lados.
- **RTC e placa do 74HC595**: berços da v2, ao lado do ESP32.
- **LEDs, botão, buzzer, base**: como na v2 (LED por dentro na parede frontal; chave tátil no bolso atrás
  da lingueta; buzzer no clipe em C; base por pressão com rebaixo para moeda).
- **Fiação**: os fios dos reeds saem no canto frente/teto da bay, bem acima dos LEDs.

Prévias: `cad/preview/previa_componentes_baixo.png` (caixa de cabeça para baixo, sem a base, com os
componentes), `previa_componentes_transparente.png`, `previa_corte_reed.png`, `previa_reed_zoom.png`
(corte no ímã: vidro deitado, ímã, saia e trava) e `previa_reed_frente.png` (parede transparente: reed deitado, pernas e fios descendo pelos furos), `previa_montada.png`, `previa_aberta.png`,
`previa_interior.png`, `previa_impressao_tampas.png`. Os componentes nas prévias são desenhos aproximados.

### 8.7 Impressão (sem suportes)
- **Corpo**: como está no STL, de cabeça para baixo. As pontes são os pisos dos compartimentos (20 mm).
- **Tampas**: topo na mesa; saia, braços e eixo ficam para cima. O eixo é uma ponte curta de 9,6 mm.
- **Base**: placa na mesa.
- PLA ou PETG, camada 0,2 mm (0,12–0,16 mm melhora os cliques), 3 paredes, bico 0,4. Desligar
  "compensação de furos/expansão horizontal" ou ajustar `sk_gap`/`rod_gap` depois do teste.
- **Imprimir primeiro as 3 peças de teste de 1 dia** (corpo, tampa, base) e ajustar os parâmetros da 8.5.

### 8.8 Verificações feitas (no computador)
- Todos os STLs: sólido válido ("Simple: yes"); corpo e base em peça única; 7 tampas separadas.
- Interseção corpo × tampas fechadas = vazia. Corpo × base = vazia.
- Tampa abrindo: sem colisão a 45° e 90°; encosta na prateleira a 100° (batente).
- ESP32 desenhado × corpo: só o contato previsto dos batentes na face de cima da placa.

### 8.9 O que **não** foi verificado (ASSUMIDO / risco)
- **A v3 não foi impressa.** Folgas e força dos cliques (8.5) provavelmente pedem um ajuste na peça de teste.
- **Grampo da dobradiça**: peça fina (arco de 1,25 mm). Em PLA pode rachar se `mouth` ficar apertada;
  PETG é mais tolerante.
- **Reed + ímã**: reed deitado com ímã de disco por cima: o acionamento depende da posição ao longo do vidro
  (o centro é ponto morto). `mag_dx = 4,5` é um chute; medir com o reed e o ímã reais e ajustar.
- **Medidas do ESP32** (comprimento, largura, quanto o USB-C passa da borda, área livre para os batentes
  entre a fileira de pinos e o módulo) são ASSUMIDAS. Medir antes de imprimir o corpo inteiro.
- RTC, placa do 595, botão, buzzer, LED e plugue USB: medidas ASSUMIDAS (como na v2).

### 8.10 Regenerar as peças e prévias
```bash
openscad -o cad/stl/caixa_corpo.stl      -D 'part="body"' cad/caixa_remedios.scad
openscad -o cad/stl/caixa_base.stl       -D 'part="base"' cad/caixa_remedios.scad
openscad -o cad/stl/caixa_tampas_x7.stl  -D 'part="lids"' cad/caixa_remedios.scad
openscad -o cad/stl/teste_corpo_1dia.stl -D n=1 -D 'part="body"' cad/caixa_remedios.scad
openscad -o cad/stl/teste_tampa_1dia.stl -D n=1 -D 'part="lid1"' cad/caixa_remedios.scad
openscad -o cad/stl/teste_base_1dia.stl  -D n=1 -D 'part="base"' cad/caixa_remedios.scad
deno run --allow-read --allow-write cad/stl_binario.js cad/stl/*.stl
# Conferência de colisão: o OpenSCAD deve responder "Current top level object is empty"
openscad -o c.stl -D 'part="chk_lids"' cad/caixa_remedios.scad
openscad -o c.stl -D 'part="chk_base"' cad/caixa_remedios.scad
openscad -o c.stl -D 'part="chk_open"' -D ang=90 cad/caixa_remedios.scad
# Prévia dos componentes (vista de baixo)
openscad -o cad/preview/previa_componentes_baixo.png -D 'part="components"' --imgsize=1800,1000 --viewall --autocenter --colorscheme=Tomorrow --camera=0,0,0,12,0,8,0 cad/caixa_remedios.scad
```
Valores de `part`: `body`, `base`, `lids`, `lid1`, `assembly`, `open`, `components`, `ghost`,
`comp_cut`, `cut`, `a_body`, `a_base`, `a_lids`, `a_lids_open`, `chk_lids`, `chk_open`, `chk_base`,
`chk_esp`, `chk_comp`, `reed_front`.

---

## 9. Registro de decisões

| # | Decisão | Estado |
|---|---|---|
| 1 | MVP com fileira única de 7 dias, com sensor de abertura | DECIDIDO |
| 2 | Versão de 3 turnos como evolução, com LED por compartimento | DECIDIDO (futuro) |
| 3 | Detector de abertura (reed + ímã) como diferencial | DECIDIDO |
| 4 | ESP32 como controlador; RTC DS3231 para hora offline | DECIDIDO / PROPOSTO |
| 5 | Máquina de estados com tolerância e atraso | PROPOSTO |
| 6 | Alertas escalonados (LED/buzzer → push → cuidador) | PROPOSTO |
| 7 | Sem nuvem: app fala com a caixa por HTTP na rede local; cuidador avisado pela caixa via Telegram; sem Firebase/MQTT/BLE | PROPOSTO (implementado; usuário pode trocar) |
| 15 | App em Flutter, só Android, APK pelo GitHub Actions | DECIDIDO (usuário pediu Actions + celular) |
| 8 | 74HC595 para os LEDs (3 pinos) | PROPOSTO |
| 9 | Caixa impressa em 3D, Ender 2/3 | DECIDIDO |
| 10 | Tudo por encaixe, sem parafusos nem pino: dobradiça de eixo impresso + grampo em C (v3; a v2 usava pino de filamento) | DECIDIDO (pedido do usuário) |
| 13 | Compartimento de 20 mm de largura (era 18) para caber a eletrônica presa em berços | PROPOSTO |
| 14 | Reed **deitado** no topo da parede frontal, sob a borda da tampa, colocado por cima; pernas por furos fechados dentro da parede (nada aberto na frente); ímã na tampa deslocado do centro (v3) | DECIDIDO (usuário: em pé o reed não funciona) |
| 11 | Pinagem da seção 5 (corrige a lista anterior que conflitava com I2C) | PROPOSTO |
| 12 | É lembrete, não dispositivo médico | DECIDIDO (aviso obrigatório) |

---

## 10. Pendências (para o usuário ou para o Claude Code)

**Perguntas abertas ao usuário**
- Tamanho do LED (3 mm ou 5 mm); cor dos LEDs (azul/branco muda a ligação do 595).
- Ender 2 ou Ender 3 (afeta se dá para aumentar a caixa).
- Modelo exato do botão (tátil de placa ou de painel); se for tátil, desenhar suporte/capuz.
- Já comprou os itens? Placa ESP32 realmente de 30 pinos?

**Tarefas de desenvolvimento**
1. ~~Firmware do MVP~~ escrito; falta compilar no Actions e testar na protoboard.
2. Diagrama elétrico (resistores, transistor do buzzer, 74HC595, RTC, reeds, botão).
3. ~~App~~ escrito; falta o primeiro build no Actions e teste no celular com a caixa.
4. Limitações conhecidas: o app só fala com a caixa na mesma rede Wi-Fi (fora de casa só recebe os
   lembretes agendados); HTTP sem criptografia na rede local; Telegram sem validar certificado.
5. Testes: imprimir as peças de teste de 1 dia da **v3** (dobradiça de encaixe, saia, trava, canal do reed deitado e furos das pernas), achar o `mag_dx` com o reed e o ímã reais, medir o ESP32 e ajustar os parâmetros da seção 8.5; reed + ímã na protoboard.
6. Evoluções: 3 turnos, botão arcade grande, texto gravado, tampa que fecha com trava.
7. Documentação final para a cadeira: arquitetura, diagrama, BOM com preços atuais, resultados de testes, aviso de que não é dispositivo médico.
