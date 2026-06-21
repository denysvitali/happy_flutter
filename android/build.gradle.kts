val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// NOTE: cronet_http (via native_dio_adapter) hardcodes compileSdkVersion 34
// but its :jni dependency requires android-35+. CI patches the pub-cache
// copy via sed before Gradle runs. Local dev should run:
//   flutter pub get && sed -i 's/compileSdkVersion 34/compileSdkVersion 36/' \
//     .dart_tool/package_config.json  (find cronet_http path first)
// or use mise which pins a compatible Flutter version.
// Do NOT add a Gradle-level compileSdk override here — it changes the
// task graph after AGP 9.x has already wired up task inputs/outputs,
// causing BundleAar validation failures.

// Kotlin 2.x dropped support for languageVersion < 1.8.
// We hook in after all subprojects are evaluated (avoiding the
// "project already evaluated" error from evaluationDependsOn(":app"))
// and bump any task whose languageVersion / apiVersion is still below
// 1.8 (e.g. sentry_flutter which declares 1.6).
gradle.projectsEvaluated {
    val minVer = org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_1_8
    subprojects {
        val javaTarget =
            tasks
                .matching { it is org.gradle.api.tasks.compile.JavaCompile }
                .map { (it as org.gradle.api.tasks.compile.JavaCompile).targetCompatibility }
                .firstOrNull()
        val jvmTarget = when {
            name == "app" -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
            javaTarget == "17" -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
            javaTarget == "11" -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11
            else -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_1_8
        }
        tasks
            .matching { it is org.jetbrains.kotlin.gradle.tasks.KotlinCompile }
            .forEach {
                val t = it as org.jetbrains.kotlin.gradle.tasks.KotlinCompile
                t.compilerOptions.apply {
                    val cur = languageVersion.orNull
                    if (cur != null && cur < minVer) languageVersion.set(minVer)
                    val curApi = apiVersion.orNull
                    if (curApi != null && curApi < minVer) apiVersion.set(minVer)
                    this.jvmTarget.set(jvmTarget)
                }
            }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
