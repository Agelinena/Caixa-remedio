// Pinagem: copia da secao 5 de docs/DOCUMENTACAO.md (fonte da verdade).
// Nao mude aqui sem atualizar o documento.
#pragma once
#include <Arduino.h>

static const uint8_t N_DIAS = 7;                       // 0 = Domingo ... 6 = Sabado

// LEDs direto no ESP32: GPIO -> resistor 330 ohm -> LED (perna longa) -> GND. Nivel alto = aceso.
static const uint8_t LED_PINS[N_DIAS]  = {13, 14, 27, 16, 15, 18, 19};  // a placa do usuario nao tem o 17
// 15 e pino de boot: com o LED para o GND ele fica em LOW no boot, o que so desliga o log da ROM. Boot normal.

// Reeds: reed entre o GPIO e o GND. Tampa fechada (ima perto) = LOW. Tampa aberta = HIGH.
// 34 e 35 sao so entrada e NAO tem pull-up interno: resistor de 10k do pino para o 3V3.
static const uint8_t REED_PINS[N_DIAS] = {23, 25, 26, 32, 33, 34, 35};

static const uint8_t PIN_BUZZER = 4;                   // via transistor NPN, nivel alto = toca
static const uint8_t PIN_BOTAO  = 36;                  // VP; botao entre o GPIO e o GND + 10k do pino para o 3V3

// Pinos 34..39 nao tem pull-up interno (o resistor e externo).
inline void entradaComPullup(uint8_t pin) { pinMode(pin, pin >= 34 ? INPUT : INPUT_PULLUP); }

// RTC DS3231: I2C padrao do ESP32
static const uint8_t PIN_SDA = 21;
static const uint8_t PIN_SCL = 22;
