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

# Keep Sentry
-keep class io.sentry.** { *; }
-dontwarn io.sentry.**

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

# MediaPipe LLM Inference (flutter_gemma)
-keep class com.google.mediapipe.** { *; }
-dontwarn com.google.mediapipe.**
-keep class com.google.protobuf.** { *; }
-dontwarn com.google.protobuf.**

# TensorFlow Lite / LiteRT (used by MediaPipe GenAI runtime)
-keep class org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.lite.**

# Cronet HTTP (native networking)
-keep class org.chromium.** { *; }
-dontwarn org.chromium.**

# Mobile Scanner (native camera/ML)
-keep class mobile.scanner.** { *; }

# Socket.IO and WebSocket dependencies
-keep class okhttp3.** { *; }
-keep class okio.** { *; }

# Native libraries — keep symbol exports intact even with minification
-keepnames class **

# Preserve method signatures for reflection-based code
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep annotation retention for reflection
-keepattributes *Annotation*,InnerClasses
