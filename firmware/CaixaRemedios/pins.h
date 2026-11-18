// Pinagem: copia da secao 5 de docs/DOCUMENTACAO.md (fonte da verdade).
// Nao mude aqui sem atualizar o documento.
#pragma once
#include <Arduino.h>

static const uint8_t N_DIAS = 7;                       // 0 = Domingo ... 6 = Sabado

// Reeds: INPUT_PULLUP, reed entre o GPIO e o GND.
// Tampa fechada (ima perto) = LOW. Tampa aberta = HIGH.
static const uint8_t REED_PINS[N_DIAS] = {16, 17, 18, 19, 23, 25, 26};

// 74HC595 (LEDs): Q0..Q6 = dias 0..6
static const uint8_t PIN_595_SER   = 13;
static const uint8_t PIN_595_SRCLK = 14;
static const uint8_t PIN_595_RCLK  = 27;

static const uint8_t PIN_BUZZER = 4;                   // via transistor NPN, nivel alto = toca
static const uint8_t PIN_BOTAO  = 32;                  // INPUT_PULLUP, botao entre o GPIO e o GND

// RTC DS3231: I2C padrao do ESP32
static const uint8_t PIN_SDA = 21;
static const uint8_t PIN_SCL = 22;
