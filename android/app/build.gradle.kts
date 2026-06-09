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

        // Force arm64-v8a only. `flutter build apk --target-platform
        // android-arm64` filters the Flutter ENGINE libs but NOT the plugin
        // AAR native libs (libonnxruntime/sherpa/barhopper ship arm64 +
        // armeabi-v7a + x86_64), so the release APK still bundled three ABIs
        // (~124MB of .so). arm64-v8a covers every modern phone; 32-bit ARM /
        // x86 emulators can use a debug `flutter run`. Clear first so a
        // plugin-populated filter list can't re-add the other ABIs.
        ndk {
            abiFilters.clear()
            abiFilters.add("arm64-v8a")
        }
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

    // ABI is pinned to arm64-v8a via defaultConfig.ndk.abiFilters above.
    // We intentionally do NOT use `splits { abi { isUniversalApk = true } }`
    // — that emitted a *universal* fat APK bundling all three ABIs (~124MB
    // of .so) and is what blew the release APK past 130MB.
    //
    // Store native libs *compressed* in the APK (extracted at install
    // time). AGP 9 rejects `android:extractNativeLibs="true"` in the
    // manifest and requires this Gradle DSL instead. For a sideloaded
    // .apk this roughly halves the on-disk size of the .so payload.
    packagingOptions {
        jniLibs {
            useLegacyPackaging = true
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
    implementation("io.sentry:sentry-android:8.39.1")
}
