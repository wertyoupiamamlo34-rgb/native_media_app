package com.example.native_media_app

import android.media.audiofx.Visualizer
import android.util.Log
import kotlin.math.*

object AndroidVisualizerEngine {

    data class AnalysisConfig(
        val captureSize: Int = 1024,
        val captureRate: Int = Visualizer.getMaxCaptureRate(),
        val bands: Int = 32,
        val minDb: Double = -90.0,
        val maxDb: Double = -12.0,
        val noiseFloorDb: Double = -78.0
    )

    data class AnalysisFrame(
        val bins: List<Double>,
        val peaks: List<Double>,
        val timestampMs: Long
    )

    private var visualizer: Visualizer? = null
    private var currentSessionId = Visualizer.ERROR
    private var frameListener: ((AnalysisFrame) -> Unit)? = null
    private var config = AnalysisConfig()
    private var bandEdges: IntArray = intArrayOf()

    fun setFrameListener(listener: ((AnalysisFrame) -> Unit)?) {
        frameListener = listener
    }

    fun updateConfig(partial: Map<String, Any?>) {
        val old = config
        val requestedCaptureSize = parseInt(partial["captureSize"], old.captureSize)
            .takeIf { it > 0 }
            ?: parseInt(partial["fftSize"], old.captureSize)
            .takeIf { it > 0 }
            ?: old.captureSize
        val requestedBands = parseInt(partial["internalBands"], old.bands).coerceIn(8, 64)
        val minDb = parseDouble(partial["minDb"], old.minDb)
        val maxDb = parseDouble(partial["maxDb"], old.maxDb)
        val noiseFloorDb = parseDouble(partial["noiseFloorDb"], old.noiseFloorDb)

        val maxCapture = Visualizer.getCaptureSizeRange()[1]
        val minCapture = Visualizer.getCaptureSizeRange()[0]
        val captureSize = requestedCaptureSize
            .coerceIn(minCapture, maxCapture)
            .let { it.toPowerOfTwo().coerceIn(minCapture, maxCapture) }

        config = AnalysisConfig(
            captureSize = captureSize,
            captureRate = Visualizer.getMaxCaptureRate(),
            bands = requestedBands,
            minDb = minDb.coerceIn(-120.0, -20.0),
            maxDb = maxDb.coerceIn(-30.0, 0.0),
            noiseFloorDb = noiseFloorDb.coerceIn(-110.0, -30.0)
        )
        bandEdges = buildBandEdges(config.bands, config.captureSize / 2)

        if (visualizer != null) {
            restartVisualizer()
        }
    }

    fun attach(audioSessionId: Int) {
        if (audioSessionId == Visualizer.ERROR || audioSessionId == currentSessionId) {
            return
        }

        release()
        currentSessionId = audioSessionId

        try {
            val captureSize = config.captureSize
            visualizer = Visualizer(audioSessionId).apply {
                enabled = false
                setCaptureSize(captureSize)
                setDataCaptureListener(
                    object : Visualizer.OnDataCaptureListener {
                        override fun onWaveFormDataCapture(
                            visualizer: Visualizer?,
                            waveform: ByteArray?,
                            samplingRate: Int
                        ) {
                            // Not used for spectrum output.
                        }

                        override fun onFftDataCapture(
                            visualizer: Visualizer?,
                            fft: ByteArray,
                            samplingRate: Int
                        ) {
                            try {
                                val frame = processFft(fft)
                                frameListener?.invoke(frame)
                            } catch (t: Throwable) {
                                Log.w("AndroidVisualizerEngine", "FFT processing failed", t)
                            }
                        }
                    },
                    config.captureRate,
                    false,
                    true
                )
                enabled = true
            }
        } catch (t: Throwable) {
            Log.w("AndroidVisualizerEngine", "Unable to attach Visualizer", t)
            release()
        }
    }

    fun release() {
        currentSessionId = Visualizer.ERROR
        visualizer?.let {
            try {
                it.setDataCaptureListener(null, 0, false, false)
                it.enabled = false
            } catch (_: Throwable) {
            }
            try {
                it.release()
            } catch (_: Throwable) {
            }
        }
        visualizer = null
    }

    private fun restartVisualizer() {
        val session = currentSessionId
        release()
        if (session != Visualizer.ERROR) {
            attach(session)
        }
    }

    private fun processFft(fft: ByteArray): AnalysisFrame {
        if (bandEdges.isEmpty()) {
            bandEdges = buildBandEdges(config.bands, config.captureSize / 2)
        }

        val bandCount = config.bands
        val bins = MutableList(bandCount) { 0.0 }
        val peaks = MutableList(bandCount) { 0.0 }

        val rawBins = fft.size / 2
        if (rawBins <= 1) {
            return AnalysisFrame(bins, peaks, System.currentTimeMillis())
        }

        val maxMagnitude = sqrt((255.0 * 255.0) * 2.0)
        for (band in 0 until bandCount) {
            val start = bandEdges[band].coerceAtLeast(1)
            val end = bandEdges[band + 1].coerceAtMost(rawBins - 1)
            var sum = 0.0
            var count = 0
            for (bin in start..end) {
                val re = fft[bin * 2].toInt().toDouble()
                val im = fft[bin * 2 + 1].toInt().toDouble()
                val magnitude = sqrt(re * re + im * im)
                sum += magnitude * magnitude
                count++
            }
            if (count > 0) {
                val rms = sqrt(sum / count)
                val db = 20.0 * log10((rms / maxMagnitude).coerceAtLeast(1e-12))
                val normalized = ((db - config.minDb) / (config.maxDb - config.minDb)).coerceIn(0.0, 1.0)
                bins[band] = normalized
                peaks[band] = normalized
            }
        }

        return AnalysisFrame(bins, peaks, System.currentTimeMillis())
    }

    private fun buildBandEdges(bands: Int, fftBins: Int): IntArray {
        if (bands <= 0) return intArrayOf(1)
        val edges = IntArray(bands + 1)
        val minIndex = 1
        val maxIndex = fftBins.coerceAtLeast(2) - 1
        edges[0] = minIndex
        edges[bands] = maxIndex

        if (bands == 1) {
            return edges
        }

        val ratio = (maxIndex.toDouble() / minIndex.toDouble()).pow(1.0 / bands)
        var current = minIndex.toDouble()
        for (i in 1 until bands) {
            current *= ratio
            edges[i] = current.toInt().coerceAtLeast(edges[i - 1] + 1).coerceAtMost(maxIndex - 1)
        }

        for (i in 1 until bands) {
            if (edges[i] <= edges[i - 1]) {
                edges[i] = edges[i - 1] + 1
            }
        }
        edges[bands] = maxIndex
        return edges
    }

    private fun parseInt(value: Any?, fallback: Int): Int {
        return when (value) {
            is Int -> value
            is Number -> value.toInt()
            is String -> value.toIntOrNull() ?: fallback
            else -> fallback
        }
    }

    private fun parseDouble(value: Any?, fallback: Double): Double {
        return when (value) {
            is Double -> value
            is Float -> value.toDouble()
            is Number -> value.toDouble()
            is String -> value.toDoubleOrNull() ?: fallback
            else -> fallback
        }
    }

    private fun Int.toPowerOfTwo(): Int {
        var v = 1
        while (v < this) v = v shl 1
        return v
    }
}
