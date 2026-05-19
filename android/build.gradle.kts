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

// Kotlin 2.x dropped support for languageVersion < 1.8.
// We hook in after all subprojects are evaluated (avoiding the
// "project already evaluated" error from evaluationDependsOn(":app"))
// and bump any task whose languageVersion / apiVersion is still below
// 1.8 (e.g. sentry_flutter which declares 1.6).
gradle.projectsEvaluated {
    val minVer = org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_1_8
    subprojects {
        val jvmTarget =
            if (name == "app") {
                org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
            } else {
                org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11
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
