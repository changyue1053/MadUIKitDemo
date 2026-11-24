pluginManagement { repositories { google(); mavenCentral(); gradlePluginPortal() } }
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories { google(); mavenCentral() }
}
// Scope: disposable developer fixture only, not a published-Maven verification.
val sdkCheckout = providers.gradleProperty("madSdkSource").get()
includeBuild(sdkCheckout) {
    name = "madUIKitExactAlpha10"
    dependencySubstitution {
        substitute(module("com.mad.maduikit:maduikit-components")).using(project(":maduikit-components"))
        substitute(module("com.mad.maduikit:maduikit-theme")).using(project(":maduikit-theme"))
    }
}
rootProject.name = "MadUIKitSourceCompositeSmoke"
include(":composeApp")
