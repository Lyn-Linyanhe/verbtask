import java.util.Properties

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val signingProperties = Properties()
val signingPropertiesFile = rootProject.file("key.properties")
if (signingPropertiesFile.exists()) {
    signingPropertiesFile.inputStream().use(signingProperties::load)
}

fun signingValue(environmentName: String, propertyName: String): String? =
    System.getenv(environmentName) ?: signingProperties.getProperty(propertyName)

android {
    namespace = "com.verbapp.verb_app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.verbapp.verb_app"
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            val storeFilePath = signingValue("VERBTASK_STORE_FILE", "storeFile")
            val storePassword = signingValue("VERBTASK_STORE_PASSWORD", "storePassword")
            val keyAlias = signingValue("VERBTASK_KEY_ALIAS", "keyAlias")
            val keyPassword = signingValue("VERBTASK_KEY_PASSWORD", "keyPassword")
            val missingSigning = listOf(storeFilePath, storePassword, keyAlias, keyPassword)
                .any { it.isNullOrBlank() }
            val releaseRequested = gradle.startParameter.taskNames.any {
                it.contains("release", ignoreCase = true)
            }
            if (missingSigning && releaseRequested) {
                throw GradleException(
                    "VerbTask release signing is not configured. Set VERBTASK_STORE_FILE, " +
                        "VERBTASK_STORE_PASSWORD, VERBTASK_KEY_ALIAS and VERBTASK_KEY_PASSWORD."
                )
            }
            if (!missingSigning) {
                signingConfig = signingConfigs.create("release") {
                    storeFile = file(storeFilePath!!)
                    this.storePassword = storePassword
                    this.keyAlias = keyAlias
                    this.keyPassword = keyPassword
                }
            }
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
