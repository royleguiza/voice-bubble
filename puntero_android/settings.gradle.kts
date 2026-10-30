// Complemento VoiceBubble Puntero: app Android mínima (sin Flutter) que hace
// los clics del trackpad de VoiceBubble en otras apps vía Accesibilidad.
// Vive aparte para que VoiceBubble siga sin declarar Accesibilidad
// (perfil anti-Play-Protect). Ver docs/contrato-trackpad.md.
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.application") version "9.1.0" apply false
}

rootProject.name = "voicebubble-puntero"
include(":app")
