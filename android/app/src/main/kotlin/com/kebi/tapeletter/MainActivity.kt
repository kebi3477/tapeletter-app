package com.kebi.tapeletter

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioAttributes
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.media.SoundPool
import android.os.Build
import androidx.core.content.ContextCompat
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

/// UI 효과음 (`tapeletter/ui_sound`) — SoundPool. 오디오 포커스를 요청하지 않아 녹음·재생을 끊거나 줄이지 않는다.
///
/// - 평소: USAGE_ASSISTANCE_SONIFICATION — 무음·진동 모드면 시스템 설정을 따라 울리지 않는다.
/// - 벨소리 모드가 무음·진동이면서 이어폰(유선·USB·블루투스)이 연결돼 있으면: USAGE_MEDIA 풀로
///   미디어 음량에 맞춰 이어폰으로 울린다. 연결은 울릴 때마다 본다.
/// - 이어폰을 빼면(ACTION_AUDIO_BECOMING_NOISY) 미디어로 울리던 효과음을 바로 멈춘다(스피커로 새지 않게).
class UiSound(private val context: Context) {
    private fun pool(usage: Int) = SoundPool.Builder()
        .setMaxStreams(2)
        .setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(usage)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
        )
        .build()

    private val system = pool(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
    private val media = pool(AudioAttributes.USAGE_MEDIA)
    private val audio = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val ids = mutableMapOf<String, Int>()
    private val mediaIds = mutableMapOf<String, Int>()
    private val streams = mutableMapOf<String, Int>()
    private val mediaStreams = mutableMapOf<String, Int>()

    private val noisy = object : BroadcastReceiver() {
        override fun onReceive(c: Context, intent: Intent) {
            if (intent.action == AudioManager.ACTION_AUDIO_BECOMING_NOISY) {
                mediaStreams.values.forEach(media::stop)
                mediaStreams.clear()
            }
        }
    }

    init {
        ContextCompat.registerReceiver(
            context,
            noisy,
            IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY),
            ContextCompat.RECEIVER_NOT_EXPORTED,
        )
    }

    fun preload(assets: Map<String, String>) {
        val loader = FlutterInjector.instance().flutterLoader()
        for ((name, asset) in assets) {
            if (ids.containsKey(name)) continue
            try {
                val key = loader.getLookupKeyForAsset(asset)
                context.assets.openFd(key).use { fd -> ids[name] = system.load(fd, 1) }
                context.assets.openFd(key).use { fd -> mediaIds[name] = media.load(fd, 1) }
            } catch (_: Exception) {
            }
        }
    }

    fun play(name: String) {
        if (silenced() && headphonesConnected()) {
            val id = mediaIds[name] ?: return
            mediaStreams[name] = media.play(id, 1f, 1f, 1, 0, 1f)
        } else {
            val id = ids[name] ?: return
            streams[name] = system.play(id, 1f, 1f, 1, 0, 1f)
        }
    }

    fun stop(name: String) {
        streams.remove(name)?.let(system::stop)
        mediaStreams.remove(name)?.let(media::stop)
    }

    /// 벨소리 모드가 무음·진동
    private fun silenced() = audio.ringerMode != AudioManager.RINGER_MODE_NORMAL

    /// 이어폰(유선·USB·블루투스·보청기)으로 소리가 나갈 수 있는지
    private fun headphonesConnected(): Boolean {
        val ear = mutableSetOf(
            AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
            AudioDeviceInfo.TYPE_WIRED_HEADSET,
            AudioDeviceInfo.TYPE_USB_HEADSET,
            AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
            AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
            AudioDeviceInfo.TYPE_HEARING_AID,
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ear += AudioDeviceInfo.TYPE_BLE_HEADSET
        }
        return audio.getDevices(AudioManager.GET_DEVICES_OUTPUTS).any { it.type in ear }
    }

    fun release() {
        try {
            context.unregisterReceiver(noisy)
        } catch (_: Exception) {
        }
        system.release()
        media.release()
    }
}
