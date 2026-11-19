// Pinagem: copia da secao 5 de docs/DOCUMENTACAO.md (fonte da verdade).
// Nao mude aqui sem atualizar o documento.
// Placa do usuario: ESP32 DevKit V1, 30 pinos, USB-C, CP2102. Na serigrafia o 16 e "RX2" e o 17 e "TX2".
// Nenhum resistor externo de pull-up: todos os pinos de entrada usam o pull-up interno.
#pragma once
#include <Arduino.h>

static const uint8_t N_DIAS = 7;                       // 0 = Domingo ... 6 = Sabado

// LEDs direto no ESP32: GPIO -> resistor 330 ohm -> LED (perna longa) -> GND. Nivel alto = aceso.
static const uint8_t LED_PINS[N_DIAS]  = {13, 14, 27, 16, 17, 18, 19};

// Reeds: reed entre o GPIO e o GND. Tampa fechada (ima perto) = LOW. Tampa aberta = HIGH.
// 5 e 15 sao pinos de boot, mas um reed para o GND so os puxa para LOW (boot normal; o 15 em LOW
// so esconde o log da ROM).
static const uint8_t REED_PINS[N_DIAS] = {23, 25, 26, 32, 33, 5, 15};

static const uint8_t PIN_BUZZER = 4;                   // nivel alto = toca (direto ou via transistor NPN)

// Botao entre o GPIO e o GND. O 12 precisa estar em LOW no boot: o botao so o leva ao GND,
// e o pull-up interno so e ligado pelo firmware depois do boot.
static const uint8_t PIN_BOTAO  = 12;

// Todas as entradas acima tem pull-up interno (34..39 nao tem; nao sao usados).
inline void entradaComPullup(uint8_t pin) { pinMode(pin, pin >= 34 ? INPUT : INPUT_PULLUP); }

// RTC DS3231: I2C padrao do ESP32
static const uint8_t PIN_SDA = 21;
static const uint8_t PIN_SCL = 22;
