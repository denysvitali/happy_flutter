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
            // R8 + resource shrink on. The previous `false`/`false`
            // config was producing a ~250 MB universal APK; the bulk
            // of that was the same set of native libs duplicated
            // across 4 ABIs plus every Java/Kotlin class reachable
            // from a manifest entry. R8 strips the dead ones and
            // resource shrink drops unreferenced assets. Stack
            // traces in GlitchTip stay readable because the
            // Sentry dart plugin already uploads ProGuard mapping
            // files automatically.
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

    // Per-ABI APK splits. Without this, every native library is
    // bundled four times (arm64-v8a, armeabi-v7a, x86, x86_64) and
    // the universal APK is ~4x larger than the per-ABI one. Modern
    // devices are arm64-v8a; older 32-bit devices are armeabi-v7a.
    // x86/x86_64 are kept off — emulators can use the universal APK
    // or be installed via `flutter run`. `isUniversalApk = true`
    // keeps a single fat APK in the build output for sideloading
    // on devices with unknown ABIs.
    splits {
        abi {
            isEnable = true
            reset()
            include("arm64-v8a", "armeabi-v7a")
            isUniversalApk = true
        }
    }
}

kotlin {
    jvmToolchain(17)
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // TFLite GPU delegate (required by tflite_flutter plugin for R8 resolution)
    implementation("org.tensorflow:tensorflow-lite-gpu:2.17.0")
}
