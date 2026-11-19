import org.gradle.api.artifacts.component.ModuleComponentIdentifier
import org.gradle.api.artifacts.result.ResolvedDependencyResult
import java.security.MessageDigest
plugins { kotlin("multiplatform"); id("org.jetbrains.kotlin.plugin.compose"); id("org.jetbrains.compose") }
kotlin {
 iosX64 { binaries.framework { baseName="MadUIKitDemoShared"; isStatic=true } }
 sourceSets.commonMain.dependencies { implementation(compose.material3); implementation("com.mad.maduikit:maduikit-components:0.1.0-alpha01") }
}
val verifyAdoption by tasks.registering {
 doLast {
  val c=configurations.getByName("iosX64CompileKlibraries")
  val a=c.incoming.artifacts.artifacts.filter { (it.id.componentIdentifier as? ModuleComponentIdentifier)?.group=="com.mad.maduikit" }
  check(a.size==2 && a.map { (it.id.componentIdentifier as ModuleComponentIdentifier).module }.toSet()==setOf("maduikit-components-iosx64","maduikit-theme-iosx64"))
  val lines=mutableListOf<String>(); val stage=file(providers.gradleProperty("madStage").get())
  for (artifact in a) {
   val id=artifact.id.componentIdentifier as ModuleComponentIdentifier
   check(id.version=="0.1.0-alpha01" && artifact.file.extension=="klib")
   val file=stage.resolve("com/mad/maduikit/${id.module}/${id.version}/${id.module}-${id.version}.klib")
   fun hash(f:File)=MessageDigest.getInstance("SHA-256").digest(f.readBytes()).joinToString("") { "%02x".format(it) }
   check(file.isFile && hash(file)==hash(artifact.file))
   check(artifact.variant.attributes.keySet().any { it.name=="org.jetbrains.kotlin.native.target" && artifact.variant.attributes.getAttribute(it).toString()=="ios_x64" })
   lines+="Resolved $id sha256=${hash(file)} variant=${artifact.variant.attributes}"
  }
  val edges=c.incoming.resolutionResult.allDependencies.filterIsInstance<ResolvedDependencyResult>().filter { (it.from.id as? ModuleComponentIdentifier)?.group=="com.mad.maduikit" }.map { "${it.from.id} -> ${it.selected.id}" }
  check(edges.any { it.contains("maduikit-components-iosx64") && it.contains("maduikit-theme") })
  val out=layout.buildDirectory.file("reports/sdk-adoption.txt").get().asFile;out.parentFile.mkdirs();out.writeText((lines+edges).joinToString("\n"));println(out.readText())
 }
}
tasks.matching { it.name.startsWith("compileKotlin") }.configureEach { dependsOn(verifyAdoption) }

val verifyGeneratedBinding by tasks.registering(Exec::class) {
 commandLine("python3", rootProject.file("scripts/verify-generated.py"), providers.gradleProperty("madCodegen").get())
}
tasks.matching { it.name.startsWith("compileKotlin") }.configureEach { dependsOn(verifyGeneratedBinding) }
