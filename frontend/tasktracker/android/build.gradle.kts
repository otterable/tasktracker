allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.buildDir = file("../build")
subprojects {
    project.buildDir = file("${rootProject.buildDir}/${project.name}")
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}

// Ensure the Google services Gradle plugin is available (using Kotlin DSL):
plugins {
    id("com.google.gms.google-services") version "4.4.2" apply false
}
