allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

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

// Kotlin 2.x dropped support for languageVersion < 1.8. Override it for
// all subprojects (e.g. sentry_flutter) that still declare the old value.
subprojects {
    afterEvaluate {
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>()
            .configureEach {
                compilerOptions {
                    val minVer =
                        org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_1_8
                    val cur = languageVersion.orNull
                    if (cur != null && cur < minVer) {
                        languageVersion.set(minVer)
                    }
                    val curApi = apiVersion.orNull
                    if (curApi != null && curApi < minVer) {
                        apiVersion.set(minVer)
                    }
                }
            }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
