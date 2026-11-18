// =====================================================================
//  Caixa de remedios inteligente - firmware do ESP32 (MVP, 7 dias)
//
//  - Funciona sozinha: agenda, alarme, LEDs e historico nao dependem de rede.
//  - Wi-Fi: sem Wi-Fi salvo, cria a rede "CaixaRemedios-XXXX" (senha
//    "remedios"); o app entra nela e configura o Wi-Fi da casa pela API.
//  - Wi-Fi, pareamento, agenda e estado do dia ficam na NVS: sobrevivem a
//    regravacoes do firmware (so o botao apaga). Historico no LittleFS.
//  - API HTTP na porta 8080 para o app (cabecalho X-Token).
//  - Aviso ao cuidador por bot do Telegram (opcional).
//  - E um lembrete, nao um dispositivo medico.
//
//  Botao: toque curto = silencia o alarme | 3 s = parear app
//         10 s = apagar o Wi-Fi | 20 s = apagar tudo (padrao de fabrica)
// =====================================================================
#include <Arduino.h>
#include <WiFi.h>
#include <WebServer.h>
#include <ESPmDNS.h>
#include <Preferences.h>
#include <LittleFS.h>
#include <Wire.h>
#include <RTClib.h>
#include <ArduinoJson.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <esp_sntp.h>
#include <time.h>
#include <sys/time.h>
#include <vector>
#include "pins.h"

#define FW_VERSION "0.2.0"
static const char* AP_SENHA   = "remedios";          // senha da rede de configuracao (min. 8)
static const char* ARQ_CFG    = "/config.json";      // so para migrar da 0.1 (agora a agenda fica na NVS)
static const char* ARQ_EV     = "/eventos.jsonl";
static const char* ARQ_EV_OLD = "/eventos.old";
static const uint16_t PORTA_API = 8080;

static const char* CFG_PADRAO = R"({"nome":"Caixa de remédios","paciente":"","remedios":[],
"dias":[{"ativo":false,"hora":"08:00","remedios":[]},{"ativo":false,"hora":"08:00","remedios":[]},
{"ativo":false,"hora":"08:00","remedios":[]},{"ativo":false,"hora":"08:00","remedios":[]},
{"ativo":false,"hora":"08:00","remedios":[]},{"ativo":false,"hora":"08:00","remedios":[]},
{"ativo":false,"hora":"08:00","remedios":[]}],
"tolerancia_min":30,"antecipa_min":60,"repete_min":5,"alarme_seg":60,"som":true,
"telegram":{"ativo":false,"token":"","chat":"","avisa_tomada":false},"fuso_min":-180})";

// ---------------------------------------------------------------- estado
struct DiaCfg { bool ativo = false; uint16_t minuto = 480; };
struct Cfg {
  DiaCfg dias[N_DIAS];
  int tol = 30, antecipa = 60, repete = 5, alarmeSeg = 60, fusoMin = -180;
  bool som = true, tgAtivo = false, tgTomada = false;
  String tgToken, tgChat, nome, paciente;
} cfg;

enum Status : uint8_t { SEM_DOSE, AGUARDANDO, ALARME, ATRASADA, TOMADA, PERDIDA };
static const char* STATUS_TXT[] = {"sem_dose", "aguardando", "alarme", "atrasada", "tomada", "perdida"};
static const char* DIA_TXT[] = {"domingo", "segunda", "terça", "quarta", "quinta", "sexta", "sábado"};

struct Hoje { uint32_t ymd = 0; uint8_t dia = 0; Status st = SEM_DOSE; uint32_t tomadaEm = 0; } hoje;

RTC_DS3231 rtc;
bool rtcPresente = false;
WebServer server(PORTA_API);
bool serverOn = false;
Preferences prefs;
String apNome, chipId, token;

// Wi-Fi: credenciais salvas por nos na NVS (WiFi.persistent(false))
String wSsid, wSenha;
bool modoConfig = false;                    // rede "CaixaRemedios-XXXX" no ar
uint32_t apDesligarEm = 0;
enum Tentativa : uint8_t { T_NADA, T_CONECTANDO, T_OK, T_FALHOU };
static const char* TENT_TXT[] = {"nada", "conectando", "ok", "falhou"};
Tentativa tent = T_NADA;
String tentSsid, tentSenha, tentErro;
uint32_t tentDesde = 0;
bool tentIniciou = false;

bool tampaAberta[N_DIAS];
bool tampaBruta[N_DIAS];
uint32_t tampaMudou[N_DIAS];

uint32_t pareandoAte = 0, reabastecerAte = 0, erradoAte = 0;
uint32_t rajadaIni = 0, alarmeDesde = 0;
bool silenciado = false;
std::vector<String> filaTelegram;

static bool antes(uint32_t ate) { return ate != 0 && (int32_t)(ate - millis()) > 0; }

// ---------------------------------------------------------------- relogio
bool relogioOk() { return time(nullptr) > 1700000000; }
uint32_t agoraUtc() { return (uint32_t)time(nullptr); }

void horaLocal(struct tm& t) {
  time_t l = time(nullptr) + (time_t)cfg.fusoMin * 60;
  gmtime_r(&l, &t);
}

void ajustaRelogio(uint32_t epoch) {
  struct timeval tv = {(time_t)epoch, 0};
  settimeofday(&tv, nullptr);
  if (rtcPresente) rtc.adjust(DateTime(epoch));
}

void relogioInicio() {
  Wire.begin(PIN_SDA, PIN_SCL);
  rtcPresente = rtc.begin();
  if (rtcPresente && !rtc.lostPower()) {
    uint32_t e = rtc.now().unixtime();
    if (e > 1700000000) {
      struct timeval tv = {(time_t)e, 0};
      settimeofday(&tv, nullptr);
    }
  }
  Serial.printf("RTC: %s, relogio %s\n", rtcPresente ? "ok" : "ausente", relogioOk() ? "ok" : "sem hora");
}

// Quando o NTP sincroniza, copia a hora para o RTC.
void relogioTick() {
  static uint32_t t = 0;
  if (millis() - t < 5000) return;
  t = millis();
  if (sntp_get_sync_status() == SNTP_SYNC_STATUS_COMPLETED && rtcPresente && relogioOk()) {
    rtc.adjust(DateTime(agoraUtc()));
    Serial.println("RTC acertado pelo NTP");
  }
}

// ---------------------------------------------------------------- LEDs (um GPIO por dia)
uint8_t ledAtual = 0xFF;
void ledsEscreve(uint8_t bits) {          // bit i = LED do dia i
  if (bits == ledAtual) return;
  ledAtual = bits;
  for (uint8_t i = 0; i < N_DIAS; i++) digitalWrite(LED_PINS[i], (bits >> i) & 1 ? HIGH : LOW);
}

void ledsTick() {
  uint32_t m = millis();
  uint8_t b = 0;
  if (antes(reabastecerAte)) b = 0x7F;                               // reabastecendo: todos acesos
  else if (antes(pareandoAte)) b = 1 << ((m / 150) % N_DIAS);        // pareando: luz correndo
  else if (modoConfig && wSsid.isEmpty()) b = ((m / 700) % 2) ? 0x08 : 0; // sem Wi-Fi: LED do meio piscando
  else if (!relogioOk()) b = ((m / 1000) % 2) ? 0x41 : 0;            // sem hora: pontas piscando
  else {
    if (hoje.st == ALARME) b = 1 << hoje.dia;
    if (hoje.st == ATRASADA && (m / 500) % 2) b = 1 << hoje.dia;
    if (antes(erradoAte)) b = ((m / 120) % 2) ? (1 << hoje.dia) : 0; // tampa errada: pisca rapido o certo
  }
  ledsEscreve(b);
}

// ---------------------------------------------------------------- buzzer
uint16_t seq[8];
uint8_t seqLen = 0, seqPos = 0;
uint32_t seqT = 0;

// Sequencia avulsa: liga, desliga, liga... (ms)
void bip(std::initializer_list<uint16_t> d) {
  seqLen = 0;
  for (auto v : d) if (seqLen < 8) seq[seqLen++] = v;
  seqPos = 0;
  seqT = millis();
}

bool alarmeTocando() {
  if (hoje.st != ALARME && hoje.st != ATRASADA) return false;
  if (!cfg.som) return false;
  uint32_t m = millis();
  if (m - alarmeDesde > 120UL * 60000UL) return false;              // depois de 2 h so o LED
  if (m - rajadaIni >= (uint32_t)cfg.repete * 60000UL) { rajadaIni = m; silenciado = false; }
  if (silenciado) return false;
  return (m - rajadaIni) < (uint32_t)cfg.alarmeSeg * 1000UL;
}

void buzzerTick() {
  uint32_t m = millis();
  bool on = false;
  if (seqPos < seqLen) {
    if (m - seqT >= seq[seqPos]) { seqPos++; seqT = m; }
    on = seqPos < seqLen && (seqPos % 2 == 0);
  } else if (alarmeTocando()) {
    uint32_t f = (m - rajadaIni) % 1600;
    on = f < 200 || (f >= 400 && f < 600) || (f >= 800 && f < 1000);
  }
  digitalWrite(PIN_BUZZER, on ? HIGH : LOW);
}

void entraAlarme() {
  hoje.st = ALARME;
  rajadaIni = alarmeDesde = millis();
  silenciado = false;
}

// ---------------------------------------------------------------- persistencia
void salvaHoje() {
  prefs.putUInt("ymd", hoje.ymd);
  prefs.putUChar("dia", hoje.dia);
  prefs.putUChar("st", (uint8_t)hoje.st);
  prefs.putUInt("tom", hoje.tomadaEm);
}

void carregaHoje() {
  hoje.ymd = prefs.getUInt("ymd", 0);
  hoje.dia = prefs.getUChar("dia", 0) % N_DIAS;
  uint8_t s = prefs.getUChar("st", 0);
  hoje.st = s <= PERDIDA ? (Status)s : SEM_DOSE;
  hoje.tomadaEm = prefs.getUInt("tom", 0);
  if (hoje.st == ALARME || hoje.st == ATRASADA) { rajadaIni = alarmeDesde = millis(); }
}

void aplicaCfg(JsonDocument& d) {
  cfg.nome = d["nome"] | "Caixa de remédios";
  cfg.paciente = d["paciente"] | "";
  JsonArray a = d["dias"];
  for (uint8_t i = 0; i < N_DIAS; i++) {
    JsonObject o = a[i];
    cfg.dias[i].ativo = o["ativo"] | false;
    const char* h = o["hora"] | "08:00";
    int hh = atoi(h), mm = strlen(h) >= 5 ? atoi(h + 3) : 0;
    cfg.dias[i].minuto = constrain(hh, 0, 23) * 60 + constrain(mm, 0, 59);
  }
  cfg.tol       = constrain((int)(d["tolerancia_min"] | 30), 5, 240);
  cfg.antecipa  = constrain((int)(d["antecipa_min"] | 60), 0, 720);
  cfg.repete    = constrain((int)(d["repete_min"] | 5), 1, 60);
  cfg.alarmeSeg = constrain((int)(d["alarme_seg"] | 60), 5, 300);
  cfg.fusoMin   = constrain((int)(d["fuso_min"] | -180), -720, 840);
  cfg.som       = d["som"] | true;
  cfg.tgAtivo   = d["telegram"]["ativo"] | false;
  cfg.tgTomada  = d["telegram"]["avisa_tomada"] | false;
  cfg.tgToken   = d["telegram"]["token"] | "";
  cfg.tgChat    = d["telegram"]["chat"] | "";
}

// A agenda fica na NVS (chave "cfg"): sobrevive a regravacao do firmware e a troca
// do esquema de particao. A NVS guarda textos de ate ~4000 bytes.
static const size_t CFG_MAX = 3900;

String leCfgBruta() {
  String s = prefs.getString("cfg", "");
  return s.length() > 10 ? s : String(CFG_PADRAO);
}

// Firmware 0.1 guardava a agenda em /config.json: copia para a NVS uma vez.
void migraCfg() {
  if (prefs.isKey("cfg")) return;
  File f = LittleFS.open(ARQ_CFG, "r");
  if (!f) return;
  String s = f.readString();
  f.close();
  if (s.length() > 10 && s.length() <= CFG_MAX) {
    prefs.putString("cfg", s);
    LittleFS.remove(ARQ_CFG);
    Serial.println("Agenda migrada do LittleFS para a NVS");
  }
}

void carregaCfg() {
  migraCfg();
  JsonDocument d;
  if (deserializeJson(d, leCfgBruta())) deserializeJson(d, CFG_PADRAO);
  aplicaCfg(d);
}

void evento(const char* tipo, int dia, const String& info = "") {
  Serial.printf("[evento] %s dia=%d %s\n", tipo, dia, info.c_str());
  File f = LittleFS.open(ARQ_EV, "a");
  if (!f) return;
  JsonDocument d;
  d["ts"] = relogioOk() ? agoraUtc() : 0;
  d["dia"] = dia;
  d["tipo"] = tipo;
  if (info.length()) d["info"] = info;
  serializeJson(d, f);
  f.print('\n');
  size_t tam = f.size();
  f.close();
  if (tam > 40000) { LittleFS.remove(ARQ_EV_OLD); LittleFS.rename(ARQ_EV, ARQ_EV_OLD); }
}

// ---------------------------------------------------------------- Telegram
void avisa(const String& msg) {
  if (!cfg.tgAtivo || cfg.tgToken.isEmpty() || cfg.tgChat.isEmpty()) return;
  if (filaTelegram.size() >= 10) filaTelegram.erase(filaTelegram.begin());
  filaTelegram.push_back(msg);
}

bool telegramEnvia(const String& tk, const String& chat, const String& msg) {
  WiFiClientSecure c;
  c.setInsecure();                       // sem validar certificado: suficiente para um aviso
  HTTPClient h;
  h.setTimeout(8000);
  if (!h.begin(c, "https://api.telegram.org/bot" + tk + "/sendMessage")) return false;
  h.addHeader("Content-Type", "application/json");
  JsonDocument d;
  d["chat_id"] = chat;
  d["text"] = msg;
  String corpo;
  serializeJson(d, corpo);
  int code = h.POST(corpo);
  h.end();
  return code == 200;
}

void telegramTick() {
  static uint32_t proxima = 0;
  if (filaTelegram.empty() || WiFi.status() != WL_CONNECTED || antes(proxima)) return;
  bool ok = telegramEnvia(cfg.tgToken, cfg.tgChat, filaTelegram.front());
  if (ok) filaTelegram.erase(filaTelegram.begin());
  proxima = millis() + (ok ? 3000 : 30000);            // se falhou, tenta de novo em 30 s
  if (proxima == 0) proxima = 1;
}

String quem() { return cfg.paciente.length() ? cfg.paciente : String("A pessoa"); }
String horaTxt(uint16_t minuto) {
  char b[6];
  snprintf(b, sizeof b, "%02d:%02d", minuto / 60, minuto % 60);
  return String(b);
}

// ---------------------------------------------------------------- logica das doses
void marcaTomada(const String& info) {
  bool atrasada = hoje.st == ATRASADA;
  hoje.st = TOMADA;
  hoje.tomadaEm = agoraUtc();
  salvaHoje();
  evento(atrasada ? "tomada_atrasada" : "tomada", hoje.dia, info);
  bip({90, 60, 250});
  if (atrasada) avisa("✅ " + quem() + " tomou o remédio de " + DIA_TXT[hoje.dia] + " (com atraso).");
  else if (cfg.tgTomada) avisa("✅ " + quem() + " tomou o remédio de " + DIA_TXT[hoje.dia] + ".");
}

void tampaAbriu(uint8_t i) {
  if (antes(reabastecerAte)) return;
  if (!relogioOk()) { evento("abertura", i, "sem hora"); return; }
  struct tm t;
  horaLocal(t);
  int minuto = t.tm_hour * 60 + t.tm_min;
  if (i == hoje.dia) {
    if (hoje.st == ALARME || hoje.st == ATRASADA) { marcaTomada(""); return; }
    if (hoje.st == AGUARDANDO && (int)cfg.dias[i].minuto - minuto <= cfg.antecipa) { marcaTomada("antecipada"); return; }
    evento("fora_horario", i);
    return;
  }
  if (hoje.st == ALARME || hoje.st == ATRASADA) {
    evento("errada", i, String("certo: ") + DIA_TXT[hoje.dia]);
    erradoAte = millis() + 5000;
    bip({120, 120, 120, 120, 120});
  } else {
    evento("abertura", i);
  }
}

void logica() {
  if (!relogioOk()) return;
  struct tm t;
  horaLocal(t);
  uint32_t ymd = (t.tm_year + 1900) * 10000UL + (t.tm_mon + 1) * 100UL + t.tm_mday;
  int minuto = t.tm_hour * 60 + t.tm_min;

  if (ymd != hoje.ymd) {                                             // virou o dia
    if (hoje.ymd != 0 && (hoje.st == ALARME || hoje.st == ATRASADA)) {
      evento("perdida", hoje.dia);
      avisa("❌ " + quem() + " NÃO tomou o remédio de " + DIA_TXT[hoje.dia] + ".");
    }
    hoje.ymd = ymd;
    hoje.dia = t.tm_wday;
    hoje.st = cfg.dias[hoje.dia].ativo ? AGUARDANDO : SEM_DOSE;
    hoje.tomadaEm = 0;
    salvaHoje();
  }

  int alvo = cfg.dias[hoje.dia].minuto;
  if (hoje.st == AGUARDANDO && minuto >= alvo) {
    entraAlarme();
    salvaHoje();
    evento("alarme", hoje.dia);
  }
  if (hoje.st == ALARME && minuto >= alvo + cfg.tol) {
    hoje.st = ATRASADA;
    salvaHoje();
    evento("atrasada", hoje.dia);
    avisa("⚠️ " + quem() + " ainda não tomou o remédio de " + DIA_TXT[hoje.dia] + " (" + horaTxt(alvo) +
          "). Já passaram " + String(cfg.tol) + " minutos.");
  }
}

// Agenda mudou: reavalia o dia de hoje (sem desfazer uma dose ja tomada).
void reavaliaHoje() {
  if (hoje.ymd == 0 || hoje.st == TOMADA) return;
  hoje.st = cfg.dias[hoje.dia].ativo ? AGUARDANDO : SEM_DOSE;
  salvaHoje();
}

// ---------------------------------------------------------------- entradas
void tampasInicio() {
  for (uint8_t i = 0; i < N_DIAS; i++) {
    entradaComPullup(REED_PINS[i]);
    tampaAberta[i] = tampaBruta[i] = digitalRead(REED_PINS[i]) == HIGH;
    tampaMudou[i] = millis();
  }
}

void tampasTick() {
  uint32_t m = millis();
  for (uint8_t i = 0; i < N_DIAS; i++) {
    bool r = digitalRead(REED_PINS[i]) == HIGH;
    if (r != tampaBruta[i]) { tampaBruta[i] = r; tampaMudou[i] = m; }
    if (r != tampaAberta[i] && m - tampaMudou[i] >= 80) {             // debounce de 80 ms
      tampaAberta[i] = r;
      if (r) tampaAbriu(i);
    }
  }
}

// Toca o que estiver na fila do buzzer e reinicia.
void reiniciaDepoisDoBip() {
  for (int i = 0; i < 120; i++) { buzzerTick(); delay(10); }
  digitalWrite(PIN_BUZZER, LOW);
  ESP.restart();
}

void apagaWifi() {
  prefs.remove("wssid");
  prefs.remove("wsenha");
  WiFi.disconnect(true, true);                                       // apaga tambem o que o ESP32 guardou
  evento("wifi_apagado", hoje.dia);
}

void apagaTudo() {
  apagaWifi();
  prefs.clear();                                                     // pareamento, agenda, estado do dia
  LittleFS.remove(ARQ_EV);
  LittleFS.remove(ARQ_EV_OLD);
  LittleFS.remove(ARQ_CFG);
}

void botaoTick() {
  static bool apertado = false, fez3 = false, fez10 = false, fez20 = false;
  static uint32_t desde = 0;
  bool b = digitalRead(PIN_BOTAO) == LOW;
  uint32_t m = millis();
  if (b && !apertado) { apertado = true; desde = m; fez3 = fez10 = fez20 = false; }
  if (b && apertado) {
    if (!fez3 && m - desde >= 3000) {                                // 3 s: parear o app
      fez3 = true;
      pareandoAte = m + 120000;
      bip({80, 80, 80});
    }
    if (!fez10 && m - desde >= 10000) { fez10 = true; bip({600}); }              // soltar agora: apaga o Wi-Fi
    if (!fez20 && m - desde >= 20000) { fez20 = true; bip({600, 200, 600}); }    // soltar agora: apaga tudo
  }
  if (!b && apertado) {
    apertado = false;
    if (fez20) { apagaTudo(); bip({100, 100, 100, 100, 600}); reiniciaDepoisDoBip(); }
    if (fez10) { pareandoAte = 0; apagaWifi(); bip({600}); reiniciaDepoisDoBip(); }
    if (m - desde >= 40 && m - desde < 1500) {                       // toque curto: silenciar
      if (alarmeTocando()) silenciado = true;
      else bip({40});
    }
  }
}

// ---------------------------------------------------------------- API
void mandaJson(JsonDocument& d, int code = 200) {
  String s;
  serializeJson(d, s);
  server.send(code, "application/json", s);
}
void mandaErro(int code, const char* msg) {
  JsonDocument d;
  d["erro"] = msg;
  mandaJson(d, code);
}
void mandaOk() { server.send(200, "application/json", "{\"ok\":true}"); }

bool autorizado() {
  if (token.length() && server.header("X-Token") == token) return true;
  mandaErro(401, "token invalido");
  return false;
}

void apiInfo() {
  JsonDocument d;
  d["caixa_remedios"] = true;
  d["nome"] = cfg.nome;
  d["id"] = chipId;
  d["fw"] = FW_VERSION;
  d["pareada"] = token.length() > 0;
  d["pareando"] = antes(pareandoAte);
  d["modo"] = (modoConfig && wSsid.isEmpty()) ? "config" : "normal";  // "config" = esperando o Wi-Fi da casa
  d["wifi_ssid"] = wSsid;
  mandaJson(d);
}

void apiParear() {
  // Sem Wi-Fi configurado (rede da caixa, com senha) o app pode parear direto.
  bool livre = token.isEmpty() || antes(pareandoAte) || (modoConfig && wSsid.isEmpty());
  if (!livre) { mandaErro(403, "segure o botao da caixa por 3 segundos e tente de novo"); return; }
  if (token.isEmpty()) {
    char b[33];
    snprintf(b, sizeof b, "%08x%08x%08x%08x", esp_random(), esp_random(), esp_random(), esp_random());
    token = b;
    prefs.putString("token", token);
  }
  pareandoAte = 0;
  bip({90, 60, 250});
  JsonDocument d;
  d["token"] = token;
  mandaJson(d);
}

void apiEstado() {
  if (!autorizado()) return;
  JsonDocument d;
  d["agora"] = agoraUtc();
  d["relogio_ok"] = relogioOk();
  d["rtc"] = rtcPresente;
  d["dia"] = hoje.dia;
  d["status"] = STATUS_TXT[hoje.st];
  d["hora"] = horaTxt(cfg.dias[hoje.dia].minuto);
  d["tomada_em"] = hoje.tomadaEm;
  d["tocando"] = alarmeTocando();
  d["reabastecendo"] = antes(reabastecerAte);
  JsonArray a = d["tampas"].to<JsonArray>();
  for (uint8_t i = 0; i < N_DIAS; i++) a.add(tampaAberta[i] ? 1 : 0);
  d["wifi"] = WiFi.RSSI();
  d["ip"] = WiFi.localIP().toString();
  d["fw"] = FW_VERSION;
  d["telegram_fila"] = (int)filaTelegram.size();
  mandaJson(d);
}

void apiCfgLe() {
  if (!autorizado()) return;
  server.send(200, "application/json", leCfgBruta());
}

void apiCfgGrava() {
  if (!autorizado()) return;
  String corpo = server.arg("plain");
  JsonDocument d;
  if (deserializeJson(d, corpo) || !d["dias"].is<JsonArray>() || d["dias"].size() != N_DIAS) {
    mandaErro(400, "configuracao invalida");
    return;
  }
  String s;
  serializeJson(d, s);
  if (s.length() > CFG_MAX) { mandaErro(413, "agenda grande demais: use nomes de remedio mais curtos"); return; }
  if (prefs.putString("cfg", s) != s.length()) { mandaErro(500, "nao consegui gravar"); return; }
  aplicaCfg(d);
  reavaliaHoje();
  mandaOk();
}

void apiEventos() {
  if (!autorizado()) return;
  size_t lim = server.hasArg("limite") ? constrain(server.arg("limite").toInt(), 1, 300) : 120;
  std::vector<String> v;
  auto le = [&](const char* p) {
    File f = LittleFS.open(p, "r");
    if (!f) return;
    while (f.available()) {
      String l = f.readStringUntil('\n');
      l.trim();
      if (l.length() > 2) {
        v.push_back(l);
        if (v.size() > lim) v.erase(v.begin());
      }
    }
    f.close();
  };
  le(ARQ_EV_OLD);
  le(ARQ_EV);
  String out = "[";
  for (int i = (int)v.size() - 1; i >= 0; i--) { out += v[i]; if (i) out += ','; }
  out += "]";
  server.send(200, "application/json", out);
}

void apiSilenciar() {
  if (!autorizado()) return;
  silenciado = true;
  mandaOk();
}

void apiTomei() {
  if (!autorizado()) return;
  if (hoje.st == AGUARDANDO || hoje.st == ALARME || hoje.st == ATRASADA) { marcaTomada("manual"); mandaOk(); }
  else mandaErro(409, "nao ha dose pendente hoje");
}

void apiReabastecer() {
  if (!autorizado()) return;
  JsonDocument d;
  deserializeJson(d, server.arg("plain"));
  int min = constrain((int)(d["min"] | 10), 0, 60);
  reabastecerAte = min ? millis() + (uint32_t)min * 60000UL : 0;
  if (min) evento("reabastecer", hoje.dia, String(min) + " min");
  mandaOk();
}

void apiTeste() {
  if (!autorizado()) return;
  mandaOk();
  for (uint8_t i = 0; i < N_DIAS; i++) { ledsEscreve(1 << i); delay(180); }
  ledsEscreve(0x7F);
  digitalWrite(PIN_BUZZER, HIGH); delay(250); digitalWrite(PIN_BUZZER, LOW);
  delay(300);
  ledsEscreve(0);
}

void apiHora() {
  if (!autorizado()) return;
  JsonDocument d;
  deserializeJson(d, server.arg("plain"));
  uint32_t e = d["epoch"] | 0;
  if (e < 1700000000) { mandaErro(400, "hora invalida"); return; }
  ajustaRelogio(e);
  mandaOk();
}

void apiTgTeste() {
  if (!autorizado()) return;
  JsonDocument d;
  deserializeJson(d, server.arg("plain"));
  String tk = d["token"] | cfg.tgToken.c_str();
  String chat = d["chat"] | cfg.tgChat.c_str();
  if (tk.isEmpty() || chat.isEmpty()) { mandaErro(400, "falta token ou conversa"); return; }
  if (telegramEnvia(tk, chat, "🔔 Teste da caixa de remédios: os avisos estão funcionando.")) mandaOk();
  else mandaErro(502, "o Telegram recusou: confira o token e a conversa");
}

// Descobre o chat: a pessoa manda qualquer mensagem para o bot e o app chama isto.
void apiTgChat() {
  if (!autorizado()) return;
  JsonDocument d;
  deserializeJson(d, server.arg("plain"));
  String tk = d["token"] | "";
  if (tk.isEmpty()) { mandaErro(400, "falta o token"); return; }
  WiFiClientSecure c;
  c.setInsecure();
  HTTPClient h;
  h.setTimeout(8000);
  h.begin(c, "https://api.telegram.org/bot" + tk + "/getUpdates?offset=-1&limit=1");
  int code = h.GET();
  String corpo = code == 200 ? h.getString() : String();
  h.end();
  if (code != 200) { mandaErro(502, "token recusado pelo Telegram"); return; }
  JsonDocument r;
  deserializeJson(r, corpo);
  JsonObject chat = r["result"][0]["message"]["chat"];
  if (chat.isNull()) { mandaErro(404, "nenhuma mensagem: mande um oi para o bot e tente de novo"); return; }
  JsonDocument o;
  o["chat"] = String((long long)(chat["id"] | 0LL));
  const char* nm = chat["first_name"] | "";
  if (!*nm) nm = chat["title"] | "";
  o["nome"] = nm;
  mandaJson(o);
}

// ---------------------------------------------------------------- API do Wi-Fi (configuracao pelo app)
// Redes que a caixa enxerga (o celular nao precisa de permissao de localizacao).
void apiWifiRedes() {
  if (!autorizado()) return;
  int n = WiFi.scanNetworks(false, false);
  JsonDocument d;
  JsonArray a = d.to<JsonArray>();
  for (int i = 0; i < n; i++) {
    String s = WiFi.SSID(i);
    if (s.isEmpty()) continue;
    bool repetida = false;                    // a mesma rede em varios roteadores: fica a mais forte
    for (JsonObject o : a) if (s == (const char*)o["ssid"]) {
      if (WiFi.RSSI(i) > (int)o["rssi"]) o["rssi"] = WiFi.RSSI(i);
      repetida = true;
    }
    if (repetida) continue;
    JsonObject o = a.add<JsonObject>();
    o["ssid"] = s;
    o["rssi"] = WiFi.RSSI(i);
    o["senha"] = WiFi.encryptionType(i) != WIFI_AUTH_OPEN;
  }
  WiFi.scanDelete();
  mandaJson(d);
}

// Recebe o Wi-Fi da casa e tenta conectar. So salva se conectar.
void apiWifiGrava() {
  if (!autorizado()) return;
  if (!(modoConfig && wSsid.isEmpty())) {
    mandaErro(409, "a caixa ja tem Wi-Fi: segure o botao por 10 segundos para trocar");
    return;
  }
  JsonDocument d;
  if (deserializeJson(d, server.arg("plain"))) { mandaErro(400, "json invalido"); return; }
  String ssid = d["ssid"] | "";
  String senha = d["senha"] | "";
  if (ssid.isEmpty() || ssid.length() > 32 || senha.length() > 63) { mandaErro(400, "nome ou senha invalidos"); return; }
  tentSsid = ssid;
  tentSenha = senha;
  tentErro = "";
  tent = T_CONECTANDO;
  tentIniciou = false;                        // o wifiTick comeca daqui a 300 ms: a resposta sai antes
  tentDesde = millis();
  mandaOk();
}

void apiWifiEstado() {
  if (!autorizado()) return;
  JsonDocument d;
  d["estado"] = TENT_TXT[tent];
  d["ssid"] = tent == T_NADA ? wSsid : tentSsid;
  if (tent == T_FALHOU) d["erro"] = tentErro;
  if (WiFi.status() == WL_CONNECTED) d["ip"] = WiFi.localIP().toString();
  mandaJson(d);
}

void apiInicio() {
  static const char* cab[] = {"X-Token"};
  server.collectHeaders(cab, 1);
  server.on("/api/info", HTTP_GET, apiInfo);
  server.on("/api/parear", HTTP_POST, apiParear);
  server.on("/api/estado", HTTP_GET, apiEstado);
  server.on("/api/config", HTTP_GET, apiCfgLe);
  server.on("/api/config", HTTP_PUT, apiCfgGrava);
  server.on("/api/eventos", HTTP_GET, apiEventos);
  server.on("/api/silenciar", HTTP_POST, apiSilenciar);
  server.on("/api/tomei", HTTP_POST, apiTomei);
  server.on("/api/reabastecer", HTTP_POST, apiReabastecer);
  server.on("/api/teste", HTTP_POST, apiTeste);
  server.on("/api/hora", HTTP_POST, apiHora);
  server.on("/api/telegram/teste", HTTP_POST, apiTgTeste);
  server.on("/api/telegram/chat", HTTP_POST, apiTgChat);
  server.on("/api/wifi/redes", HTTP_GET, apiWifiRedes);
  server.on("/api/wifi", HTTP_POST, apiWifiGrava);
  server.on("/api/wifi", HTTP_GET, apiWifiEstado);
  server.onNotFound([]() { mandaErro(404, "nao existe"); });
  server.begin();
  serverOn = true;
}

// ---------------------------------------------------------------- Wi-Fi
void wifiSubiu() {
  Serial.printf("Wi-Fi ok: %s\n", WiFi.localIP().toString().c_str());
  if (!serverOn) apiInicio();
  MDNS.end();
  if (MDNS.begin("caixa-remedios")) MDNS.addService("caixaremedios", "tcp", PORTA_API);
  configTime(0, 0, "pool.ntp.org", "time.google.com");
}

// Rede da propria caixa, para o app configurar o Wi-Fi. AP+STA: assim ela consegue
// procurar redes e testar a senha sem derrubar o celular.
void apLiga() {
  WiFi.mode(WIFI_AP_STA);
  WiFi.softAP(apNome.c_str(), AP_SENHA);
  modoConfig = true;
  Serial.printf("Modo configuracao: rede '%s' (senha %s), app em %s:%u\n", apNome.c_str(), AP_SENHA,
                WiFi.softAPIP().toString().c_str(), PORTA_API);
}

void apDesliga() {
  WiFi.softAPdisconnect(true);
  WiFi.mode(WIFI_STA);
  modoConfig = false;
  apDesligarEm = 0;
  Serial.println("Rede de configuracao desligada");
}

void wifiInicio() {
  WiFi.persistent(false);                     // quem guarda as credenciais e a NVS "caixa"
  WiFi.setAutoReconnect(true);
  wSsid = prefs.getString("wssid", "");
  wSenha = prefs.getString("wsenha", "");
  if (wSsid.length()) {
    WiFi.mode(WIFI_STA);
    WiFi.begin(wSsid.c_str(), wSenha.c_str());
    Serial.printf("Wi-Fi: conectando em '%s'\n", wSsid.c_str());
  } else {
    apLiga();
  }
  if (!serverOn) apiInicio();                 // a API responde tambem na rede da caixa (192.168.4.1)
}

void wifiTick() {
  static bool estava = false;
  static uint32_t t = 0;
  uint32_t m = millis();
  bool on = WiFi.status() == WL_CONNECTED;

  if (tent == T_CONECTANDO && !tentIniciou && m - tentDesde >= 300) {
    tentIniciou = true;
    tentDesde = m;
    WiFi.disconnect(false);
    WiFi.begin(tentSsid.c_str(), tentSenha.c_str());
    Serial.printf("Wi-Fi: tentando '%s'\n", tentSsid.c_str());
  }
  if (tent == T_CONECTANDO && tentIniciou) {
    if (on) {                                 // senha certa: agora sim salva
      tent = T_OK;
      wSsid = tentSsid;
      wSenha = tentSenha;
      prefs.putString("wssid", wSsid);
      prefs.putString("wsenha", wSenha);
      apDesligarEm = m + 90000;               // da tempo do app ler o IP novo
      evento("wifi_ok", hoje.dia, wSsid);
      bip({90, 60, 250});
    } else if (m - tentDesde > 20000) {
      wl_status_t s = WiFi.status();
      tent = T_FALHOU;
      tentErro = s == WL_NO_SSID_AVAIL ? "a caixa nao encontrou essa rede" : "nao conectou: confira a senha";
      WiFi.disconnect(false);                 // para de tentar (a rede da caixa continua no ar)
      Serial.printf("Wi-Fi: falhou (%d)\n", (int)s);
    }
  }

  if (on && !estava) wifiSubiu();
  estava = on;

  if (modoConfig && apDesligarEm && (int32_t)(m - apDesligarEm) >= 0) apDesliga();

  if (!on && !modoConfig && wSsid.length() && m - t > 30000) {      // caiu: tenta de novo
    t = m;
    WiFi.begin(wSsid.c_str(), wSenha.c_str());
  }
}

// ---------------------------------------------------------------- setup / loop
void setup() {
  // Apaga os LEDs logo de cara (o GPIO 14 pulsa no boot e pode piscar o LED de segunda).
  for (uint8_t i = 0; i < N_DIAS; i++) pinMode(LED_PINS[i], OUTPUT);
  ledsEscreve(0);
  pinMode(PIN_BUZZER, OUTPUT);
  digitalWrite(PIN_BUZZER, LOW);
  entradaComPullup(PIN_BOTAO);

  Serial.begin(115200);
  Serial.printf("\nCaixa de remedios - firmware %s\n", FW_VERSION);

  char id[7];
  snprintf(id, sizeof id, "%06X", (uint32_t)(ESP.getEfuseMac() >> 24) & 0xFFFFFF);
  chipId = id;
  apNome = "CaixaRemedios-" + chipId.substring(2);

  if (!LittleFS.begin(true)) Serial.println("LittleFS falhou");
  prefs.begin("caixa", false);
  token = prefs.getString("token", "");

  carregaCfg();
  relogioInicio();
  carregaHoje();
  tampasInicio();
  evento("ligou", hoje.dia, FW_VERSION);
  bip({60});
  wifiInicio();
}

void loop() {
  wifiTick();
  if (serverOn) server.handleClient();
  botaoTick();
  tampasTick();
  static uint32_t tl = 0;
  if (millis() - tl >= 250) { tl = millis(); logica(); }
  buzzerTick();
  ledsTick();
  telegramTick();
  relogioTick();
  delay(4);
}
