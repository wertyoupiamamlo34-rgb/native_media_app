package com.example.native_media_app

import androidx.media3.common.C
import androidx.media3.exoplayer.audio.TeeAudioProcessor
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.atan
import kotlin.math.cos
import kotlin.math.ln
import kotlin.math.log10
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * Professional realtime analysis engine operating on real PCM captured through Media3.
 *
 * Pipeline:
 *   PCM capture -> ring buffer -> windowing -> FFT -> dB normalization ->
 *   Mel/Bark aggregation -> auto-gain + compression -> adaptive smoothing -> peak hold ->
 *   frame interpolation for stable rendering cadence.
 */
object ProfessionalAudioAnalysisEngine {

    enum class WindowType {
        HANN,
        HAMMING,
        BLACKMAN
    }

    enum class FrequencyScale {
        MEL,
        BARK,
        LOG
    }

    data class AnalysisConfig(
        val fftSize: Int = 2048,
        val hopSize: Int = 512,
        val internalBands: Int = 64,
        val windowType: WindowType = WindowType.HANN,
        val frequencyScale: FrequencyScale = FrequencyScale.MEL,
        val minDb: Double = -96.0,
        val maxDb: Double = -12.0,
        val noiseFloorDb: Double = -78.0,
        val compression: Double = 0.32,
        val autoGainTargetDb: Double = -24.0
    )

    data class AnalysisFrame(
        val bins: List<Double>,
        val peaks: List<Double>,
        val timestampMs: Long
    )

    private const val EPS = 1e-12
    private const val TARGET_FRAME_MS = 16L

    @Volatile
    private var config = AnalysisConfig()

    @Volatile
    private var frameListener: ((AnalysisFrame) -> Unit)? = null

    private val analysisExecutor = Executors.newSingleThreadExecutor { r ->
        Thread(r, "pro-audio-analysis").apply { isDaemon = true }
    }

    private val emitterExecutor: ScheduledExecutorService =
        Executors.newSingleThreadScheduledExecutor { r ->
            Thread(r, "pro-audio-frame-emitter").apply { isDaemon = true }
        }

    private val analysisScheduled = AtomicBoolean(false)

    private val ringLock = Any()
    private var ring = FloatArray(config.fftSize * 10)
    private var writeIndex = 0
    private var totalSamplesWritten = 0L
    private var analysisCursor = 0L

    private var sampleRateHz = 44100
    private var channelCount = 2
    private var pcmEncoding = C.ENCODING_PCM_16BIT

    private var window = buildWindow(config.windowType, config.fftSize)
    private var bandEdges = IntArray(config.internalBands + 1)

    private var frameRe = DoubleArray(config.fftSize)
    private var frameIm = DoubleArray(config.fftSize)
    private var fftMag = DoubleArray((config.fftSize / 2) + 1)

    private var smoothed = DoubleArray(config.internalBands)
    private var peaks = DoubleArray(config.internalBands)
    private var peakHoldTicks = IntArray(config.internalBands)

    private var targetBins = DoubleArray(config.internalBands)
    private var targetPeaks = DoubleArray(config.internalBands)
    private var renderBins = DoubleArray(config.internalBands)
    private var renderPeaks = DoubleArray(config.internalBands)

    private var autoGainDb = 0.0
    private var emitterStarted = false

    private val pcmSink = object : TeeAudioProcessor.AudioBufferSink {
        override fun flush(sampleRateHz: Int, channelCount: Int, encoding: Int) {
            onFormatChanged(sampleRateHz, channelCount, encoding)
        }

        override fun handleBuffer(buffer: ByteBuffer) {
            ingestPcm(buffer)
            scheduleAnalysis()
        }
    }

    fun createTeeAudioProcessor(): TeeAudioProcessor {
        ensureEmitterStarted()
        return TeeAudioProcessor(pcmSink)
    }

    fun setFrameListener(listener: ((AnalysisFrame) -> Unit)?) {
        frameListener = listener
        ensureEmitterStarted()
    }

    fun release() {
        synchronized(ringLock) {
            totalSamplesWritten = 0L
            analysisCursor = 0L
            writeIndex = 0
            ring.fill(0f)
        }
        smoothed.fill(0.0)
        peaks.fill(0.0)
        peakHoldTicks.fill(0)
        targetBins.fill(0.0)
        targetPeaks.fill(0.0)
        renderBins.fill(0.0)
        renderPeaks.fill(0.0)
        autoGainDb = 0.0
    }

    fun updateConfig(partial: Map<String, Any?>) {
        val old = config
        val newConfig = AnalysisConfig(
            fftSize = parseInt(partial["fftSize"], old.fftSize).coerceIn(1024, 4096)
                .toPowerOfTwo(),
            hopSize = parseInt(partial["hopSize"], old.hopSize).coerceIn(128, 1024),
            internalBands = parseInt(partial["internalBands"], old.internalBands).coerceIn(16, 128),
            windowType = parseWindowType(partial["windowType"], old.windowType),
            frequencyScale = parseScale(partial["frequencyScale"], old.frequencyScale),
            minDb = parseDouble(partial["minDb"], old.minDb).coerceIn(-120.0, -20.0),
            maxDb = parseDouble(partial["maxDb"], old.maxDb).coerceIn(-30.0, 0.0),
            noiseFloorDb = parseDouble(partial["noiseFloorDb"], old.noiseFloorDb).coerceIn(-110.0, -30.0),
            compression = parseDouble(partial["compression"], old.compression).coerceIn(0.0, 0.95),
            autoGainTargetDb = parseDouble(partial["autoGainTargetDb"], old.autoGainTargetDb)
                .coerceIn(-48.0, -6.0)
        )

        config = newConfig
        rebuildForConfig(newConfig)
    }

    private fun rebuildForConfig(cfg: AnalysisConfig) {
        synchronized(ringLock) {
            ring = FloatArray(cfg.fftSize * 10)
            writeIndex = 0
            totalSamplesWritten = 0L
            analysisCursor = cfg.fftSize.toLong()
        }

        window = buildWindow(cfg.windowType, cfg.fftSize)
        frameRe = DoubleArray(cfg.fftSize)
        frameIm = DoubleArray(cfg.fftSize)
        fftMag = DoubleArray((cfg.fftSize / 2) + 1)
        smoothed = DoubleArray(cfg.internalBands)
        peaks = DoubleArray(cfg.internalBands)
        peakHoldTicks = IntArray(cfg.internalBands)
        targetBins = DoubleArray(cfg.internalBands)
        targetPeaks = DoubleArray(cfg.internalBands)
        renderBins = DoubleArray(cfg.internalBands)
        renderPeaks = DoubleArray(cfg.internalBands)
        bandEdges = buildBandEdges(cfg, sampleRateHz)
        autoGainDb = 0.0
    }

    private fun onFormatChanged(sampleRateHz: Int, channelCount: Int, encoding: Int) {
        this.sampleRateHz = sampleRateHz.coerceAtLeast(8000)
        this.channelCount = channelCount.coerceAtLeast(1)
        this.pcmEncoding = encoding

        synchronized(ringLock) {
            writeIndex = 0
            totalSamplesWritten = 0L
            analysisCursor = config.fftSize.toLong()
            ring.fill(0f)
        }

        bandEdges = buildBandEdges(config, this.sampleRateHz)
    }

    private fun ingestPcm(source: ByteBuffer) {
        if (!source.hasRemaining()) return

        val readOnly = source.asReadOnlyBuffer()
        readOnly.order(ByteOrder.LITTLE_ENDIAN)

        when (pcmEncoding) {
            C.ENCODING_PCM_16BIT -> ingestPcm16(readOnly)
            C.ENCODING_PCM_FLOAT -> ingestPcmFloat(readOnly)
            C.ENCODING_PCM_8BIT -> ingestPcm8(readOnly)
            C.ENCODING_PCM_24BIT -> ingestPcm24(readOnly)
            C.ENCODING_PCM_32BIT -> ingestPcm32(readOnly)
            else -> ingestPcm16(readOnly)
        }
    }

    private fun ingestPcm16(buffer: ByteBuffer) {
        val channels = channelCount.coerceAtLeast(1)
        val bytesPerFrame = channels * 2
        while (buffer.remaining() >= bytesPerFrame) {
            var mono = 0.0
            for (c in 0 until channels) {
                mono += (buffer.short.toInt() / 32768.0)
            }
            mono /= channels.toDouble()
            pushSample(mono.toFloat())
        }
    }

    private fun ingestPcmFloat(buffer: ByteBuffer) {
        val channels = channelCount.coerceAtLeast(1)
        val bytesPerFrame = channels * 4
        while (buffer.remaining() >= bytesPerFrame) {
            var mono = 0.0
            for (c in 0 until channels) {
                mono += buffer.float.toDouble()
            }
            mono /= channels.toDouble()
            pushSample(mono.toFloat())
        }
    }

    private fun ingestPcm8(buffer: ByteBuffer) {
        val channels = channelCount.coerceAtLeast(1)
        val bytesPerFrame = channels
        while (buffer.remaining() >= bytesPerFrame) {
            var mono = 0.0
            for (c in 0 until channels) {
                val v = buffer.get().toInt() and 0xFF
                mono += (v - 128) / 128.0
            }
            mono /= channels.toDouble()
            pushSample(mono.toFloat())
        }
    }

    private fun ingestPcm24(buffer: ByteBuffer) {
        val channels = channelCount.coerceAtLeast(1)
        val bytesPerFrame = channels * 3
        while (buffer.remaining() >= bytesPerFrame) {
            var mono = 0.0
            for (c in 0 until channels) {
                val b0 = buffer.get().toInt() and 0xFF
                val b1 = buffer.get().toInt() and 0xFF
                val b2 = buffer.get().toInt()
                val sample = (b2 shl 24) or (b1 shl 16) or (b0 shl 8)
                mono += (sample / 2147483648.0)
            }
            mono /= channels.toDouble()
            pushSample(mono.toFloat())
        }
    }

    private fun ingestPcm32(buffer: ByteBuffer) {
        val channels = channelCount.coerceAtLeast(1)
        val bytesPerFrame = channels * 4
        while (buffer.remaining() >= bytesPerFrame) {
            var mono = 0.0
            for (c in 0 until channels) {
                mono += (buffer.int / 2147483648.0)
            }
            mono /= channels.toDouble()
            pushSample(mono.toFloat())
        }
    }

    private fun pushSample(sample: Float) {
        synchronized(ringLock) {
            ring[writeIndex] = sample
            writeIndex = (writeIndex + 1) % ring.size
            totalSamplesWritten += 1
        }
    }

    private fun scheduleAnalysis() {
        if (!analysisScheduled.compareAndSet(false, true)) return
        analysisExecutor.execute {
            try {
                runAnalysisLoop()
            } finally {
                analysisScheduled.set(false)
                if (pendingSamplesForAnalysis()) {
                    scheduleAnalysis()
                }
            }
        }
    }

    private fun pendingSamplesForAnalysis(): Boolean {
        val hop = config.hopSize.toLong()
        synchronized(ringLock) {
            return totalSamplesWritten - analysisCursor >= hop
        }
    }

    private fun runAnalysisLoop() {
        val cfg = config
        val fftSize = cfg.fftSize
        val hop = cfg.hopSize.toLong()
        val frame = DoubleArray(fftSize)

        while (true) {
            val canProcess = synchronized(ringLock) {
                totalSamplesWritten - analysisCursor >= hop
            }
            if (!canProcess) return

            val frameStart = (analysisCursor - fftSize).coerceAtLeast(0L)
            if (!copyFrame(frameStart, frame)) return

            processFrame(frame, cfg)

            synchronized(ringLock) {
                analysisCursor += hop
            }
        }
    }

    private fun copyFrame(absoluteStart: Long, out: DoubleArray): Boolean {
        synchronized(ringLock) {
            val availableStart = (totalSamplesWritten - ring.size).coerceAtLeast(0L)
            if (absoluteStart < availableStart) return false
            if (absoluteStart + out.size > totalSamplesWritten) return false

            val base = ((writeIndex - (totalSamplesWritten - absoluteStart).toInt())
                .floorMod(ring.size))
            for (i in out.indices) {
                out[i] = ring[(base + i) % ring.size].toDouble()
            }
            return true
        }
    }

    private fun processFrame(frame: DoubleArray, cfg: AnalysisConfig) {
        val fftSize = cfg.fftSize

        for (i in 0 until fftSize) {
            frameRe[i] = frame[i] * window[i]
            frameIm[i] = 0.0
        }

        fft(frameRe, frameIm)

        val nyquistBins = fftMag.size
        for (i in 0 until nyquistBins) {
            val re = frameRe[i]
            val im = frameIm[i]
            val mag = sqrt((re * re) + (im * im)) / fftSize
            fftMag[i] = 20.0 * log10(max(mag, EPS))
        }

        val framePeakDb = percentile(fftMag, 0.94)
        val targetGain = cfg.autoGainTargetDb - framePeakDb
        autoGainDb = lerp(autoGainDb, targetGain, 0.08).coerceIn(-28.0, 28.0)

        val bandDb = DoubleArray(cfg.internalBands)
        for (b in 0 until cfg.internalBands) {
            val start = bandEdges[b].coerceAtLeast(1)
            val end = bandEdges[b + 1].coerceAtLeast(start + 1)
            var powerSum = 0.0
            var count = 0
            for (i in start until min(end, nyquistBins)) {
                val db = fftMag[i] + autoGainDb
                val lin = 10.0.pow(db / 20.0)
                powerSum += lin * lin
                count++
            }

            val rms = if (count > 0) sqrt(powerSum / count) else 0.0
            val dbValue = 20.0 * log10(max(rms, EPS))
            bandDb[b] = dbValue
        }

        val normalized = DoubleArray(cfg.internalBands)
        for (i in normalized.indices) {
            val freqNorm = if (normalized.size <= 1) 0.0 else i.toDouble() / (normalized.size - 1)
            val attack = lerp(0.78, 0.56, freqNorm)
            val decay = lerp(0.16, 0.30, freqNorm)

            val compressed = applyCompression(
                valueDb = bandDb[i],
                minDb = cfg.minDb,
                maxDb = cfg.maxDb,
                strength = cfg.compression
            )

            val noised = if (bandDb[i] < cfg.noiseFloorDb) 0.0 else compressed
            val prev = smoothed[i]
            val smooth = if (noised > prev) {
                prev + ((noised - prev) * attack)
            } else {
                prev + ((noised - prev) * decay)
            }.coerceIn(0.0, 1.0)

            smoothed[i] = smooth
            normalized[i] = smooth

            val holdTicks = peakHoldTicks[i]
            var peak = peaks[i]
            if (smooth >= peak) {
                peak = smooth
                peakHoldTicks[i] = (3 + (freqNorm * 5).toInt())
            } else if (holdTicks > 0) {
                peakHoldTicks[i] = holdTicks - 1
            } else {
                val fall = lerp(0.010, 0.024, freqNorm)
                peak = max(0.0, peak - fall)
            }
            peaks[i] = peak
        }

        targetBins = normalized
        targetPeaks = peaks.copyOf()
    }

    private fun ensureEmitterStarted() {
        if (emitterStarted) return
        emitterStarted = true
        emitterExecutor.scheduleAtFixedRate(
            {
                emitInterpolatedFrame()
            },
            TARGET_FRAME_MS,
            TARGET_FRAME_MS,
            TimeUnit.MILLISECONDS
        )
    }

    private fun emitInterpolatedFrame() {
        if (targetBins.isEmpty()) return
        val listener = frameListener ?: return

        val interp = 0.34
        for (i in renderBins.indices) {
            renderBins[i] = lerp(renderBins[i], targetBins[i], interp)
            renderPeaks[i] = max(renderPeaks[i] - 0.012, targetPeaks[i])
        }

        listener.invoke(
            AnalysisFrame(
                bins = renderBins.map { it.coerceIn(0.0, 1.0) },
                peaks = renderPeaks.map { it.coerceIn(0.0, 1.0) },
                timestampMs = System.currentTimeMillis()
            )
        )
    }

    private fun applyCompression(
        valueDb: Double,
        minDb: Double,
        maxDb: Double,
        strength: Double
    ): Double {
        val normalized = ((valueDb - minDb) / max(1e-6, (maxDb - minDb))).coerceIn(0.0, 1.0)
        val gamma = (1.0 - (strength * 0.8)).coerceIn(0.2, 1.0)
        return normalized.pow(gamma)
    }

    private fun buildWindow(type: WindowType, size: Int): DoubleArray {
        if (size <= 1) return DoubleArray(size) { 1.0 }
        return DoubleArray(size) { i ->
            val phase = (2.0 * Math.PI * i) / (size - 1)
            when (type) {
                WindowType.HANN -> 0.5 * (1.0 - cos(phase))
                WindowType.HAMMING -> 0.54 - (0.46 * cos(phase))
                WindowType.BLACKMAN -> 0.42 - (0.5 * cos(phase)) + (0.08 * cos(2.0 * phase))
            }
        }
    }

    private fun buildBandEdges(cfg: AnalysisConfig, sampleRateHz: Int): IntArray {
        val nFftBins = (cfg.fftSize / 2) + 1
        val nyquist = sampleRateHz / 2.0
        val minHz = 20.0
        val maxHz = max(minHz + 1.0, nyquist)

        fun hzToBin(hz: Double): Int {
            val ratio = (hz / nyquist).coerceIn(0.0, 1.0)
            return (ratio * (nFftBins - 1)).toInt().coerceIn(0, nFftBins - 1)
        }

        val edges = IntArray(cfg.internalBands + 1)
        when (cfg.frequencyScale) {
            FrequencyScale.MEL -> {
                val melMin = hzToMel(minHz)
                val melMax = hzToMel(maxHz)
                for (i in 0..cfg.internalBands) {
                    val t = i.toDouble() / cfg.internalBands
                    val mel = melMin + ((melMax - melMin) * t)
                    edges[i] = hzToBin(melToHz(mel))
                }
            }

            FrequencyScale.BARK -> {
                val barkMin = hzToBark(minHz)
                val barkMax = hzToBark(maxHz)
                for (i in 0..cfg.internalBands) {
                    val t = i.toDouble() / cfg.internalBands
                    val bark = barkMin + ((barkMax - barkMin) * t)
                    edges[i] = hzToBin(barkToHz(bark))
                }
            }

            FrequencyScale.LOG -> {
                val logMin = ln(minHz)
                val logMax = ln(maxHz)
                for (i in 0..cfg.internalBands) {
                    val t = i.toDouble() / cfg.internalBands
                    val hz = kotlin.math.exp(logMin + ((logMax - logMin) * t))
                    edges[i] = hzToBin(hz)
                }
            }
        }

        for (i in 1 until edges.size) {
            if (edges[i] <= edges[i - 1]) {
                edges[i] = (edges[i - 1] + 1).coerceAtMost(nFftBins - 1)
            }
        }

        edges[0] = max(1, edges[0])
        edges[edges.lastIndex] = nFftBins - 1
        return edges
    }

    private fun hzToMel(hz: Double): Double = 2595.0 * log10(1.0 + (hz / 700.0))
    private fun melToHz(mel: Double): Double = 700.0 * (10.0.pow(mel / 2595.0) - 1.0)

    private fun hzToBark(hz: Double): Double {
        val hzKhz = hz / 1000.0
        return 13.0 * atan(0.76 * hzKhz) + 3.5 * atan((hzKhz / 7.5).pow(2.0))
    }

    private fun barkToHz(bark: Double): Double {
        val ratio = bark / 13.0
        return 650.0 * sin(ratio).coerceAtLeast(0.0)
    }

    private fun fft(re: DoubleArray, im: DoubleArray) {
        val n = re.size
        val levels = Integer.numberOfTrailingZeros(n)

        for (i in 0 until n) {
            val j = Integer.reverse(i) ushr (32 - levels)
            if (j > i) {
                val tr = re[i]
                re[i] = re[j]
                re[j] = tr

                val ti = im[i]
                im[i] = im[j]
                im[j] = ti
            }
        }

        var size = 2
        while (size <= n) {
            val halfSize = size / 2
            val tableStep = n / size
            var i = 0
            while (i < n) {
                var j = i
                var k = 0
                while (j < i + halfSize) {
                    val angle = (2.0 * Math.PI * k) / n
                    val tpre = (re[j + halfSize] * cos(angle)) + (im[j + halfSize] * sin(angle))
                    val tpim = (-re[j + halfSize] * sin(angle)) + (im[j + halfSize] * cos(angle))

                    re[j + halfSize] = re[j] - tpre
                    im[j + halfSize] = im[j] - tpim
                    re[j] += tpre
                    im[j] += tpim

                    j++
                    k += tableStep
                }
                i += size
            }
            size *= 2
        }
    }

    private fun percentile(values: DoubleArray, p: Double): Double {
        if (values.isEmpty()) return -96.0
        val copy = values.copyOf()
        copy.sort()
        val idx = ((copy.size - 1) * p.coerceIn(0.0, 1.0)).toInt().coerceIn(0, copy.lastIndex)
        return copy[idx]
    }

    private fun parseWindowType(value: Any?, fallback: WindowType): WindowType {
        val raw = value?.toString()?.trim()?.uppercase() ?: return fallback
        return when (raw) {
            "HANN" -> WindowType.HANN
            "HAMMING" -> WindowType.HAMMING
            "BLACKMAN" -> WindowType.BLACKMAN
            else -> fallback
        }
    }

    private fun parseScale(value: Any?, fallback: FrequencyScale): FrequencyScale {
        val raw = value?.toString()?.trim()?.uppercase() ?: return fallback
        return when (raw) {
            "MEL" -> FrequencyScale.MEL
            "BARK" -> FrequencyScale.BARK
            "LOG" -> FrequencyScale.LOG
            else -> fallback
        }
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

    private fun Int.floorMod(mod: Int): Int {
        val m = this % mod
        return if (m < 0) m + mod else m
    }

    private fun Int.toPowerOfTwo(): Int {
        var v = 1
        while (v < this) v = v shl 1
        return v
    }

    private fun lerp(from: Double, to: Double, alpha: Double): Double {
        return from + ((to - from) * alpha.coerceIn(0.0, 1.0))
    }
}
