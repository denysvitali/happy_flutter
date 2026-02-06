# Add project specific ProGuard rules here.
# By default, the flags in this file are appended to flags specified
# in /sdk/tools/proguard/proguard-android.txt

# Keep Flutter classes
-keep class io.flutter.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }

# Keep plugin classes
-keep class com.example.happy_flutter.** { *; }

# Keep NaCl/libsodium
-keep class org.libsodium.** { *; }

# Keep Riverpod
-keep class riverpod.** { *; }
-keep class flutter_riverpod.** { *; }

# Keep Dio
-keep class dio.** { *; }

# Preserve generic signatures (for Retrofit)
-keepattributes Signature

# Keep enum classes
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Don't warn about missing Play Core split install classes (not used in this app)
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
