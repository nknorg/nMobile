buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.12.3")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.2.21")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    afterEvaluate {
        if (hasProperty("android")) {
            extensions.findByType(com.android.build.gradle.BaseExtension::class.java)?.let { android ->
                if (android.namespace == null) {
                    val manifestFile = android.sourceSets.findByName("main")?.manifest?.srcFile
                    if (manifestFile != null && manifestFile.exists()) {
                        try {
                            val packageName = groovy.util.XmlSlurper().parse(manifestFile).getProperty("@package").toString()
                            if (packageName.isNotEmpty()) {
                                println("Setting $packageName as android namespace")
                                android.namespace = packageName
                            }
                        } catch (e: Exception) {
                            println("Error parsing manifest: ${e.message}")
                        }
                    }
                }
                
                val javaVersion = JavaVersion.VERSION_21
                val androidApiVersion = 36
                
                android.compileSdkVersion(androidApiVersion)
                android.defaultConfig.targetSdk = androidApiVersion
                
                android.compileOptions.sourceCompatibility = javaVersion
                android.compileOptions.targetCompatibility = javaVersion
                
                tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile::class.java).configureEach {
                    compilerOptions {
                        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_21)
                        languageVersion.set(org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_2_2)
                        apiVersion.set(org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_2_2)
                    }
                }
                
                println("Setting [${project.name}] java version to ${javaVersion.toString()} which is $javaVersion")
                println("Setting compileSdkVersion and targetSdkVersion to $androidApiVersion")
            }
        }
    }
}

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
