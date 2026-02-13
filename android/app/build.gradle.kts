plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.monitor_destilacion"

    // --- CAMBIO OBLIGATORIO: Versión 36 ---
    compileSdk = 36
    // --------------------------------------

    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.monitor_destilacion"

        minSdk = flutter.minSdkVersion

        // El targetSdk puede quedarse en 34 o 35, pero si te da guerra, súbelo a 36 también.
        // Por ahora déjalo en 34 para mantener compatibilidad, el error solo pedía compileSdk.
        targetSdk = 34

        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}