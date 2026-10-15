import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// release 签名（Flutter 官方约定）：android/key.properties（已 gitignore）四键
// storeFile/storePassword/keyAlias/keyPassword；storeFile 相对本模块（android/app/）解析。
// 缺失或 keystore 不在位 → 回退 debug 签名并打 warning，保证无 keystore 的协作者仍可构建。
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}
val releaseStoreFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
val hasReleaseSigning =
    releaseStoreFile != null &&
        releaseStoreFile.exists() &&
        !keystoreProperties.getProperty("storePassword").isNullOrBlank() &&
        !keystoreProperties.getProperty("keyAlias").isNullOrBlank() &&
        !keystoreProperties.getProperty("keyPassword").isNullOrBlank()
if (!hasReleaseSigning) {
    logger.warn(
        "[booksift] 未找到可用的 release 签名（android/key.properties 缺失或 keystore 不在位）→ " +
            "本次 release 构建回退 debug 签名，产物不可用于分发。签名生成与备份见 docs/发布指南.md。",
    )
}

android {
    namespace = "com.linyuan.booksift"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.linyuan.booksift"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = releaseStoreFile
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // 有 keystore → 正式 release 签名；无 → 回退 debug，`flutter run --release` 仍可用。
            signingConfig =
                if (hasReleaseSigning) {
                    signingConfigs.getByName("release")
                } else {
                    signingConfigs.getByName("debug")
                }
        }
    }
}

flutter {
    source = "../.."
}
