import org.gradle.api.artifacts.component.ModuleComponentIdentifier
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import java.security.MessageDigest

plugins {
    id("org.jetbrains.kotlin.multiplatform")
    id("org.jetbrains.kotlin.plugin.compose")
    id("org.jetbrains.compose")
    id("com.android.application")
}

kotlin {
    jvmToolchain(17)
    androidTarget {
        compilerOptions {
            jvmTarget.set(JvmTarget.JVM_17)
        }
    }
    listOf(iosArm64(), iosSimulatorArm64()).forEach { target ->
        target.binaries.framework {
            baseName = "MadUIKitDemoShared"
            isStatic = true
        }
    }

    sourceSets {
        commonMain.dependencies {
            implementation("com.mad.maduikit:maduikit-components:0.1.0-alpha01")
            implementation(compose.runtime)
            implementation(compose.foundation)
            implementation(compose.material3)
            implementation(compose.ui)
            // Keep the coroutine version aligned with the Compose host.
            implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.10.2")
        }
        androidMain.dependencies {
            implementation("androidx.activity:activity-compose:1.10.1")
        }
    }
}

android {
    namespace = "dev.maduikit.demo"
    compileSdk = 36

    defaultConfig {
        applicationId = "dev.maduikit.demo.p5"
        minSdk = 23
        targetSdk = 36
        versionCode = 5
        versionName = "0.0.5-p5-local"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}


// Confirms the actual Android runtime artifacts equal the staged binaries; no Maven Local or project substitution.
tasks.register("verifyStagedAndroidSdk") {
    group = "verification"
    description = "Check the version, module IDs, and SHA-256 of both staged Android SDK AARs."
    doLast {
        val expectedVersion = "0.1.0-alpha01"
        val groupId = "com.mad.maduikit"
        val modules = setOf("maduikit-components-android", "maduikit-theme-android")
        val resolved = configurations.getByName("debugRuntimeClasspath").incoming.artifacts.artifacts
            .mapNotNull { artifact ->
                (artifact.id.componentIdentifier as? ModuleComponentIdentifier)
                    ?.takeIf { it.group == groupId }?.let { it to artifact.file }
            }
        check(resolved.map { it.first.module }.toSet() == modules && resolved.size == modules.size) {
            "Expected only the two staged external Android modules; found: ${resolved.map { it.first }}"
        }
        fun digest(file: File): String = MessageDigest.getInstance("SHA-256").digest(file.readBytes())
            .joinToString("") { (it.toInt() and 255).toString(16).padStart(2, '0') }
        for ((component, artifact) in resolved.sortedBy { it.first.module }) {
            check(component.version == expectedVersion && artifact.extension == "aar") {
                "Unexpected SDK runtime artifact: $component (${artifact.name})"
            }
            val stagingDir = rootProject.file(
                providers.gradleProperty("maduikitStagingDir").getOrElse("../maduikit-maven")
            )
            val staged = stagingDir.resolve(
                "com/mad/maduikit/${component.module}/$expectedVersion/${component.module}-$expectedVersion.aar"
            )
            check(staged.isFile && digest(staged) == digest(artifact)) {
                "Resolved artifact does not match the filesystem staging binary: $component"
            }
            println("Verified external module $component sha256=${digest(artifact)}")
        }
    }
}
