package com.tv.fifi

import android.app.AlertDialog
import android.content.*
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import com.google.android.gms.cast.MediaInfo
import com.google.android.gms.cast.MediaLoadRequestData
import com.google.android.gms.cast.MediaMetadata
import com.google.android.gms.cast.framework.CastContext
import com.google.android.gms.cast.framework.CastSession
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL_CAST = "com.tv.fifi/cast"
    private val CHANNEL_OVERLAY = "com.tv.fifi/overlay"
    private val CHANNEL_DATA = "main_activity_channel"
    private val REQUEST_CODE_OVERLAY = 1234
    private val REQUEST_IGNORE_BATTERY = 5678
    private var lastVideoPosition: Int = 0
    private var wasPlaying: Boolean = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestIgnoreBatteryOptimizations()
        maybeShowAutoStartDialog()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Canal para Chromecast (versión mejorada)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_CAST).setMethodCallHandler { call, result ->
            when (call.method) {
                "startCasting" -> {
                    val url = call.argument<String>("url") ?: ""
                    val title = call.argument<String>("title") ?: "Video"
                    castVideo(url, title)
                    result.success(null)
                }
                "castVideo" -> {
                    val url = call.argument<String>("url") ?: return@setMethodCallHandler
                    val castContext = CastContext.getSharedInstance(this)
                    val session = castContext.sessionManager.currentCastSession

                    if (session != null && session.isConnected) {
                        val metadata = MediaMetadata(MediaMetadata.MEDIA_TYPE_MOVIE)
                        metadata.putString(MediaMetadata.KEY_TITLE, "Streaming desde Flutter")

                        val mediaInfo = MediaInfo.Builder(url)
                            .setStreamType(MediaInfo.STREAM_TYPE_BUFFERED)
                            .setContentType("video/x-matroska") // para .mkv
                            .setMetadata(metadata)
                            .build()

                        val request = MediaLoadRequestData.Builder()
                            .setMediaInfo(mediaInfo)
                            .build()

                        session.remoteMediaClient?.load(request)
                        result.success("OK")
                    } else {
                        result.error("NO_SESSION", "No hay una sesión activa de Cast", null)
                    }
                }
                else -> result.notImplemented()
            }
        }


        // Canal para el overlay
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_OVERLAY).setMethodCallHandler { call, result ->
            when (call.method) {
                "showOverlay" -> {
                    val videoUrl = call.argument<String>("videoUrl")
                    val position = call.argument<Int>("position") ?: 0
                    val isPlaying = call.argument<Boolean>("isPlaying") ?: false

                    if (videoUrl != null) {
                        lastVideoPosition = position
                        wasPlaying = isPlaying
                        checkOverlayPermissionAndStartService(videoUrl, position, isPlaying)
                        result.success(null)
                    } else {
                        result.error("INVALID_URL", "La URL del video no es válida", null)
                    }
                }

                "closeOverlay" -> {
                    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "flutter/videoController")
                        .invokeMethod("resumeVideo", mapOf("position" to lastVideoPosition, "isPlaying" to wasPlaying))
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }


    private fun castVideo(url: String, title: String) {
        val castSession = CastContext.getSharedInstance(this).sessionManager.currentCastSession ?: return

        val metadata = MediaMetadata(MediaMetadata.MEDIA_TYPE_MOVIE)
        metadata.putString(MediaMetadata.KEY_TITLE, title)

        val mediaInfo = MediaInfo.Builder(url)
            .setStreamType(MediaInfo.STREAM_TYPE_BUFFERED)
            .setContentType("video/mp4") // o mkv si el receptor lo soporta
            .setMetadata(metadata)
            .build()

        val requestData = MediaLoadRequestData.Builder()
            .setMediaInfo(mediaInfo)
            .build()

        castSession.remoteMediaClient?.load(requestData)
    }

    private fun checkOverlayPermissionAndStartService(videoUrl: String, position: Int, isPlaying: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
            val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))
            startActivityForResult(intent, REQUEST_CODE_OVERLAY)
            Companion.lastVideoUrl = videoUrl
            Companion.lastVideoPosition = position
            Companion.wasPlaying = isPlaying
            return
        }
        startOverlayService(videoUrl, position, isPlaying)
    }

    private fun startOverlayService(videoUrl: String, position: Int, isPlaying: Boolean) {
        val intent = Intent(this, OverlayService::class.java).apply {
            putExtra("videoUrl", videoUrl)
            putExtra("position", position)
            putExtra("isPlaying", isPlaying)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CODE_OVERLAY) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && Settings.canDrawOverlays(this)) {
                startOverlayService(Companion.lastVideoUrl, Companion.lastVideoPosition, Companion.wasPlaying)
            }
        }
    }

    private fun requestIgnoreBatteryOptimizations() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val packageName = packageName
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:$packageName")
                }
                startActivity(intent)
            }
        }
    }

    private fun maybeShowAutoStartDialog() {
        val manufacturer = Build.MANUFACTURER.lowercase()

        when {
            manufacturer.contains("xiaomi") -> {
                showAutoStartDialog(
                    "Xiaomi",
                    ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity")
                )
            }

            manufacturer.contains("huawei") -> {
                showAutoStartDialog(
                    "Huawei",
                    ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity")
                )
            }

            manufacturer.contains("oppo") -> {
                showAutoStartDialog(
                    "Oppo",
                    ComponentName("com.coloros.safecenter", "com.coloros.safecenter.startupapp.StartupAppListActivity")
                )
            }

            manufacturer.contains("vivo") -> {
                showAutoStartDialog(
                    "Vivo",
                    ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity")
                )
            }

            manufacturer.contains("samsung") -> {
                AlertDialog.Builder(this)
                    .setTitle("Configuración de batería")
                    .setMessage("En Samsung, desactiva la optimización de batería para esta app para que funcione correctamente en segundo plano.")
                    .setPositiveButton("Abrir ajustes") { _, _ ->
                        val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                        startActivity(intent)
                    }
                    .setNegativeButton("Cancelar", null)
                    .show()
            }
        }
    }

    private fun showAutoStartDialog(brand: String, componentName: ComponentName) {
        AlertDialog.Builder(this)
            .setTitle("Permiso de inicio automático - $brand")
            .setMessage("Para que la app funcione correctamente, activa el inicio automático en tu dispositivo $brand.")
            .setPositiveButton("Ir ahora") { _, _ ->
                try {
                    val intent = Intent().apply {
                        component = componentName
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                } catch (e: Exception) {
                    e.printStackTrace()
                    Log.e("AutoStart", "No se pudo abrir el autostart de $brand")
                }
            }
            .setNegativeButton("Cancelar", null)
            .show()
    }

    companion object {
        @JvmStatic
        var lastVideoUrl: String = ""
            private set
        @JvmStatic
        var lastVideoPosition: Int = 0
            private set
        @JvmStatic
        var wasPlaying: Boolean = false
            private set
    }
}