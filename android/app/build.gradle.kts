import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val googleServicesFile = file("google-services.json")
if (googleServicesFile.exists()) {
    apply(plugin = "com.google.gms.google-services")
}

android {
    namespace = "com.example.happy_flutter"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    buildFeatures {
        buildConfig = true
    }

    defaultConfig {
        applicationId = "com.example.happy_flutter"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "environment"

    productFlavors {
        create("development") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            buildConfigField("String", "APP_ENV", "\"development\"")
        }
        create("preview") {
            dimension = "environment"
            applicationIdSuffix = ".preview"
            versionNameSuffix = "-preview"
            buildConfigField("String", "APP_ENV", "\"preview\"")
        }
        create("production") {
            dimension = "environment"
            buildConfigField("String", "APP_ENV", "\"production\"")
        }
    }

    val keystorePath = System.getenv("KEYSTORE_PATH")
    signingConfigs {
        create("release") {
            if (!keystorePath.isNullOrBlank()) {
                storeFile = file(keystorePath)
                storePassword = System.getenv("KEYSTORE_STORE_PASSWORD")
                keyPassword = System.getenv("KEYSTORE_KEY_PASSWORD")
                keyAlias = System.getenv("KEYSTORE_KEY_ALIAS")
            }
        }
    }

    buildTypes {
        getByName("debug") {
            isMinifyEnabled = false
            // Allow CI debug artifacts to be signed with the same keystore
            // as release builds (when KEYSTORE_PATH is provided), so they
            // can be installed as upgrades on Android devices.
            if (!keystorePath.isNullOrBlank()) {
                signingConfig = signingConfigs.findByName("release")
            }
        }
        getByName("release") {
            // R8 + resource shrink on. The previous ANR/bloat root cause was
            // flutter_gemma pulling in MediaPipe + Qdrant vector DB (250MB of
            // native libs loaded at boot via GeneratedPluginRegistrant). With
            // flutter_gemma fully removed, minification is safe. ProGuard rules
            // protect reflection/JNI native deps (Cronet, OkHttp, MMKV,
            // Firebase, libsodium). Stack traces stay readable via Sentry's
            // ProGuard mapping upload.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            if (!keystorePath.isNullOrBlank()) {
                signingConfig = signingConfigs.findByName("release")
            }
        }
    }

    // ABI selection is driven by Flutter's `--target-platform` flag —
    // CI passes `android-arm64`, producing a single arm64-v8a APK.
    //
    // We intentionally do NOT use `splits { abi { isUniversalApk = true } }`
    // here. That emitted a *universal* fat APK bundling arm64-v8a +
    // armeabi-v7a + x86_64 (~124MB of .so), which is what blew the release
    // APK past 130MB and ignored `--target-platform`. arm64-v8a covers
    // every modern phone; 32-bit ARM / x86 emulators can `flutter run`.
    //
    // Native libs are stored *compressed* in the APK via
    // `android:extractNativeLibs="true"` (AndroidManifest.xml). For a
    // sideloaded .apk that roughly halves the on-disk size again.
}

kotlin {
    jvmToolchain(17)
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
