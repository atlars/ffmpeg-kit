import java.io.File
import java.math.BigInteger
import java.security.MessageDigest
import java.text.SimpleDateFormat
import java.util.Date

group = "com.arthenica.ffmpegkit.flutter"
version = "6.0.3"

buildscript {
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:9.1.0")
    }
}

val localMavenPath: String = project.mkdir("build").absolutePath

rootProject.allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("file://$localMavenPath") }
    }
}

plugins {
    id("com.android.library")
}

android {
    namespace = "com.arthenica.ffmpegkit.flutter"

    compileSdk = 35

    defaultConfig {
        minSdk = 24
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = false
        }
    }

    lint {
        disable += "GradleCompatible"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    implementation("androidx.annotation:annotation:1.5.0")
    implementation("com.arthenica:smart-exception-java:0.2.1")
}

fun digest(file: File, algorithm: String, length: Int): String {
    val messageDigest = MessageDigest.getInstance(algorithm)
    file.inputStream().use { input ->
        val buffer = ByteArray(1024 * 1024 * 10)
        while (true) {
            val len = input.read(buffer)
            if (len <= 0) break
            messageDigest.update(buffer, 0, len)
        }
    }
    return BigInteger(1, messageDigest.digest()).toString(16).padStart(length, '0')
}

fun getFileSha1(file: File): String = digest(file, "SHA-1", 40)

fun getFileMD5(file: File): String = digest(file, "MD5", 32)

fun createMetadataStr(groupId: String, artifactId: String, version: String): String {
    val lastUpdated = SimpleDateFormat("yyyyMMdd").format(Date())
    return """<?xml version="1.0" encoding="UTF-8"?>
<metadata>
  <groupId>$groupId</groupId>
  <artifactId>$artifactId</artifactId>
  <versioning>
    <release>$version</release>
    <versions>
      <version>$version</version>
    </versions>
    <lastUpdated>${lastUpdated}000000</lastUpdated>
  </versioning>
</metadata>
"""
}

fun createPomStr(groupId: String, artifactId: String, version: String): String =
    """<?xml version="1.0" encoding="UTF-8"?>
<project xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd" xmlns="http://maven.apache.org/POM/4.0.0"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <modelVersion>4.0.0</modelVersion>
  <groupId>$groupId</groupId>
  <artifactId>$artifactId</artifactId>
  <version>$version</version>
  <packaging>aar</packaging>
</project>
"""

// Publishes the bundled .aar files from libs/ into a local maven repository, because AGP does not
// support direct local .aar dependencies in library modules.
// https://itnext.io/working-with-local-aar-files-in-flutter-6028bb289124
val aarFiles = project.file("libs").listFiles { file -> file.name.endsWith(".aar") }.orEmpty()
aarFiles.forEach { item ->
    val aarName = item.name.removeSuffix(".aar")
    val aarInfo = aarName.split("-")
    println("aar: $aarInfo file sha1:${getFileSha1(item)} md5:${getFileMD5(item)}")

    val intoStr = "$localMavenPath/${aarInfo[0].replace(".", "/")}/${aarInfo[1]}/${aarInfo[2]}"
    val newName = "${aarInfo[1]}-${aarInfo[2]}.aar"

    val target = project.file("$intoStr/$newName")
    target.parentFile.mkdirs()
    item.copyTo(target, overwrite = true)
    project.file("$intoStr/$newName.md5").writeText(getFileMD5(target))
    project.file("$intoStr/$newName.sha1").writeText(getFileSha1(target))

    val pomFile = project.file("$intoStr/${newName.removeSuffix(".aar")}.pom")
    pomFile.writeText(createPomStr(aarInfo[0], aarInfo[1], aarInfo[2]))
    project.file("${pomFile.path}.md5").writeText(getFileMD5(pomFile))
    project.file("${pomFile.path}.sha1").writeText(getFileSha1(pomFile))

    val metadataFile = File(project.file(intoStr).parentFile, "maven-metadata.xml")
    metadataFile.writeText(createMetadataStr(aarInfo[0], aarInfo[1], aarInfo[2]))
    project.file("${metadataFile.path}.md5").writeText(getFileMD5(metadataFile))
    project.file("${metadataFile.path}.sha1").writeText(getFileSha1(metadataFile))

    dependencies {
        add("implementation", "${aarInfo[0]}:${aarInfo[1]}:${aarInfo[2]}")
    }
}
