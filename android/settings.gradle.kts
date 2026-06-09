pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    // Include Flutter's gradle build, mirroring to a writable location if needed.
    // Gradle 9.x rejects read-only project directories (Nix store) for included builds.
    // The Flutter gradle plugin navigates ../../.. to find the SDK root, so the mirror
    // must preserve that depth: .flutter-sdk/packages/flutter_tools/gradle.
    val flutterGradlePath = "$flutterSdkPath/packages/flutter_tools/gradle"
    val flutterGradleDir = file(flutterGradlePath)
    if (flutterGradleDir.exists()) {
        val effectivePath = if (flutterGradleDir.canWrite()) {
            flutterGradlePath
        } else {
            val mirror = file("${rootDir}/.flutter-sdk")
            val mirrorGradle = file("${mirror}/packages/flutter_tools/gradle")
            if (!mirrorGradle.exists()
                || mirrorGradle.lastModified() < flutterGradleDir.lastModified()
            ) {
                mirror.deleteRecursively()
                // Copy the gradle dir into a structure preserving the 3-level depth
                flutterGradleDir.copyRecursively(mirrorGradle, overwrite = true)
                // Symlink SDK subdirs that the plugin references via ../../..
                val sdkRoot = file(flutterSdkPath)
                for (child in sdkRoot.listFiles() ?: emptyArray()) {
                    if (child.name == "packages") continue
                    val link = file("${mirror}/${child.name}").toPath()
                    if (!java.nio.file.Files.exists(link)) {
                        java.nio.file.Files.createSymbolicLink(
                            link, child.toPath()
                        )
                    }
                }
            }
            mirrorGradle.absolutePath
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
    id("com.android.application") version "9.2.1" apply false
    id("org.jetbrains.kotlin.android") version "2.4.0" apply false
    id("com.google.gms.google-services") version "4.4.4" apply false
}

include(":app")
