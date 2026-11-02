plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
}

// Release signing reads LIMIT_UPLOAD_STORE_FILE, LIMIT_UPLOAD_STORE_PASSWORD,
// LIMIT_UPLOAD_KEY_ALIAS, and LIMIT_UPLOAD_KEY_PASSWORD. Unset leaves the release build unsigned.
val uploadStorePath = System.getenv("LIMIT_UPLOAD_STORE_FILE")

android {
    namespace = "com.joshmcarthur.limit"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.joshmcarthur.limit"
        minSdk = 26
        targetSdk = 36
        versionCode = 2
        versionName = "1.0.1"
    }

    if (uploadStorePath != null) {
        signingConfigs {
            create("release") {
                storeFile = project.file(uploadStorePath)
                storePassword = System.getenv("LIMIT_UPLOAD_STORE_PASSWORD")
                keyAlias = System.getenv("LIMIT_UPLOAD_KEY_ALIAS")
                keyPassword = System.getenv("LIMIT_UPLOAD_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"))
            if (uploadStorePath != null) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

dependencies {
    implementation(project(":core"))
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.kotlinx.coroutines.android)
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.graphics)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.material.icons)
    implementation(libs.androidx.car.app)
    implementation(libs.androidx.car.app.projected)
    implementation(libs.androidx.glance)
    implementation(libs.androidx.glance.material3)
}
