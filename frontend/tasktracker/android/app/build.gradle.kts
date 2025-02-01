plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Apply the Google services plugin to process google-services.json.
    id("com.google.gms.google-services")
}

android {
    // Use a unique namespace for your app:
    namespace = "com.molentracker"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Set Java compile options to Java 17 (the highest Kotlin supports)
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Enable core library desugaring for libraries such as flutter_local_notifications
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        // Set the JVM target to "17"
        jvmTarget = "17"
    }

    defaultConfig {
        // The applicationId is set to "com.molentracker" per your request.
        applicationId = "com.molentracker"
        // Use the Flutter-provided values:
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Create a signing config for release builds
        create("release") {
            // Use a relative path because the keystore is in the "android" folder, not in "android/app"
            storeFile = file("../molentracker-release.jks")
            // Replace these with your actual keystore and key passwords.
            storePassword = "moulin"
            keyAlias = "molentracker"
            keyPassword = "moulin"
        }
    }

    buildTypes {
        release {
            // Use the release signing config created above.
            signingConfig = signingConfigs.getByName("release")
            // Optionally, enable code shrinking and obfuscation with ProGuard:
            // isMinifyEnabled = true
            // proguardFiles(getDefaultProguardFile("proguard-android.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Add the desugaring library dependency required by flutter_local_notifications.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.2")
}
