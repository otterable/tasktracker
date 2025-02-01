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

// Add the Google services Gradle plugin dependency in your plugins block if using Kotlin DSL:
plugins {
    // ... other plugins
    id("com.google.gms.google-services") version "4.4.2" apply false
}
