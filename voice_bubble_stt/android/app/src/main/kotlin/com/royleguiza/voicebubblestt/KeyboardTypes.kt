package com.royleguiza.voicebubblestt

/**
 * Tipos del teclado (SPK-05, módulo 2 de N): enums extraídos de
 * VoiceKeyboardService sin cambiar conducta. Mismo paquete y mismos
 * nombres: ningún call site se tocó. Los próximos módulos (dictado,
 * snippets, credenciales) los usan sin pasar por VKS.
 */

enum class Layer { LETTERS, SYMBOLS, CODE, SNIPPETS, TRACKPAD, CREDENTIALS }

internal enum class MicState { IDLE, RECORDING, PROCESSING, BUSY }

/** Shift en tres estados: momentaneo tras un tap, persistente tras doble pulso. */
internal enum class ShiftState { OFF, MOMENTARY, CAPS_LOCK }

internal enum class SnippetMode { NORMAL, EDIT, DELETE }
