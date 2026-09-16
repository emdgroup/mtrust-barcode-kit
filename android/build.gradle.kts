group = "com.emddigital.barcode_kit"
version = "1.0-SNAPSHOT"

val camerax_version = "1.3.0-alpha03"

buildscript {
    val kotlinVersion = "2.4.0"
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:9.4.0")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
}

android {
    namespace = "com.emddigital.barcode_kit"

    compileSdk = 37

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // No explicit sourceSets block: `src/main/kotlin` is already a default
    // recognized source directory once the Kotlin Gradle plugin is applied
    // (as it is here via the classpath dependency + `kotlin { }` block
    // below), so this was redundant. It's also actively broken under AGP
    // 8.9-8.12 (the range many consuming apps are still pinned to, since
    // AGP 9.x+ has other breaking changes) - `sourceSets { getByName("main")
    // { ... } }` throws:
    //   java.lang.ClassCastException: class
    //   com.android.build.gradle.internal.api.DefaultAndroidSourceSet_Decorated
    //   cannot be cast to class com.android.build.api.dsl.AndroidLibrarySourceSet
    // This is a known AGP internal source-set bridging regression for
    // library modules in that AGP version range. Verified removing this
    // block (letting the default `src/main/kotlin` convention apply
    // instead) builds successfully under AGP 8.12.3 without any source
    // files being dropped.
    defaultConfig {
        minSdk = 24
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    implementation("androidx.camera:camera-camera2:$camerax_version")
    implementation("androidx.camera:camera-lifecycle:$camerax_version")
    implementation("androidx.camera:camera-mlkit-vision:$camerax_version")
    implementation("com.google.mlkit:barcode-scanning:17.0.2")
    implementation("com.google.android.gms:play-services-mlkit-text-recognition-common:19.1.0")
    implementation("com.google.android.gms:play-services-mlkit-text-recognition:19.0.1")
}
