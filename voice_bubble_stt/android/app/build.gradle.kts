plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.royleguiza.voicebubblestt"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.royleguiza.voicebubblestt"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 28
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // `debug.keystore` VERSIONADO A PROPÓSITO (práctica estándar de
        // Android, no un descuido): la keystore de debug solo firma builds
        // de desarrollo/CI y su password ("android") es pública por diseño
        // del SDK. Versionarla da reproducibilidad: mismo fingerprint de
        // firma en cada run de CI y en cada clon, así el APK debug se puede
        // reinstalar sin desinstalar (misma firma) y no depende de la
        // keystore efímera que Gradle generaría por defecto en cada máquina.
        // JAMÁS usar para publicar en Play. Release real: exportar
        // KEYSTORE_FILE (ruta al upload keystore), KEYSTORE_PASSWORD,
        // KEY_ALIAS y KEY_PASSWORD (p. ej. desde secrets del CI) y compilar
        // con `flutter build apk/appbundle --release`; ver bloque "release".
        getByName("debug") {
            val persistentKeystore = file("debug.keystore")
            if (persistentKeystore.exists()) {
                storeFile = persistentKeystore
                storePassword = "android"
                keyAlias = "androiddebugkey"
                keyPassword = "android"
            }
        }
        // Release por variables de entorno (forma correcta sin romper CI: los
        // builds debug de CI no tocan esta config). Para firmar un release real,
        // exportar KEYSTORE_FILE (ruta al upload keystore), KEYSTORE_PASSWORD,
        // KEY_ALIAS y KEY_PASSWORD (p. ej. desde secrets del CI) y compilar
        // con `flutter build apk/appbundle --release`.
        // SPK-03: release SOLO con keystore real. Sin KEYSTORE_FILE válido
        // la config queda SIN storeFile y Gradle falla al ensamblar release
        // ("missing required property 'storeFile'"); jamás firma con el
        // debug.keystore versionado. OJO: un error() aquí rompería la fase
        // de configuración de TODOS los builds (este bloque se evalúa
        // siempre, incluidos los debug de CI): por eso se falla tarde.
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

flutter {
    source = "../.."
}

dependencies {
    // SPK-02: bóveda del IME (SecureStore.kt). Misma versión que trae
    // transitivamente flutter_secure_storage v9: sin cambio de conducta,
    // solo pin explícito para que el import compile aunque cambie el árbol.
    implementation("androidx.security:security-crypto:1.1.0-alpha06")
}
