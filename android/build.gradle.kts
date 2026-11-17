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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// file_picker >= 11 skips the Kotlin Gradle plugin on AGP 9+ (it expects
// built-in Kotlin), but this project keeps android.builtInKotlin=false for
// other plugins. Apply KGP to it explicitly so its Kotlin sources compile.
subprojects {
    if (name == "file_picker") {
        pluginManager.withPlugin("com.android.library") {
            pluginManager.apply("org.jetbrains.kotlin.android")
            tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
                compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            }
        }
    }
}
