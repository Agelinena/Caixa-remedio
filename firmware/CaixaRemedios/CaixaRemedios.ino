// Caixa de remedios inteligente - firmware do ESP32
//
// O codigo fica em main.cpp (aba ao lado) e a pinagem em pins.h.
// Este arquivo existe so para o Arduino IDE reconhecer a pasta como sketch;
// o PlatformIO (GitHub Actions) compila a mesma pasta.
//
// Arduino IDE (ver docs/DOCUMENTACAO.md, secao 6.6):
//   Placa: "ESP32 Dev Module"
//   Partition Scheme: "Minimal SPIFFS (1.9MB APP with OTA/190KB SPIFFS)"
//   Bibliotecas: RTClib (Adafruit), ArduinoJson (Benoit Blanchon, v7)
//   Ferramentas > "Erase All Flash Before Sketch Upload": Disabled (senao apaga Wi-Fi e agenda)
