/*
 * File Purpose: Configures Attractive's Android application, release signing, tests, and assets.
 * Primary Components: API 36 build settings, JDK 21 compilation, offline web assets, optional signing.
 * Inputs/Outputs: Bundles ../web into APK/AAB files and optionally signs from private env/properties.
 */

import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

fun privateValue(name: String): String? =
    providers.environmentVariable(name)
        .orElse(providers.gradleProperty(name))
        .orNull
        ?.takeIf(String::isNotBlank)

val releaseStorePath = privateValue("ATTRACTIVE_STORE_FILE")
    ?: privateValue("ATTRACTIVE_RELEASE_STORE_FILE")
val releaseStorePassword = privateValue("ATTRACTIVE_STORE_PASSWORD")
    ?: privateValue("ATTRACTIVE_RELEASE_STORE_PASSWORD")
val releaseKeyAlias = privateValue("ATTRACTIVE_KEY_ALIAS")
    ?: privateValue("ATTRACTIVE_RELEASE_KEY_ALIAS")
val releaseKeyPassword = privateValue("ATTRACTIVE_KEY_PASSWORD")
    ?: privateValue("ATTRACTIVE_RELEASE_KEY_PASSWORD")
val hasReleaseSigning = listOf(
    releaseStorePath,
    releaseStorePassword,
    releaseKeyAlias,
    releaseKeyPassword,
).all { it != null }
val versionProperties = Properties().apply {
    file("../version.properties").inputStream().use(::load)
}
val attractiveVersionName = requireNotNull(versionProperties.getProperty("VERSION_NAME"))
val attractiveVersionCode = requireNotNull(versionProperties.getProperty("VERSION_CODE")).toInt()

android {
    namespace = "attractive.lukesteuber.android"
    compileSdk = 36

    defaultConfig {
        applicationId = "attractive.lukesteuber.android"
        minSdk = 26
        targetSdk = 36
        versionCode = attractiveVersionCode
        versionName = attractiveVersionName
        testInstrumentationRunner = "attractive.lukesteuber.android.NativeUiRestorationRunner"
    }

    sourceSets {
        getByName("main").assets.srcDir("../web")
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(requireNotNull(releaseStorePath))
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
                enableV1Signing = true
                enableV2Signing = true
                enableV3Signing = true
                enableV4Signing = true
            }
        }
    }

    buildTypes {
        debug {
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
        }
        release {
            isDebuggable = false
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            signingConfig = signingConfigs.findByName("release")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }

    testOptions {
        unitTests.isIncludeAndroidResources = false
        unitTests.all {
            it.systemProperty("attractive.webDir", file("../web").absolutePath)
        }
    }

    lint {
        abortOnError = true
        checkReleaseBuilds = true
        warningsAsErrors = true
        disable += "ObsoleteSdkInt"
        // Keep the tested API 36 baseline; an SDK migration is a separate change.
        disable += "OldTargetApi"
        // Retain the tested wrapper for this viewport change; dependency freshness
        // is a separate maintenance task, not a source correctness failure.
        disable += "AndroidGradlePluginVersion"
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_21)
        allWarningsAsErrors.set(true)
    }
}

dependencies {
    testImplementation("junit:junit:4.13.2")
}

tasks.register("printVersion") {
    group = "help"
    description = "Prints the Android versionName for release staging."
    doLast {
        println(attractiveVersionName)
    }
}

tasks.register<Exec>("prepareWebAssets") {
    group = "build"
    description = "Prepare offline attractive-web assets into android/web."
    workingDir = rootProject.projectDir.parentFile
    commandLine("bash", "scripts/prepare-android-web.sh")
}

tasks.named("preBuild").configure {
    dependsOn("prepareWebAssets")
}
