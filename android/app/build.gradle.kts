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
val buildingTest2 = System.getenv("CHEKMI_TEST2_BUILD")
    ?.equals("true", ignoreCase = true) == true
if (buildingRelease && !releaseKeystoreFile.exists() && !buildingTest2) {
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
        applicationId = if (buildingTest2) {
            "com.leulverify.verify_me.test2"
        } else {
            "com.leulverify.verify_me"
        }
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = if (buildingTest2) {
            flutter.versionCode + 2
        } else {
            flutter.versionCode
        }
        versionName = if (buildingTest2) {
            "${flutter.versionName}-test2.2"
        } else {
            flutter.versionName
        }
        manifestPlaceholders["appLabel"] = if (buildingTest2) {
            "CHEKMI Test 2"
        } else {
            "CHEKMI"
        }
        manifestPlaceholders["usesCleartextTraffic"] = buildingTest2.toString()
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
        release {
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = if (releaseKeystoreFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                // Installable review builds only. Production releases still
                // fail above when the upload keystore is unavailable.
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter { source = "../.." }
