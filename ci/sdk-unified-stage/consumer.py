"""Pin and minimally extend exact public Books to one KMP Android+iOS app."""
from pathlib import Path
import sys
root=Path(sys.argv[1]); app=root/'composeApp'; host=root/'build.gradle.kts'
def replace(path,old,new):
 s=path.read_text()
 if s.count(old)!=1:raise SystemExit(f'expected exact anchor: {path.name}')
 path.write_text(s.replace(old,new))
replace(host,' kotlin("multiplatform") version "2.2.21" apply false', ' kotlin("multiplatform") version "2.2.21" apply false\n id("com.android.application") version "8.11.1" apply false')
build=app/'build.gradle.kts'
replace(build,'id("org.jetbrains.compose") }','id("org.jetbrains.compose"); id("com.android.application") }')
replace(build,'kotlin {\n iosSimulatorArm64','''android {
 namespace = "dev.mad.adoption"
 compileSdk = 36
 defaultConfig { applicationId = "dev.mad.adoption.unified"; minSdk = 23; targetSdk = 36 }
 compileOptions {
  sourceCompatibility = JavaVersion.VERSION_17
  targetCompatibility = JavaVersion.VERSION_17
 }
}
kotlin {
 jvmToolchain(17)
 androidTarget { compilerOptions { jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17) } }
 sourceSets.commonMain.dependencies { implementation(compose.foundation) }
 sourceSets.androidMain.dependencies { implementation("androidx.activity:activity-compose:1.10.1") }
 iosSimulatorArm64''')
with build.open('a') as f:f.write('''
val verifyAndroidAdoption by tasks.registering {
 doLast {
  val c = configurations.getByName("debugRuntimeClasspath")
  val stage = file(providers.gradleProperty("madStage").get()).canonicalFile
  val artifacts = c.incoming.artifacts.artifacts.filter {
    (it.id.componentIdentifier as? ModuleComponentIdentifier)?.group == "com.mad.maduikit"
  }
  check(artifacts.size == 2 && artifacts.map { (it.id.componentIdentifier as ModuleComponentIdentifier).module }.toSet() ==
    setOf("maduikit-components-android", "maduikit-theme-android"))
  fun sha(f: File) = MessageDigest.getInstance("SHA-256").digest(f.readBytes()).joinToString("") { "%02x".format(it) }
  val lines = artifacts.map {
   val id = it.id.componentIdentifier as ModuleComponentIdentifier
   val original = stage.resolve("com/mad/maduikit/${id.module}/${id.version}/${id.module}-${id.version}.aar")
   check(id.version == "0.1.0-alpha01" && it.file.extension == "aar" && original.isFile && sha(it.file) == sha(original))
   check(it.variant.attributes.keySet().any { key -> key.name == "org.jetbrains.kotlin.platform.type" && it.variant.attributes.getAttribute(key).toString() == "androidJvm" })
   "$id sha256=${sha(original)}"
  }
  val edges = c.incoming.resolutionResult.allDependencies.filterIsInstance<ResolvedDependencyResult>()
  check(edges.any { (it.from.id as? ModuleComponentIdentifier)?.module == "maduikit-components-android" &&
    (it.selected.id as? ModuleComponentIdentifier)?.module == "maduikit-theme" })
  layout.buildDirectory.file("reports/sdk-adoption-android.txt").get().asFile.apply {
    parentFile.mkdirs(); writeText(lines.sorted().joinToString("\\n") + "\\n")
  }
 }
}
''')
ios=app/'src/iosMain/kotlin/dev/mad/adoption/DemoController.kt'
prefix='fun makeDemoViewController() = ComposeUIViewController '
src=ios.read_text()
if src.count(prefix)!=1 or not src.endswith('}\n'):raise SystemExit('unknown controller baseline')
src=src.replace('import androidx.compose.ui.window.ComposeUIViewController\n','').replace(prefix,'@androidx.compose.runtime.Composable\nfun BooksContent() ')
shared=app/'src/commonMain/kotlin/dev/mad/adoption/BooksContent.kt'
shared.parent.mkdir(parents=True);shared.write_text(src)
ios.write_text('package dev.mad.adoption\nimport androidx.compose.ui.window.ComposeUIViewController\nfun makeDemoViewController() = ComposeUIViewController { BooksContent() }\n')
adir=app/'src/androidMain'; target=adir/'kotlin/dev/mad/adoption/MainActivity.kt'
target.parent.mkdir(parents=True)
target.write_text('''package dev.mad.adoption
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
class MainActivity : ComponentActivity() {
 override fun onCreate(savedInstanceState: Bundle?) {
  super.onCreate(savedInstanceState)
  setContent { BooksContent() }
 }
}
''')
(adir/'AndroidManifest.xml').write_text('''<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <application android:label="MadUIKit Unified SDK">
    <activity android:name=".MainActivity" android:exported="true">
      <intent-filter>
        <action android:name="android.intent.action.MAIN"/>
        <category android:name="android.intent.category.LAUNCHER"/>
      </intent-filter>
    </activity>
  </application>
</manifest>
''')
