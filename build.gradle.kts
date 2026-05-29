plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.appaudio_nueva"
    
    // CORRECCIÓN: Forzamos el SDK de compilación a la versión 36 que te exige la librería
    compileSdk = 36 
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.example.appaudio_nueva"
        minSdk = flutter.minSdkVersion 
        targetSdk = 35 
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // ESTA ES LA CORRECCIÓN CLAVE:
        // Fuerza al empaquetador de Gradle a registrar el permiso multimedia ante el plugin
        manifestPlaceholders["requestLegacyExternalStorage"] = "true"
        manifestPlaceholders["readMediaAudio"] = "true"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
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

// Bloque de compatibilidad para evitar el choque de versiones en librerías de ciclo de vida
configurations.all {
    resolutionStrategy {
        force("androidx.lifecycle:lifecycle-runtime-ktx:2.8.0")
        force("androidx.lifecycle:lifecycle-common:2.8.0")
    }
}
