import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseKeystoreProperties = Properties()
val releaseKeystoreFile = rootProject.file("key.properties")
if (releaseKeystoreFile.exists()) {
    releaseKeystoreFile.inputStream().use(releaseKeystoreProperties::load)
}
val buildingRelease = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}
if (buildingRelease && !releaseKeystoreFile.exists()) {
    throw GradleException(
        "Release signing is not configured. Copy android/key.properties.example " +
            "to android/key.properties and supply the upload keystore values."
    )
}

android {
    namespace = "com.leulverify.verify_me"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }

    defaultConfig {
        applicationId = "com.leulverify.verify_me"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (releaseKeystoreFile.exists()) {
                keyAlias = releaseKeystoreProperties["keyAlias"] as String
                keyPassword = releaseKeystoreProperties["keyPassword"] as String
                storeFile = file(releaseKeystoreProperties["storeFile"] as String)
                storePassword = releaseKeystoreProperties["storePassword"] as String
            }
        }
    }
    buildTypes {
        release { signingConfig = signingConfigs.getByName("release") }
    }
}

flutter { source = "../.." }
