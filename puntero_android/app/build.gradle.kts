plugins {
    id("com.android.application")
}

android {
    namespace = "com.royleguiza.voicebubble.puntero"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.royleguiza.voicebubble.puntero"
        minSdk = 28
        targetSdk = 36
        // CI pasa -PbuildNumber=<run_number>: cada APK es una ACTUALIZACIÓN.
        versionCode = (project.findProperty("buildNumber") as String?)?.toIntOrNull() ?: 1
        versionName = "1.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        // Misma debug.keystore versionada que VoiceBubble: el permiso de firma
        // com.royleguiza.voicebubble.puntero.permission.POINTER exige que las
        // dos apps estén firmadas igual. Jamás para publicar en Play.
        getByName("debug") {
            val shared = file("../../voice_bubble_stt/android/app/debug.keystore")
            if (shared.exists()) {
                storeFile = shared
                storePassword = "android"
                keyAlias = "androiddebugkey"
                keyPassword = "android"
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    testImplementation("junit:junit:4.13.2")
}
