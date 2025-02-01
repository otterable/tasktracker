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
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_1_8.toString()
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
        release {
            // Replace the file path with the actual location of your release keystore.
            storeFile = file("C:/Users/ottr/molentracker-release.jks")
            // Replace these with your actual keystore and key passwords.
            storePassword = "your_store_password"
            keyAlias = "molentracker"
            keyPassword = "your_key_password"
        }
    }

    buildTypes {
        release {
            // Use the release signing config for release builds.
            signingConfig = signingConfigs.release
            // Optionally, enable code shrinking and obfuscation with ProGuard:
            // isMinifyEnabled = true
            // proguardFiles(getDefaultProguardFile("proguard-android.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}
