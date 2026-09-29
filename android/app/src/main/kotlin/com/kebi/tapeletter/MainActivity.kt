package com.kebi.tapeletter

import android.content.Context
import android.media.AudioAttributes
import android.media.SoundPool
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var uiSound: UiSound? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        uiSound = UiSound(applicationContext).also { sound ->
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tapeletter/ui_sound")
                .setMethodCallHandler { call, result ->
                    when (call.method) {
                        "preload" -> {
                            @Suppress("UNCHECKED_CAST")
                            sound.preload(call.arguments as? Map<String, String> ?: emptyMap())
                            result.success(null)
                        }
                        "play" -> {
                            (call.arguments as? String)?.let(sound::play)
                            result.success(null)
                        }
                        "stop" -> {
                            (call.arguments as? String)?.let(sound::stop)
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        uiSound?.release()
        uiSound = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}

/// UI 효과음 (`tapeletter/ui_sound`) — SoundPool, USAGE_ASSISTANCE_SONIFICATION.
/// 오디오 포커스를 요청하지 않아 녹음·재생을 끊거나 줄이지 않는다. 무음·진동 모드면 시스템 볼륨을 따른다.
class UiSound(private val context: Context) {
    private val pool = SoundPool.Builder()
        .setMaxStreams(2)
        .setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
        )
        .build()
    private val ids = mutableMapOf<String, Int>()
    private val streams = mutableMapOf<String, Int>()

    fun preload(assets: Map<String, String>) {
        val loader = FlutterInjector.instance().flutterLoader()
        for ((name, asset) in assets) {
            if (ids.containsKey(name)) continue
            try {
                context.assets.openFd(loader.getLookupKeyForAsset(asset)).use { fd ->
                    ids[name] = pool.load(fd, 1)
                }
            } catch (_: Exception) {
            }
        }
    }

    fun play(name: String) {
        val id = ids[name] ?: return
        streams[name] = pool.play(id, 1f, 1f, 1, 0, 1f)
    }

    fun stop(name: String) {
        streams.remove(name)?.let(pool::stop)
    }

    fun release() = pool.release()
}
