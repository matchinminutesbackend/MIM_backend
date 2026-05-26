buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.2")
    }
}

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

subprojects {
    val configureNamespace = { proj: Project ->
        if (proj.plugins.hasPlugin("com.android.library")) {
            val android = proj.extensions.findByName("android")
            if (android != null) {
                // 1. Force compileSdk to 34 (only if it is less than 34) to resolve lStar attribute error
                try {
                    val getCompileSdk = android.javaClass.getMethod("getCompileSdk")
                    val currentCompileSdk = getCompileSdk.invoke(android)
                    if (currentCompileSdk is Number) {
                        val sdkInt = currentCompileSdk.toInt()
                        if (sdkInt < 34) {
                            val setCompileSdk = android.javaClass.getMethod("setCompileSdk", java.lang.Integer::class.java)
                            setCompileSdk.invoke(android, 34)
                            logger.quiet("Forced compileSdk to 34 (was $sdkInt) for library project ${proj.name}")
                        } else {
                            logger.quiet("Keeping compileSdk $sdkInt for library project ${proj.name}")
                        }
                    } else if (currentCompileSdk != null) {
                        logger.quiet("Keeping non-numeric compileSdk $currentCompileSdk for library project ${proj.name}")
                    } else {
                        val setCompileSdk = android.javaClass.getMethod("setCompileSdk", java.lang.Integer::class.java)
                        setCompileSdk.invoke(android, 34)
                        logger.quiet("Forced compileSdk to 34 (was null) for library project ${proj.name}")
                    }
                } catch (e: Exception) {
                    try {
                        val setCompileSdkVersion = android.javaClass.getMethod("setCompileSdkVersion", Int::class.javaPrimitiveType)
                        setCompileSdkVersion.invoke(android, 34)
                        logger.quiet("Forced compileSdkVersion to 34 for library project ${proj.name}")
                    } catch (e2: Exception) {
                        logger.quiet("Failed to force compileSdk for library project ${proj.name}: ${e2.message}")
                    }
                }

                // 2. Set namespace if missing
                try {
                    val getNamespace = android.javaClass.getMethod("getNamespace")
                    val namespace = getNamespace.invoke(android)
                    if (namespace == null) {
                        var packageName: String? = null
                        val manifestFile = proj.file("src/main/AndroidManifest.xml")
                        if (manifestFile.exists()) {
                            val manifestText = manifestFile.readText()
                            val match = Regex("""package="([^"]+)"""").find(manifestText)
                            if (match != null) {
                                packageName = match.groupValues[1]
                            }
                        }
                        if (packageName == null) {
                            packageName = "co.app.${proj.name.replace("-", "_").replace(".", "_")}"
                        }
                        val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                        setNamespace.invoke(android, packageName)
                        logger.quiet("Dynamically set namespace to $packageName for library project ${proj.name}")
                    }
                } catch (e: Exception) {
                    logger.quiet("Failed to dynamically set namespace for library project ${proj.name}: ${e.message}")
                }
            }
        }
    }

    if (project.state.executed) {
        configureNamespace(project)
    } else {
        project.afterEvaluate {
            configureNamespace(this)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

