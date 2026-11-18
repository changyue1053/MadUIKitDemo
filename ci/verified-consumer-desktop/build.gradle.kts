plugins {
    kotlin("jvm") version "2.2.21"
    id("org.jetbrains.kotlin.plugin.compose") version "2.2.21"
    id("org.jetbrains.compose") version "1.9.3"
    application
}
val demoRoot = file("../..")
val sdkRoot = file(providers.gradleProperty("maduikitSdkDir").getOrElse("../../../MadUIKit"))
kotlin {
    compilerOptions { jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17) }
    sourceSets.main {
        kotlin.srcDir(demoRoot.resolve("composeApp/src/commonMain/kotlin"))
        // A source adapter, NOT verification of a published JVM SDK artifact.
        kotlin.srcDir(sdkRoot.resolve("maduikit-theme/src/commonMain/kotlin"))
    }
}
java {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
}
dependencies {
    implementation(compose.desktop.currentOs)
    implementation(compose.material3)
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.10.2")
}
val verifyGeneratedSource by tasks.registering(Exec::class) {
    commandLine("python3", demoRoot.resolve("scripts/verify-codegen-consumer.py").absolutePath,
        "--codegen-root", file(providers.gradleProperty("maduikitCodegenDir")
            .getOrElse("../../../MadUIKitCodegen")).absolutePath)
}
tasks.named("compileKotlin") { dependsOn(verifyGeneratedSource) }
application {
    mainClass.set("CaptureKt")
    applicationDefaultJvmArgs = listOf("-Djava.awt.headless=true") +
        providers.gradleProperty("captureUserHome").orNull?.let { listOf("-Duser.home=$it") }.orEmpty()
}
