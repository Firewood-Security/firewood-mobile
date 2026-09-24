plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties

// Release signing (ADR-002): credentials come from `android/key.properties`
// (git-ignored; see key.properties.template) or FIREWOOD_STORE_FILE /
// FIREWOOD_STORE_PASSWORD / FIREWOOD_KEY_ALIAS / FIREWOOD_KEY_PASSWORD env.
// No secrets are committed. Absence => explicit QA-class debug signing.
val keystoreProperties = Properties().apply {
    val keystoreFile = rootProject.file("key.properties")
    if (keystoreFile.exists()) keystoreFile.inputStream().use(::load)
}

fun signingProp(name: String): String? =
    System.getenv("FIREWOOD_${name.uppercase()}") ?: keystoreProperties.getProperty(name)

android {
    namespace = "com.example.firewood"
    compileSdk = 35
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.firewood"
        minSdk = maxOf(flutter.minSdkVersion.toInt(), 24)
        targetSdk = flutter.targetSdkVersion
        versionCode = (flutter.versionCode ?: 1) + 1
        versionName = flutter.versionName ?: "1.0.1"
    }

    signingConfigs {
        getByName("debug") {
            enableV1Signing = true
            enableV2Signing = true
            enableV3Signing = true
        }
        create("release") {
            val storePath = signingProp("store_file")
            if (storePath != null) {
                storeFile = file(storePath)
                storePassword = signingProp("store_password")
                keyAlias = signingProp("key_alias")
                keyPassword = signingProp("key_password")
                enableV1Signing = true
                enableV2Signing = true
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (signingProp("store_file") != null) {
                signingConfigs.getByName("release")
            } else {
                logger.warn("FIREWOOD: no release keystore configured — QA-class debug signing in effect (see ADR-002).")
                signingConfigs.getByName("debug")
            }
        }
    }
}

dependencies {
    // AndroidX Security Crypto – EncryptedSharedPreferences + MasterKey (Keystore-backed)
    implementation("androidx.security:security-crypto:1.1.0-alpha06")

    // Kotlin coroutines for async clipboard clear and auto-lock scheduling
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
}

flutter {
    source = "../.."
}
