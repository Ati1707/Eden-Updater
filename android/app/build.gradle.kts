plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.eden.updater.eden_updater"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"
    
    // Suppress deprecation warnings for dependencies
    lintOptions {
        disable("Deprecation")
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.eden.updater.eden_updater"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            
            // Completely disable R8/ProGuard to avoid missing class issues
            isMinifyEnabled = false
            isShrinkResources = false
            
            // Explicitly disable R8
            proguardFiles.clear()
        }
    }
}

dependencies {
    // Add Google Play Core to resolve missing classes
    implementation("com.google.android.play:core:1.10.3")
}

// Remove from app level since we're adding it to root build.gradle.kts

flutter {
    source = "../.."
}
