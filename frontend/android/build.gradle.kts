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

// file_picker 8.x still declares compileSdk 34, which flutter_plugin_android_lifecycle 2.0.35
// rejects ("requires ... version 36 or later"). Compile every plugin against the app's SDK.
subprojects {
    if (name == "app") return@subprojects // already evaluated above; it uses flutter.compileSdkVersion
    afterEvaluate {
        extensions.findByType(com.android.build.api.dsl.CommonExtension::class.java)?.let { android ->
            val current = android.compileSdk
            if (current == null || current < 36) android.compileSdk = 36
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
