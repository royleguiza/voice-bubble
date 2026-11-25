plugins {
    id("com.android.application")
}

android {
    namespace = "com.royleguiza.voicebubble.puntero"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.royleguiza.orison.puntero"
        minSdk = 28
        targetSdk = 36
        // CI pasa -PbuildNumber=<run_number>: cada APK es una ACTUALIZACIÓN.
        versionCode = (project.findProperty("buildNumber") as String?)?.toIntOrNull() ?: 1
        versionName = "1.0.0"
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
        // T3: publicación con la MISMA clave de subida que Orison (Play exige
        // que el permiso de firma lo compartan las dos apps). Mismas variables
        // que la app: KEYSTORE_FILE, KEYSTORE_PASSWORD, KEY_ALIAS, KEY_PASSWORD.
        // Sin KEYSTORE_FILE válido queda sin storeFile y el release falla
        // tarde, jamás firma con la debug.keystore.
        create("release") {
            val envStoreFile = System.getenv("KEYSTORE_FILE")?.takeIf { it.isNotBlank() }?.let { file(it) }
            if (envStoreFile != null && envStoreFile.exists()) {
                storeFile = envStoreFile
                storePassword = System.getenv("KEYSTORE_PASSWORD")
                keyAlias = System.getenv("KEY_ALIAS")
                keyPassword = System.getenv("KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
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
