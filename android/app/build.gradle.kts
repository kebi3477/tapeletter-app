import java.io.FileInputStream
import java.net.URI
import java.util.Properties
import java.util.Base64

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val appId = "com.kebi.tapeletter"

// Firebase 설정 파일은 커밋하지 않는다(.gitignore). 있고, 이 앱(appId)으로 받은 파일일 때만
// Google Services 플러그인을 적용한다. 다른 번들 ID의 파일이면 건너뛴다(앱은 가짜 푸시). docs/SETUP.md 참고
val googleServices = file("google-services.json")
if (googleServices.exists()) {
    val forThisApp =
        Regex(""""package_name"\s*:\s*"${Regex.escape(appId)}"""").containsMatchIn(googleServices.readText())
    if (forThisApp) {
        apply(plugin = "com.google.gms.google-services")
    } else {
        logger.warn("warning: google-services.json이 $appId 용이 아니라 건너뜀 - 푸시는 가짜(LocalPushService)로 동작")
    }
}

// 출시 서명: android/key.properties(커밋 안 함, 원본은 ~/private_keys/tapeletter/). 없으면 debug 키로 서명한다.
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) load(FileInputStream(f))
}

// `flutter run --dart-define=KEY=VALUE` 값을 매니페스트에 넘긴다 (카카오 키, 링크 도메인).
val dartDefines: Map<String, String> = run {
    val out = mutableMapOf<String, String>()
    val raw = project.findProperty("dart-defines") as String?
    raw?.split(",")?.forEach { encoded: String ->
        val decoded = Base64.getDecoder().decode(encoded).toString(Charsets.UTF_8)
        val i = decoded.indexOf('=')
        if (i > 0) out[decoded.substring(0, i)] = decoded.substring(i + 1)
    }
    out
}

// debug·profile 빌드에서만 http 개발 서버에 붙을 수 있게 하는 network_security_config.
// 허용: localhost, 127.0.0.1, 10.0.2.2(에뮬레이터), 그리고 API_BASE_URL의 호스트가 사설 IP면 그 주소.
// Android는 IP 대역(CIDR)을 쓸 수 없어서 dart-define의 맥 IP를 빌드할 때 넣는다. release에는 넣지 않는다.
val devApiHost: String? = dartDefines["API_BASE_URL"]?.let { url: String ->
    try {
        URI(url).host
    } catch (e: Exception) {
        null
    }
}
val privateIp = Regex("""^(10\.\d+|192\.168|172\.(1[6-9]|2\d|3[01]))\.\d+\.\d+$""")
val devCleartextHosts =
    (listOf("localhost", "127.0.0.1", "10.0.2.2") +
        listOfNotNull(devApiHost?.takeIf { privateIp.matches(it) })).distinct()
val devNetworkRes = layout.buildDirectory.dir("generated/devNetworkSecurity/res").get().asFile
File(devNetworkRes, "xml/network_security_config.xml").apply {
    parentFile.mkdirs()
    writeText(
        buildString {
            appendLine("<?xml version=\"1.0\" encoding=\"utf-8\"?>")
            appendLine("<!-- 빌드가 만든 파일 (android/app/build.gradle.kts). debug·profile 전용 -->")
            appendLine("<network-security-config>")
            appendLine("    <domain-config cleartextTrafficPermitted=\"true\">")
            devCleartextHosts.forEach {
                appendLine("        <domain includeSubdomains=\"false\">$it</domain>")
            }
            appendLine("    </domain-config>")
            appendLine("</network-security-config>")
        },
    )
}

android {
    namespace = appId
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = appId
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["kakaoNativeAppKey"] = dartDefines["KAKAO_NATIVE_APP_KEY"] ?: "b53a18d3cc2caf80784d6ffd8bddb7c4" // env.dart·Env.xcconfig와 같은 기본값
        manifestPlaceholders["publicHost"] = dartDefines["PUBLIC_HOST"] ?: "tapeletter.lab241.com"
    }

    sourceSets {
        getByName("debug").res.srcDir(devNetworkRes)
        getByName("profile").res.srcDir(devNetworkRes)
    }

    signingConfigs {
        if (keystoreProperties.isNotEmpty()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                if (keystoreProperties.isNotEmpty()) signingConfigs.getByName("release")
                else signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
