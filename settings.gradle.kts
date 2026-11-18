pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        exclusiveContent {
            forRepository {
                maven {
                    name = "madUIKitLocal"
                    url = file(providers.gradleProperty("maduikitStagingDir").getOrElse("../maduikit-maven")).toURI()
                }
            }
            filter { includeGroup("com.mad.maduikit") }
        }
        google()
        mavenCentral()
    }
}

rootProject.name = "MadUIKitDemo"
include(":composeApp")
