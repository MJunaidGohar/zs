// Top-level build.gradle.kts for Flutter Android project

plugins {
    id("com.android.application") version "8.12.2" apply false
    id("org.jetbrains.kotlin.android") version "2.2.10" apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Keep Flutter’s custom build output redirection
val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    project.evaluationDependsOn(":app")
}

// Clean task
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
