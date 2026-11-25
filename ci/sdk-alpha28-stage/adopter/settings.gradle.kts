pluginManagement { repositories { google(); mavenCentral(); gradlePluginPortal() } }
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        exclusiveContent {
            forRepository {
                maven { url = uri(providers.gradleProperty("madStage").get())
                    metadataSources { gradleMetadata(); mavenPom() } }
            }
            filter { includeGroup("com.mad.maduikit") }
        }
        google(); mavenCentral()
    }
}
rootProject.name = "MadTypographyStandaloneAdopter"
include(":composeApp")
