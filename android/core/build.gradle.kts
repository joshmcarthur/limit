plugins {
    alias(libs.plugins.kotlin.jvm)
}

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(17))
    }
}

dependencies {
    implementation(libs.org.json)
    testImplementation(libs.kotlin.test)
}

tasks.test {
    useJUnitPlatform()
}
