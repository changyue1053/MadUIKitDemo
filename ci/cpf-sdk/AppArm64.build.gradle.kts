// Isolated ARM64-only diagnostic host. Not the production SDK build.
plugins {
    alias(libs.plugins.kotlinMultiplatform)
    alias(libs.plugins.composeMultiplatform)
    alias(libs.plugins.composeCompiler)
}
kotlin {
    ohosArm64 {
        binaries.sharedLib {
            baseName = "kn"
            export(libs.compose.multiplatform.export)
            linkerOpts("-lz")
        }
        compilations.getByName("main") {
            val resource by cinterops.creating {
                defFile(file("src/ohosMain/cinterop/resource.def"))
                includeDirs(file("src/ohosMain/cinterop/include"))
            }
        }
    }
    sourceSets {
        commonMain.dependencies {
            implementation(project(":maduikit-components"))
            implementation(compose.runtime)
            implementation(compose.foundation)
            implementation(compose.material)
            implementation(compose.material3)
            implementation(compose.ui)
            implementation(compose.components.resources)
            implementation(compose.components.uiToolingPreview)
            implementation(libs.kotlinx.coroutines.core)
            implementation(libs.atomicFu)
        }
        val ohosMain by creating {
            dependsOn(commonMain.get())
            dependencies { api(libs.compose.multiplatform.export) }
        }
        val ohosArm64Main by getting { dependsOn(ohosMain) }
    }
}
