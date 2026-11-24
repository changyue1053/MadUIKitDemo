import org.gradle.api.artifacts.component.ModuleComponentIdentifier
import org.gradle.api.artifacts.component.ModuleComponentSelector
import org.gradle.api.artifacts.component.ProjectComponentIdentifier
import org.gradle.api.artifacts.result.ResolvedDependencyResult
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    kotlin("multiplatform") version "2.2.21"
    id("org.jetbrains.kotlin.plugin.compose") version "2.2.21"
    id("com.android.library") version "8.11.1"
}
val exactVersion = "0.1.0-alpha08-sdk-preview01"
val sdkGroup = "com.mad.maduikit"
kotlin {
    androidTarget { compilerOptions { jvmTarget.set(JvmTarget.JVM_17) } }
    jvmToolchain(17)
    sourceSets.commonMain.dependencies {
        implementation("$sdkGroup:maduikit-components:$exactVersion")
    }
}
android {
    namespace = "dev.mad.synthetic.sourceonly"
    compileSdk = 36
    defaultConfig { minSdk = 23 }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}
tasks.register("verifySourceComposite") {
    doLast {
        val direct = configurations.getByName("commonMainImplementation").dependencies
            .filter { it.group == sdkGroup }
        check(direct.size == 1 && direct.single().name == "maduikit-components" && direct.single().version == exactVersion)
        val config = configurations.getByName("debugCompileClasspath")
        val graph = config.incoming.resolutionResult
        val directMatches = graph.root.dependencies.filterIsInstance<ResolvedDependencyResult>().filter {
            val request = it.requested as? ModuleComponentSelector
            request?.group == sdkGroup && request.module == "maduikit-components" && request.version == exactVersion
        }
        val selectedComponents = directMatches.map { it.selected.id }.toSet()
        check(selectedComponents.size == 1)
        val component = selectedComponents.single() as? ProjectComponentIdentifier
        check(component?.projectPath == ":maduikit-components" && component.build.buildPath == ":madUIKitExactAlpha08")
        val theme = graph.allDependencies.filterIsInstance<ResolvedDependencyResult>().any {
            val selected = it.selected.id as? ProjectComponentIdentifier
            it.from.id == component && selected?.projectPath == ":maduikit-theme" && selected.build == requireNotNull(component).build
        }
        check(theme)
        check(graph.allComponents.none { (it.id as? ModuleComponentIdentifier)?.group == sdkGroup })
        println("SOURCE_COMPOSITE_ROOTS_VERIFIED")
    }
}
