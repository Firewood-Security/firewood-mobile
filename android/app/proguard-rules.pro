# ProGuard Rules for Firewood Release Build

# Flutter Engine & Plugins
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.provider.** { *; }
-keep class io.flutter.plugins.** { *; }

# Isar Database (Critical for Release APK)
-keep class com.isar.** { *; }
-keep class dev.isar.** { *; }
-keepclassmembers class * {
    @com.isar.annotation.* <fields>;
    @com.isar.annotation.* <methods>;
}
-keep @com.isar.annotation.Collection class * { *; }
-keep @com.isar.annotation.Embedded class * { *; }
-dontwarn dev.isar.**
-dontwarn com.isar.**

# AndroidX Security Crypto & MasterKey
-keep class androidx.security.crypto.** { *; }
-dontwarn androidx.security.crypto.**

# Application classes & native security channels
-keep class com.example.firewood.** { *; }
