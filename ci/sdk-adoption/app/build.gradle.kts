import org.gradle.api.artifacts.component.ModuleComponentIdentifier
import org.gradle.api.artifacts.result.ResolvedDependencyResult
import java.security.MessageDigest
plugins {
 id("com.android.application")
 id("org.jetbrains.kotlin.android")
 id("org.jetbrains.kotlin.plugin.compose")
}
android {
 namespace = "dev.mad.adoption"
 compileSdk = 36
 defaultConfig { applicationId = "dev.mad.adoption"; minSdk = 23; targetSdk = 36; versionCode = 1; versionName = "0.1" }
 buildFeatures { compose = true }
 compileOptions { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17 }
}
kotlin { jvmToolchain(17) }
dependencies {
 implementation("com.mad.maduikit:maduikit-components:0.1.0-alpha01")
 implementation("androidx.activity:activity-compose:1.10.1")
}
tasks.register("verifySdkAdoption") {
 doLast {
  val config = configurations.getByName("debugRuntimeClasspath")
  val direct = config.allDependencies.filter { it.group == "com.mad.maduikit" }.map { it.name }
  check(direct == listOf("maduikit-components")) { "Only components may be declared directly: $direct" }
  val sdk = config.incoming.artifacts.artifacts.filter { (it.id.componentIdentifier as? ModuleComponentIdentifier)?.group == "com.mad.maduikit" }
  check(sdk.map { (it.id.componentIdentifier as ModuleComponentIdentifier).module }.toSet() == setOf("maduikit-components-android", "maduikit-theme-android"))
  check(sdk.size == 2)
  val stage = file(providers.gradleProperty("madStage").get())
  val lines = mutableListOf<String>()
  for (a in sdk) {
   val id = a.id.componentIdentifier as ModuleComponentIdentifier
   check(id.version == "0.1.0-alpha01" && a.file.extension == "aar")
   val staged = stage.resolve("com/mad/maduikit/${id.module}/${id.version}/${id.module}-${id.version}.aar")
   fun hash(f: File) = MessageDigest.getInstance("SHA-256").digest(f.readBytes()).joinToString("") { "%02x".format(it) }
   check(staged.isFile && hash(staged) == hash(a.file))
   check(a.variant.attributes.keySet().any { k -> k.name == "org.jetbrains.kotlin.platform.type" && a.variant.attributes.getAttribute(k).toString() == "androidJvm" })
   lines += "Resolved external $id sha256=${hash(a.file)} attributes=${a.variant.attributes}"
  }
  val edges = config.incoming.resolutionResult.allDependencies.filterIsInstance<ResolvedDependencyResult>().filter { (it.from.id as? ModuleComponentIdentifier)?.group == "com.mad.maduikit" }.map { "${it.from.id} -> ${it.selected.id}" }
  check(edges.any { it.contains("maduikit-components-android") && it.contains("maduikit-theme") }) { "Missing transitive theme edge: $edges" }
  val report = layout.buildDirectory.file("reports/sdk-adoption.txt").get().asFile
  report.parentFile.mkdirs(); report.writeText((lines + edges).joinToString("\n"))
  println(report.readText())
 }
}
tasks.named("preBuild") { dependsOn("verifySdkAdoption") }
