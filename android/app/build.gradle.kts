plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

// Version et numéro de build viennent de app/Info.plist, transmis par scripts/build-apk.sh.
val appVersion = (project.findProperty("appVersion") as String?) ?: "0.0.0"
val appBuild = (project.findProperty("appBuild") as String?)?.toIntOrNull() ?: 1

// Clé de debug Android : suffisante hors Play Store, et stable tant que le même fichier sert
// (une mise à jour d'APK n'est acceptée par Android que si la signature est identique).
val signingStore = File(System.getenv("UF_KEYSTORE") ?: "${System.getProperty("user.home")}/.android/debug.keystore")

android {
    namespace = "com.alane.usageforecast"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.alane.usageforecast"
        minSdk = 26
        targetSdk = 35
        versionCode = appBuild
        versionName = appVersion
    }

    signingConfigs {
        create("debugKeystore") {
            storeFile = signingStore
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            signingConfig = signingConfigs.getByName("debugKeystore")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets["main"].java.srcDir("src/main/kotlin")
    sourceSets["test"].java.srcDir("src/test/kotlin")
}

dependencies {
    testImplementation("junit:junit:4.13.2")
    // org.json n'est qu'une coquille vide dans les tests unitaires de l'SDK : la vraie implémentation sert aux tests.
    testImplementation("org.json:json:20240303")
}
