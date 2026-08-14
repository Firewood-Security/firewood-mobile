plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.firewood"
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
        applicationId = "com.example.firewood"
        // AndroidX Security Crypto requires API 23+ for EncryptedSharedPreferences
        minSdk = maxOf(flutter.minSdkVersion.toInt(), 23)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Sign with debug keys for now; replace with production keystore
            signingConfig = signingConfigs.getByName("debug")
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

    // Play Core – required by Flutter embedding for deferred component support
    implementation("com.google.android.play:core:1.10.3")
}

flutter {
    source = "../.."
}
