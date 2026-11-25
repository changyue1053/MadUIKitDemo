import org.gradle.api.artifacts.component.ModuleComponentIdentifier
import org.gradle.api.artifacts.result.ResolvedDependencyResult
import java.security.MessageDigest

plugins { kotlin("multiplatform") version "2.2.21"; id("com.android.application") version "8.11.1"; id("org.jetbrains.kotlin.plugin.compose") version "2.2.21" }

val sdkEntry = "maduikit-components"
val sdkVersion = "0.1.0-alpha19-sdk-preview01"
kotlin {
    androidTarget { compilerOptions { jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17) } }
    if (providers.gradleProperty("madApple").orNull == "true") {
        iosArm64()
        iosSimulatorArm64 { binaries.framework { baseName = "MadUIKitS1Adopter"; isStatic = true } }
    }
    jvmToolchain(17)
    sourceSets.commonMain.dependencies { implementation("com.mad.maduikit:$sdkEntry:$sdkVersion") }
    sourceSets.androidMain.dependencies { implementation("androidx.activity:activity-compose:1.10.1") }
}
android {
    namespace = "dev.mad.synthetic.typography"
    compileSdk = 36
    defaultConfig { applicationId = "dev.mad.synthetic.typography"; minSdk = 23; targetSdk = 36 }
    compileOptions { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17 }
}

val verifySdkCompile by tasks.registering {
    doLast {
        val selected = providers.gradleProperty("madCompileConfiguration").get()
        require(selected in setOf("debugCompileClasspath", "debugRuntimeClasspath", "iosSimulatorArm64CompileKlibraries", "iosArm64CompileKlibraries"))
        val config = configurations.getByName(selected)
        val dependencies = config.incoming.resolutionResult.allDependencies.filterIsInstance<ResolvedDependencyResult>()
        val graph = dependencies.mapNotNull {
            val selectedId = it.selected.id as? ModuleComponentIdentifier ?: return@mapNotNull null
            val origin = (it.from.id as? ModuleComponentIdentifier)?.displayName ?: "synthetic-consumer"
            "$origin -> ${selectedId.displayName}"
        }.sorted()
        val artifacts = config.incoming.artifacts.artifacts
        val sdkArtifacts = artifacts.filter { (it.id.componentIdentifier as? ModuleComponentIdentifier)?.group == "com.mad.maduikit" }
        val expectedModules = if (sdkEntry == "maduikit-theme") setOf("maduikit-theme") else setOf("maduikit-theme", "maduikit-components")
        require(sdkArtifacts.size == expectedModules.size)
        val suffix = when (selected) {
            "iosSimulatorArm64CompileKlibraries" -> "-iossimulatorarm64"
            "iosArm64CompileKlibraries" -> "-iosarm64"
            else -> "-android"
        }
        require(sdkArtifacts.map {
            val m = it.id.componentIdentifier as ModuleComponentIdentifier
            require(m.version == sdkVersion)
            m.module
        }.toSet() == expectedModules.map { it + suffix }.toSet())
        val stage = file(providers.gradleProperty("madStage").get()).canonicalFile
        fun sha(f: File) = MessageDigest.getInstance("SHA-256").digest(f.readBytes()).joinToString("") { "%02x".format(it) }
        sdkArtifacts.forEach {
            val id=it.id.componentIdentifier as ModuleComponentIdentifier
            val ext=if(suffix=="-android") "aar" else "klib"
            val original=stage.resolve("com/mad/maduikit/${id.module}/$sdkVersion/${id.module}-$sdkVersion.$ext")
            require(original.isFile && it.file.isFile && sha(original)==sha(it.file))
        }
        // Gradle module aliases may resolve to AndroidX ui-text on Android.
        require(artifacts.any {
            val id = it.id.componentIdentifier as? ModuleComponentIdentifier
            id != null && id.group in setOf("org.jetbrains.compose.ui","androidx.compose.ui") &&
                (id.module=="ui-text" || id.module.startsWith("ui-text-"))
        })
        val external = artifacts.mapNotNull {
            val id = it.id.componentIdentifier as? ModuleComponentIdentifier ?: return@mapNotNull null
            if (id.group !in setOf("com.mad.maduikit", "org.jetbrains.compose.ui", "androidx.compose.ui")) return@mapNotNull null
            if (id.group != "com.mad.maduikit" && id.module != "ui-text" && !id.module.startsWith("ui-text-")) return@mapNotNull null
            require(it.file.isFile)
            "${id.displayName}: ${it.file.name}, ${sha(it.file)}, ${it.variant.attributes}"
        }.sorted()
        val report=layout.buildDirectory.file("reports/sdk-$sdkEntry-$selected.txt").get().asFile
        report.parentFile.mkdirs()
        report.writeText((listOf("scope=$sdkEntry/$selected") + graph + external).joinToString("\n","", "\n"))
    }
}
