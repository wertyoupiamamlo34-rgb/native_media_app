package com.example.native_media_app

import android.content.Context
import android.view.TextureView
import android.view.View
import android.widget.FrameLayout
import androidx.media3.exoplayer.ExoPlayer
import io.flutter.plugin.platform.PlatformView

class NativeVideoView(
    context: Context,
    viewId: Int,
    creationParams: Any?
) : PlatformView {

    private val container = FrameLayout(context).apply {
        layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        )
    }

    private val textureView = TextureView(context).apply {
        layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        )
    }

    private val player: ExoPlayer? = null

    init {
        VideoPlaybackEngine.init(context.applicationContext)
        container.addView(textureView)
        VideoPlaybackEngine.getPlayer()?.let { exoPlayer ->
            exoPlayer.clearVideoTextureView(textureView)
            exoPlayer.setVideoTextureView(textureView)
        }
    }

    override fun getView(): View = container

    override fun dispose() {
        VideoPlaybackEngine.getPlayer()?.clearVideoTextureView(textureView)
        container.removeView(textureView)
    }
}
