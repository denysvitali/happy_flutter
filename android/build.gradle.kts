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

// Kotlin 2.x dropped support for languageVersion 1.6. Override it to 1.8
// for all subprojects (e.g. sentry_flutter) that still declare the old value.
subprojects {
    afterEvaluate {
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>()
            .configureEach {
                val opts = kotlinOptions
                if (opts.languageVersion != null &&
                    opts.languageVersion!! < "1.8"
                ) {
                    opts.languageVersion = "1.8"
                }
                if (opts.apiVersion != null &&
                    opts.apiVersion!! < "1.8"
                ) {
                    opts.apiVersion = "1.8"
                }
            }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
