# Caixa de remédios inteligente (IoT)

Caixa semanal com ESP32: acende a luz do dia, apita na hora do remédio, **percebe sozinha
quando a tampa certa é aberta** (reed switch + ímã) e avisa o cuidador se a dose atrasar.
Projeto final da cadeira de IoT.

> É um **lembrete**, não um dispositivo médico.

| Pasta | O que tem |
|---|---|
| `cad/` | Modelo 3D (OpenSCAD) e STLs prontos para imprimir, sem parafusos |
| `firmware/` | Programa do ESP32 (PlatformIO) |
| `app/` | App Android (Flutter) |
| `docs/DOCUMENTACAO.md` | Documentação completa: decisões, pinagem, hardware, modelo 3D |

## Como funciona

```
 Tampa aberta (reed) ─┐
 Botão ───────────────┤                ┌─> LEDs (74HC595)
 RTC DS3231 ──────────┼──> ESP32 ──────┼─> Buzzer
                      │      │         └─> Telegram do cuidador (internet)
                      │      └── Wi-Fi da casa ── API HTTP :8080 ── App no celular
```

- **A caixa decide sozinha.** Agenda, alarme, luzes e histórico ficam no ESP32 e funcionam sem
  internet. O RTC guarda a hora; quando há internet, ela é acertada pelo NTP.
- **O app** configura a agenda, mostra o estado e o histórico, e agenda lembretes no próprio celular
  (tocam mesmo com o app fechado ou longe de casa).
- **O cuidador** recebe mensagem no Telegram, enviada pela própria caixa, quando a dose atrasa ou o
  dia termina sem a dose. Não precisa de servidor.

### Ciclo de cada dose

| Estado | Quando | Caixa | App / cuidador |
|---|---|---|---|
| Aguardando | antes da hora | luz apagada | — |
| Alarme | chegou a hora | luz do dia acesa, bipes a cada 5 min (botão silencia) | notificação no celular |
| Atrasada | passou a tolerância (30 min) | luz piscando, bipes continuam | "já tomou?" no celular + Telegram |
| Tomada | abriu a tampa certa | luz apaga, bipe de confirmação | registro com a hora |
| Perdida | virou o dia sem abrir | — | Telegram + registro |

- Abrir até 60 min **antes** da hora conta como tomada.
- Abrir a **tampa errada** durante o alarme: a luz certa pisca rápido e fica registrado.
- **Reabastecer** (no app): acende todas as luzes por 10 min e as aberturas não contam.

### Botão da caixa

| Toque | Ação |
|---|---|
| Curto | Silencia o alarme (a luz continua) |
| 3 segundos | Libera conectar um celular novo (luzes correm por 2 min) |
| 10 segundos | Apaga o Wi-Fi salvo e reinicia |

## Primeiro uso

1. Grave o firmware (abaixo) e ligue a caixa.
2. No celular, conecte na rede **CaixaRemedios-XXXX**. Abre uma página: escolha o Wi-Fi da casa.
3. Instale o app, volte para o Wi-Fi da casa e toque em **Procurar caixa** → **Conectar**.
4. Na aba **Agenda**, cadastre os remédios e marque os dias e horários. Toque em **Gravar na caixa**.

## Firmware

```bash
pip install platformio
pio run -d firmware -t upload     # grava pelo USB
pio device monitor -d firmware    # mostra o log
```

O GitHub Actions também compila e deixa o `.bin` em **Actions → Firmware ESP32 → Artifacts**.

## App

O GitHub Actions gera o APK a cada mudança em `app/`: **Actions → App Android → Artifacts**.
Criando uma tag `app-v0.1.0`, o APK vai para a página **Releases**.

Secrets necessários para assinar o APK (sem eles sai com chave de debug):
`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`.

Para compilar localmente:
```bash
cd app
flutter create --platforms=android --org br.caixaremedios --project-name caixa_remedios .
cp -r android_extra/. android/
flutter run
```

## API da caixa (porta 8080)

Todas as rotas, menos `info` e `parear`, pedem o cabeçalho `X-Token` recebido no pareamento.

| Rota | Função |
|---|---|
| `GET /api/info` | identifica a caixa (usado na busca) |
| `POST /api/parear` | entrega o token (só na primeira vez ou após segurar o botão 3 s) |
| `GET /api/estado` | dia, estado da dose, tampas, alarme tocando, Wi-Fi |
| `GET/PUT /api/config` | agenda e ajustes (JSON) |
| `GET /api/eventos?limite=N` | histórico, mais recente primeiro |
| `POST /api/tomei` · `/api/silenciar` · `/api/teste` | ações |
| `POST /api/reabastecer` `{"min":10}` | modo reabastecer (0 encerra) |
| `POST /api/hora` `{"epoch":...}` | acerta o relógio |
| `POST /api/telegram/chat` · `/api/telegram/teste` | configurar o aviso ao cuidador |
