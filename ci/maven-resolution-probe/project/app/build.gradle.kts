import groovy.json.JsonOutput
import org.gradle.api.artifacts.component.ModuleComponentIdentifier
import org.gradle.api.artifacts.result.ResolvedDependencyResult
import org.gradle.api.artifacts.result.UnresolvedDependencyResult
import org.gradle.api.attributes.AttributeContainer
import java.security.MessageDigest

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}
android {
    namespace = "example.probe.variant"
    compileSdk = 36
    defaultConfig { applicationId = "example.probe.variant"; minSdk = 23; targetSdk = 36 }
    buildFeatures { compose = true }
    compileOptions { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17 }
}
kotlin { jvmToolchain(17) }
dependencies {
    implementation("com.mad.maduikit:maduikit-components:0.1.0-alpha01")
    implementation("androidx.activity:activity-compose:1.10.1")
    implementation("org.jetbrains.compose.material3:material3:1.9.0")
    implementation("org.jetbrains.compose.components:components-resources:1.9.3")
    implementation("org.jetbrains.compose.ui:ui-backhandler:1.9.1")
    implementation("org.jetbrains.androidx.lifecycle:lifecycle-runtime-compose:2.9.6")
}

fun digest(file: File): String = file.inputStream().use { stream ->
    val sha = MessageDigest.getInstance("SHA-256")
    val buffer = ByteArray(65536)
    while (true) {
        val n = stream.read(buffer)
        if (n < 0) break
        sha.update(buffer, 0, n)
    }
    sha.digest().joinToString("") { "%02x".format(it) }
}
fun attributes(values: AttributeContainer) =
    values.keySet().associate { it.name to values.getAttribute(it).toString() }.toSortedMap()

tasks.register("resolvePublicAndroidRuntime") {
    doLast {
        val mode = providers.gradleProperty("probeMode").get()
        check(mode in setOf("online", "offline") && gradle.startParameter.isOffline == (mode == "offline"))
        val config = configurations.getByName("debugRuntimeClasspath")
        val resolution = config.incoming.resolutionResult
        val unresolved = resolution.allDependencies.filterIsInstance<UnresolvedDependencyResult>()
        check(unresolved.isEmpty()) { "Unresolved runtime dependency: ${unresolved.map { it.attempted.displayName }}" }
        data class Artifact(val id: ModuleComponentIdentifier, val file: File, val attrs: Map<String,String>, val sha: String)
        val resolved = config.incoming.artifacts.artifacts.map {
            val id = it.id.componentIdentifier as? ModuleComponentIdentifier
                ?: error("Unexpected local/project artifact")
            Artifact(id, it.file, attributes(it.variant.attributes), digest(it.file))
        }.sortedWith(compareBy({ it.id.displayName }, { it.file.name }, { it.sha }))
        check(resolved.isNotEmpty())
        val sdk = resolved.filter { it.id.group == "com.mad.maduikit" }
        check(sdk.size == 2 && sdk.map { it.id.module }.toSet() ==
                setOf("maduikit-components-android","maduikit-theme-android"))
        val stage = file(providers.gradleProperty("madStage").get())
        for (artifact in sdk) {
            val m = artifact.id.module
            val version = artifact.id.version
            check(version == "0.1.0-alpha01" && artifact.file.extension == "aar"
                    && artifact.attrs["org.jetbrains.kotlin.platform.type"] == "androidJvm")
            val published = stage.resolve("com/mad/maduikit/$m/$version/$m-$version.aar")
            check(artifact.sha == digest(published)) { "Staged SDK AAR hash mismatch: $m" }
        }
        val edges = resolution.allDependencies.filterIsInstance<ResolvedDependencyResult>()
        check(edges.any { edge ->
            val from = edge.from.id as? ModuleComponentIdentifier
            val to = edge.selected.id as? ModuleComponentIdentifier
            from?.group == "com.mad.maduikit" && from.module == "maduikit-components-android"
                && to?.group == "com.mad.maduikit" && to.module.startsWith("maduikit-theme")
        }) { "Missing transitive theme edge" }
        val payload = mapOf(
            "artifactCount" to resolved.size,
            "artifacts" to resolved.map { mapOf("coordinate" to it.id.displayName, "file" to it.file.name,
                                    "bytes" to it.file.length(), "sha256" to it.sha, "attributes" to it.attrs) },
            "edges" to edges.map { mapOf("from" to it.from.id.displayName, "requested" to it.requested.displayName,
                                    "selected" to it.selected.id.displayName,
                                    "attributes" to attributes(it.resolvedVariant.attributes)) }
                         .sortedBy { JsonOutput.toJson(it) }
        )
        file(providers.gradleProperty("probeReceipt").get()).writeText(JsonOutput.prettyPrint(JsonOutput.toJson(payload)) + "\n")
    }
}
