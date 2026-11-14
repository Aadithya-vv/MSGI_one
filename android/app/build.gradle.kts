plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Secrets are supplied only to the build process by the local release wrapper.
val releaseStore = System.getenv("MSGI_RELEASE_STORE_FILE")
val releaseStorePassword = System.getenv("MSGI_RELEASE_STORE_PASSWORD")
val releaseAlias = System.getenv("MSGI_RELEASE_KEY_ALIAS")
val releaseKeyPassword = System.getenv("MSGI_RELEASE_KEY_PASSWORD")
val releaseSigningReady = listOf(releaseStore, releaseStorePassword, releaseAlias, releaseKeyPassword)
    .all { !it.isNullOrBlank() }

gradle.taskGraph.whenReady {
    if (allTasks.any { it.project == project && it.name.contains("Release") }) {
        check(releaseSigningReady) {
            "Release signing is required. Use tool/Build-CompetitionRelease.ps1; debug signing is never a fallback."
        }
    }
}

android {
    namespace = "com.msgi.nexus.msgi_nexus"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.msgi.nexus.msgi_nexus"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("competition") {
            if (releaseSigningReady) {
                storeFile = file(releaseStore!!)
                storePassword = releaseStorePassword
                keyAlias = releaseAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("competition")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
