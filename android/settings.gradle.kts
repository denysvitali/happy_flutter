pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    // Include Flutter's gradle build, copying to a writable location if needed
    // (Nix store is read-only which Gradle 9.x rejects for included builds)
    val flutterGradlePath = "$flutterSdkPath/packages/flutter_tools/gradle"
    val flutterGradleDir = file(flutterGradlePath)
    if (flutterGradleDir.exists()) {
        val effectivePath = if (flutterGradleDir.canWrite()) {
            flutterGradlePath
        } else {
            val writableCopy = file("${rootDir}/.flutter-gradle")
            if (!writableCopy.exists()
                || writableCopy.lastModified() < flutterGradleDir.lastModified()
            ) {
                writableCopy.deleteRecursively()
                flutterGradleDir.copyRecursively(writableCopy, overwrite = true)
            }
            writableCopy.absolutePath
        }
        includeBuild(effectivePath)
    }

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.1.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
    id("com.google.gms.google-services") version "4.4.4" apply false
}

include(":app")
