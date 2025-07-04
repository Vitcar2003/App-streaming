package com.tv.fifi

import android.app.*
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.view.*
import android.widget.ImageView
import android.widget.VideoView
import androidx.core.app.NotificationCompat

class OverlayService : Service() {
    private lateinit var windowManager: WindowManager
    private lateinit var overlayView: View
    private lateinit var videoView: VideoView
    private lateinit var playPauseIcon: ImageView
    private lateinit var closeIcon: ImageView
    private var isPlaying = true
    private var lastPosition = 0
    private val handler = Handler(Looper.getMainLooper())

    // Define constants for notification
    private val NOTIFICATION_ID = 101

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()

        try {
            // Inicializa WindowManager y la vista flotante
            windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
            overlayView = LayoutInflater.from(this).inflate(R.layout.overlay_layout, null)

            videoView = overlayView.findViewById(R.id.videoView)
            playPauseIcon = overlayView.findViewById(R.id.playPauseIcon)
            closeIcon = overlayView.findViewById(R.id.closeIcon)

            closeIcon.setOnClickListener { closeOverlay() }
            playPauseIcon.setOnClickListener { togglePlayPause() }

            hideControls()

            // Configuración de los parámetros de la ventana flotante
            val layoutParams = WindowManager.LayoutParams(
                700, 400,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                else WindowManager.LayoutParams.TYPE_PHONE,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                PixelFormat.TRANSLUCENT
            )
            layoutParams.gravity = Gravity.TOP or Gravity.START
            layoutParams.x = 0
            layoutParams.y = 100

            // Agregar la vista al WindowManager con manejo de excepciones
            try {
                windowManager.addView(overlayView, layoutParams)
            } catch (e: Exception) {
                e.printStackTrace()
                stopSelf()  // Evita que la app crashee
                return
            }

            // Configurar el arrastre de la ventana flotante
            overlayView.setOnTouchListener(object : View.OnTouchListener {
                private var initialX = 0
                private var initialY = 0
                private var initialTouchX = 0f
                private var initialTouchY = 0f

                override fun onTouch(v: View?, event: MotionEvent?): Boolean {
                    if (event == null) return false
                    when (event.action) {
                        MotionEvent.ACTION_DOWN -> {
                            initialX = layoutParams.x
                            initialY = layoutParams.y
                            initialTouchX = event.rawX
                            initialTouchY = event.rawY
                            showControls()
                            return true
                        }
                        MotionEvent.ACTION_MOVE -> {
                            layoutParams.x = initialX + (event.rawX - initialTouchX).toInt()
                            layoutParams.y = initialY + (event.rawY - initialTouchY).toInt()
                            windowManager.updateViewLayout(overlayView, layoutParams)
                            return true
                        }
                    }
                    return false
                }
            })

        } catch (e: Exception) {
            e.printStackTrace()
            stopSelf()
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val videoUrl = intent?.getStringExtra("videoUrl")
        lastPosition = intent?.getIntExtra("position", 0) ?: 0
        isPlaying = intent?.getBooleanExtra("isPlaying", true) ?: true

        // Iniciar el servicio en primer plano para evitar cierres en Android 10+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForeground(1, createNotification())
        }

        if (videoUrl != null) {
            videoView.setVideoURI(Uri.parse(videoUrl))
            videoView.seekTo(lastPosition)
            videoView.setOnPreparedListener { mediaPlayer ->
                mediaPlayer.setOnSeekCompleteListener { }
                if (isPlaying) videoView.start()
            }
            updatePlayPauseIcon()
        }

        // Crear la notificación
        val notification = createNotification()

        // Iniciar el servicio en primer plano
        startForeground(NOTIFICATION_ID, notification)

        return START_NOT_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        if (::overlayView.isInitialized) {
            try {
                windowManager.removeView(overlayView)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
        handler.removeCallbacksAndMessages(null)
    }

    private fun closeOverlay() {
        val intent = Intent("com.tv.fifi.CLOSE_OVERLAY").apply {
            putExtra("position", videoView.currentPosition)
            putExtra("isPlaying", videoView.isPlaying)
        }
        sendBroadcast(intent)
        stopSelf()
    }

    private fun togglePlayPause() {
        if (videoView.isPlaying) {
            videoView.pause()
            isPlaying = false
        } else {
            videoView.start()
            isPlaying = true
        }
        updatePlayPauseIcon()
    }

    private fun updatePlayPauseIcon() {
        playPauseIcon.setImageResource(
            if (isPlaying) android.R.drawable.ic_media_pause
            else android.R.drawable.ic_media_play
        )
    }

    private fun showControls() {
        closeIcon.visibility = View.VISIBLE
        playPauseIcon.visibility = View.VISIBLE
        handler.postDelayed({ hideControls() }, 3000L)
    }

    private fun hideControls() {
        closeIcon.visibility = View.GONE
        playPauseIcon.visibility = View.GONE
    }

    private fun createNotification(): Notification {
        val channelId = "overlay_service_channel"
        val notificationManager =
            getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(channelId, "Overlay Service", NotificationManager.IMPORTANCE_LOW)
            notificationManager.createNotificationChannel(channel)
        }
        return NotificationCompat.Builder(this, channelId)
            .setContentTitle("Overlay Service")
            .setContentText("El servicio de superposición está activo")
            .setSmallIcon(android.R.drawable.ic_dialog_info)  // Reemplaza con tu ícono
            .build()
    }
}
