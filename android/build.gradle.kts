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

subprojects {
    // Definimos la logica del arreglo en una funcion interna
    fun fixNamespace(proj: Project) {
        val android = proj.extensions.findByName("android")
        if (android != null) {
            // Intentamos obtener la extension de Android de forma segura
            val extension = android as? com.android.build.gradle.BaseExtension
            // Si existe la extension pero no tiene namespace, se lo ponemos
            if (extension != null && extension.namespace == null) {
                extension.namespace = proj.group.toString()
            }
        }
    }

    // Revisamos si el proyecto ya termino de configurarse
    if (state.executed) {
        // Si ya termino, aplicamos el fix inmediatamente
        fixNamespace(this)
    } else {
        // Si no ha terminado, esperamos a que termine
        afterEvaluate {
            fixNamespace(this)
        }
    }
}


