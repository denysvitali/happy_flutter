import org.gradle.api.Action
import org.gradle.api.Project

// AGP 9 removes the org.jetbrains.kotlin.android plugin in favor of built-in
// Kotlin support, but many published Flutter plugins still apply it and use the
// kotlinOptions DSL. Patch them in the pub cache before Gradle evaluates them.
// This replaces the CI-level sed patching and works for local builds too.
fun patchPluginBuildForAgp9(buildFile: java.io.File) {
    if (!buildFile.exists()) return
    var text = buildFile.readText()
    val original = text

    // Bump compileSdkVersion / compileSdk below 36 up to 36.
    text = text.replace(
        Regex("""compileSdkVersion\s+3[0-5]([^0-9]|$)"""),
        "compileSdkVersion 36$1"
    )
    text = text.replace(
        Regex("""compileSdk\s*=\s*3[0-5]([^0-9]|$)"""),
        "compileSdk = 36$1"
    )

    if (text != original) {
        buildFile.writeText(text)
    }
}

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

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        google()
        mavenCentral()
        maven {
            url = uri("https://storage.googleapis.com/download.flutter.io")
        }
    }
}

// Apply the AGP 9 compatibility patch to every Flutter plugin in the pub cache
// before Gradle evaluates it. Keep kotlin-android intact: several plugins ship
// Kotlin-generated Pigeon APIs used by Java sources, so disabling Kotlin drops
// required classes from the Java compile classpath.
gradle.beforeProject(Action<Project> {
    // Only patch Flutter plugin build.gradle(.kts) files in the pub cache.
    if (buildFile.path.contains("hosted/pub.dev/") &&
        (buildFile.name == "build.gradle" || buildFile.name == "build.gradle.kts")
    ) {
        patchPluginBuildForAgp9(buildFile)
    }
})

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.2.1" apply false
    id("org.jetbrains.kotlin.android") version "2.4.0" apply false
    id("com.google.gms.google-services") version "4.4.4" apply false
}

include(":app")
