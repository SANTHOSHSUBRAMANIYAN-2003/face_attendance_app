import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.projectDir.resolve("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.nmspayroll.face_attendance_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.nmspayroll.face_attendance_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = 14
        versionName = flutter.versionName
        ndk {
            // Exclude x86_64 (emulator-only). All real Android devices use arm64-v8a or armeabi-v7a.
            // This removes the non-16KB-aligned x86_64 libtensorflowlite_jni.so from the bundle.
            abiFilters += listOf("arm64-v8a", "armeabi-v7a")
        }
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    packaging {
        jniLibs {
            excludes += "/lib/x86_64/**"
            excludes += "/lib/x86/**"
        }
    }
}

flutter {
    source = "../.."
}

configurations.all {
    resolutionStrategy {
        // Force all transitive TF Lite references to use the 16KB-aligned version
        force("com.google.ai.edge.litert:litert:1.4.0")
        force("com.google.ai.edge.litert:litert-support:1.4.0")
    }
    // Replace old tensorflow-lite dependency with LiteRT everywhere
    resolutionStrategy.dependencySubstitution {
        substitute(module("org.tensorflow:tensorflow-lite")).using(module("com.google.ai.edge.litert:litert:1.4.0"))
        substitute(module("org.tensorflow:tensorflow-lite-support")).using(module("com.google.ai.edge.litert:litert-support:1.4.0"))
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.3")
    // Google AI Edge LiteRT - 16KB page-aligned replacement for TF Lite
    // https://ai.google.dev/edge/litert/inference
    implementation("com.google.ai.edge.litert:litert:1.4.0")
    implementation("com.google.ai.edge.litert:litert-support:1.4.0")
}
