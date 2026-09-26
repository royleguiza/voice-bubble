package com.royleguiza.voicebubblestt

/**
 * FlutterPrefs - Helper canónico para SharedPreferences gestionadas por Flutter.
 * Centraliza el nombre del archivo de preferencias y el prefijo de claves para el puente
 * entre el runtime de Flutter y los servicios nativos de Android.
 */
object FlutterPrefs {
    const val PREFS_NAME = "FlutterSharedPreferences"
    const val PREFIX = "flutter."

    fun key(name: String): String = "$PREFIX$name"
}
