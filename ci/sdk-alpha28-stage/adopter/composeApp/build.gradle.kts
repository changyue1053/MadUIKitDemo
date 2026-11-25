import java.security.MessageDigest
import org.gradle.api.artifacts.component.ModuleComponentIdentifier
import org.gradle.api.artifacts.component.ModuleComponentSelector
import org.gradle.api.artifacts.result.ResolvedDependencyResult
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    kotlin("multiplatform") version "2.2.21"
    id("org.jetbrains.kotlin.plugin.compose") version "2.2.21"
    id("com.android.library") version "8.11.1"
}

val groupId = "com.mad.maduikit"
val versionPin = "0.1.0-alpha28-sdk-preview01"
val rootComponent = "maduikit-components"
val rootTheme = "maduikit-theme"
kotlin {
    androidTarget { compilerOptions { jvmTarget.set(JvmTarget.JVM_17) } }
    iosSimulatorArm64()
    jvmToolchain(17)
    sourceSets.commonMain.dependencies { implementation("$groupId:$rootComponent:$versionPin") }
}
android {
    namespace = "dev.mad.synthetic.stage"
    compileSdk = 36
    defaultConfig { minSdk = 23 }
    compileOptions { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17 }
}

tasks.register("verifyStageGraph") {
    doLast {
        val config = providers.gradleProperty("madCompileConfiguration").get()
        val target = when(config) {
            "debugCompileClasspath" -> "android"
            "iosSimulatorArm64CompileKlibraries" -> "iossimulatorarm64"
            else -> error("unsupported exact configuration")
        }
        val declared = configurations.getByName("commonMainImplementation").dependencies.filter { it.group == groupId }
        require(declared.size == 1 && declared.single().group == groupId &&
                declared.single().name == rootComponent && declared.single().version == versionPin)
        val cfg = configurations.getByName(config)
        val result = cfg.incoming.resolutionResult
        val nodes = setOf(rootComponent, rootTheme, "$rootComponent-$target", "$rootTheme-$target")
        fun sdkId(id: Any) = (id as? ModuleComponentIdentifier)?.takeIf { it.group == groupId }
        val sdkNodes = result.allComponents.mapNotNull { sdkId(it.id) }
        require(sdkNodes.size == 4 && sdkNodes.map { it.module }.toSet() == nodes &&
                sdkNodes.all { it.version == versionPin })
        val direct = result.root.dependencies.filterIsInstance<ResolvedDependencyResult>().filter { e ->
            val ask = e.requested as? ModuleComponentSelector
            ask?.group == groupId && ask.module == rootComponent && ask.version == versionPin
        }
        require(direct.isNotEmpty() && direct.all { sdkId(it.selected.id)?.module == rootComponent })
        val edges = result.allDependencies.filterIsInstance<ResolvedDependencyResult>()
            .mapNotNull { e ->
                val source = sdkId(e.from.id)?.module
                val dest = sdkId(e.selected.id)?.module
                if (source != null && dest != null) source to dest else null
            }.toSet()
        require(edges == setOf(rootComponent to "$rootComponent-$target",
              "$rootComponent-$target" to rootTheme, rootTheme to "$rootTheme-$target"))
        val stage = file(providers.gradleProperty("madStage").get()).canonicalFile
        val artifacts = cfg.incoming.artifacts.artifacts
        val expectedLeaves = setOf("$rootComponent-$target", "$rootTheme-$target")
        val selected = artifacts.mapNotNull { a -> sdkId(a.id.componentIdentifier)?.let { it to a.file } }
        require(selected.size == 2 && selected.map { it.first.module }.toSet() == expectedLeaves)
        val ext = if (target == "android") "aar" else "klib"
        fun sha(file: File) = MessageDigest.getInstance("SHA-256").digest(file.readBytes())
            .joinToString("") { "%02x".format(it) }
        val rows = selected.map { (id, received) ->
            require(id.version == versionPin)
            val staged = stage.resolve("com/mad/maduikit/${id.module}/$versionPin/${id.module}-$versionPin.$ext")
            require(staged.canonicalFile.toPath().startsWith(stage.toPath()))
            require(staged.isFile && received.isFile && received.extension == ext)
            val digest = sha(staged)
            require(sha(received) == digest)
            "${id.module}\t$digest"
        }.sorted()
        require(artifacts.any {
            val id = it.id.componentIdentifier as? ModuleComponentIdentifier
            id != null && id.group in setOf("org.jetbrains.compose.ui","androidx.compose.ui") &&
                (id.module=="ui-text" || id.module.startsWith("ui-text-"))
        })
        layout.buildDirectory.file("reports/sdk-stage-$target.tsv").get().asFile.also { f ->
            f.parentFile.mkdirs()
            f.writeText(rows.joinToString("\n", postfix = "\n"))
        }
    }
}
