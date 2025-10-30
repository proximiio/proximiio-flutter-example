allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://maven.proximi.io/repository/android-releases/") }
        maven { url = uri("https://dl.cloudsmith.io/public/indooratlas/mvn-public/maven/") }
        maven { url = uri("https://api.mapbox.com/downloads/v2/releases/maven") }
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
