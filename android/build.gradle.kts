import com.android.build.api.dsl.LibraryExtension
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile
import java.io.File

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

// Must be registered before evaluationDependsOn to avoid "already evaluated" error
subprojects {
    afterEvaluate {
        plugins.withType<com.android.build.gradle.LibraryPlugin> {
            extensions.configure<LibraryExtension> {
                compileSdk = 36
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    if (project.name != "app") {
        val manifestFile = project.projectDir.resolve("src/main/AndroidManifest.xml")
        if (manifestFile.exists()) {
            val content = manifestFile.readText()
            if (content.contains("""package="""")) {
                val filteredManifestDir = project.layout.buildDirectory
                    .get().asFile.resolve("generated/filtered_manifest")
                val filteredManifestFile = filteredManifestDir.resolve("AndroidManifest.xml")
                val filteredContent = content.replace(Regex("""\s+package="[^"]*""""), "")
                filteredManifestFile.parentFile.mkdirs()
                filteredManifestFile.writeText(filteredContent)
                project.extensions.add("nearme_filtered_manifest", filteredManifestFile)
            }
        }
        project.plugins.whenPluginAdded {
            if (this is com.android.build.gradle.LibraryPlugin) {
                project.extensions.configure<LibraryExtension> {
                    namespace = "com.example.near_me.${project.name.replace("-", "_")}"
                    val filtered = project.extensions.findByName("nearme_filtered_manifest") as? File
                    if (filtered != null) {
                        sourceSets {
                            getByName("main") {
                                manifest.srcFile(filtered)
                            }
                        }
                    }
                }
                project.apply(plugin = "org.jetbrains.kotlin.android")
            }
        }
    }
}

subprojects {
    tasks.withType<KotlinCompile> {
        compilerOptions {
            jvmTarget.set(JvmTarget.JVM_17)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
