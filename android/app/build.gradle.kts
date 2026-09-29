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
    namespace = "net.firewood.app"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "net.firewood.app"
        minSdk = maxOf(flutter.minSdkVersion.toInt(), 24)
        targetSdk = flutter.targetSdkVersion
        // Straight from pubspec `version:` so the manifest, PackageInfo and
        // the in-app version text always agree. Bump pubspec to change these.
        versionCode = flutter.versionCode ?: 1
        versionName = flutter.versionName ?: "1.0.0"
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
            // V-030: fail closed BY DEFAULT. A release artifact must never
            // silently fall back to the debug keystore — anyone holding that
            // key can push same-signature "updates" to every install. The
            // requirement activates whenever a release build is actually
            // requested (or when -PrequireReleaseSigning=true is passed
            // explicitly); opting out requires the equally explicit
            // -PrequireReleaseSigning=false (env form for scripts:
            // ORG_GRADLE_PROJECT_requireReleaseSigning=false) — see ADR-002
            // for the QA-class debug-signing escape hatch.
            val explicit =
                (project.findProperty("requireReleaseSigning") as String?)?.toBoolean()
            val releaseRequested = gradle.startParameter.taskNames
                .any { it.contains("release", ignoreCase = true) }
            val requireReleaseSigning = explicit ?: releaseRequested
            if (requireReleaseSigning && signingProp("store_file") == null) {
                throw GradleException(
                    "FIREWOOD (V-030): release build requested but no release keystore is " +
                        "configured — failing closed. Create android/key.properties (see " +
                        "key.properties.template) or set FIREWOOD_STORE_FILE/FIREWOOD_STORE_PASSWORD/" +
                        "FIREWOOD_KEY_ALIAS/FIREWOOD_KEY_PASSWORD. For an intentionally " +
                        "debug-signed local QA artifact, opt out explicitly with " +
                        "-PrequireReleaseSigning=false (ADR-002)."
                )
            }
            signingConfig = if (signingProp("store_file") != null) {
                signingConfigs.getByName("release")
            } else {
                logger.warn(
                    "FIREWOOD: no release keystore — DEBUG-SIGNED QA artifact, explicitly " +
                        "opted out via -PrequireReleaseSigning=false (ADR-002 / V-030)."
                )
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

dependencies {
    // AndroidX Security Crypto – EncryptedSharedPreferences + MasterKey (Keystore-backed)
    implementation("androidx.security:security-crypto:1.1.0-alpha06")

    // Kotlin coroutines for async clipboard clear and auto-lock scheduling
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")

    // Secure autofill picker activity (FirewoodAutofillPickerActivity):
    // biometric gate + credential list. Explicit versions so the autofill
    // flow does not depend on transitive plugin classpaths.
    implementation("androidx.biometric:biometric:1.1.0")
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("androidx.recyclerview:recyclerview:1.3.2")
}

flutter {
    source = "../.."
}
