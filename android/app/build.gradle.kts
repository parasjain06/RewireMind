import java.util.Properties

// The upload key Play Store builds are signed with. Kept out of the source in
// android/key.properties (see STORE_RELEASE.md); when that file is missing,
// release builds fall back to the debug key so they still build and install
// here — Play will simply refuse to accept them until the real key exists.
val keyProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.parasjain.rewiremind"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications schedules with java.time, which needs
        // desugaring to run on the older Android versions we still support.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // Permanent once published: the store listing is keyed on it.
        applicationId = "com.parasjain.rewiremind"
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

        // A throwaway copy that installs beside the real app, with its own
        // empty data: set REWIRE_PREVIEW=1 when building. It exists to look at
        // the first-launch experience without uninstalling anything.
        val preview = System.getenv("REWIRE_PREVIEW") == "1"
        if (preview) applicationIdSuffix = ".preview"
        manifestPlaceholders["appLabel"] =
            if (preview) "RewireMind Preview" else "RewireMind"
    }

    signingConfigs {
        if (keyProperties.isNotEmpty()) {
            create("upload") {
                storeFile = file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keyProperties.isNotEmpty()) {
                signingConfigs.getByName("upload")
            } else {
                signingConfigs.getByName("debug")
            }
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
