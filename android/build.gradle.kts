allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// file_picker 11.0.2 applies the Kotlin Gradle Plugin only when AGP < 9 (see its
// `isAgp9OrAbove` check), assuming AGP 9's built-in Kotlin takes over — but the Flutter
// template sets `android.builtInKotlin=false` in gradle.properties, so nothing compiles
// the plugin's Kotlin. Its AAR ends up holding just R.class and the app fails with
// "cannot find symbol: FilePickerPlugin" in GeneratedPluginRegistrant.
//
// Flutter's Gradle plugin auto-applies KGP to plugin modules that lack it, but it decides
// by grepping the build file, and file_picker's still *mentions* KGP inside that dead
// branch — so it is skipped. Apply KGP here instead. Drop this once file_picker ships a
// build script that works with builtInKotlin=false, or once the app moves to built-in
// Kotlin. Keyed on Kotlin sources rather than on the name so other plugins with the same
// packaging are covered too.
subprojects {
    plugins.withId("com.android.library") {
        val hasKotlinSources = file("src/main/kotlin").isDirectory
        if (hasKotlinSources && !plugins.hasPlugin("org.jetbrains.kotlin.android")) {
            apply(plugin = "org.jetbrains.kotlin.android")
            extensions.configure<org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension> {
                compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
