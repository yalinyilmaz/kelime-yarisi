package com.csdcorp.speech_to_text

import android.app.Activity
import android.app.Application
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import java.util.ArrayDeque
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/** 16kHz mono PCM, RAM only. API 33+ recognition services may consume the pipe. */
internal class SpeechAudioPrebuffer(
    private val activity: Activity,
    private val failure: () -> Unit,
) : Application.ActivityLifecycleCallbacks {
    private val handler = Handler(Looper.getMainLooper())
    private val running = AtomicBoolean(false)
    private val lock = Any()
    private val ring = ArrayDeque<ByteArray>()
    private var ringBytes = 0
    private val queue = ArrayBlockingQueue<ByteArray>(180) // <=3.6s including pre-roll.
    @Volatile private var armed = false
    @Volatile private var inputEnded = false
    private var reader: ParcelFileDescriptor? = null
    private var writer: ParcelFileDescriptor.AutoCloseOutputStream? = null
    private var recorder: AudioRecord? = null
    private var worker: Thread? = null
    private var ready: ((Boolean) -> Unit)? = null
    private var endAtNanos = Long.MAX_VALUE
    private val deadline = Runnable { finish() }
    private val startupTimeout = Runnable { if (ready != null) close() }

    val isRunning: Boolean get() = running.get()
    val isArmed: Boolean get() = armed

    @Suppress("MissingPermission")
    fun start(completion: (Boolean) -> Unit) {
        ready = completion
        val size = AudioRecord.getMinBufferSize(16000, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
        check(size > 0) { "Microphone format unavailable" }
        val audio = AudioRecord.Builder()
            .setAudioSource(MediaRecorder.AudioSource.VOICE_RECOGNITION)
            .setAudioFormat(AudioFormat.Builder().setSampleRate(16000)
                .setChannelMask(AudioFormat.CHANNEL_IN_MONO).setEncoding(AudioFormat.ENCODING_PCM_16BIT).build())
            .setBufferSizeInBytes(maxOf(size, 6400)).build()
        recorder = audio
        check(audio.state == AudioRecord.STATE_INITIALIZED)
        activity.application.registerActivityLifecycleCallbacks(this)
        audio.startRecording()
        check(audio.recordingState == AudioRecord.RECORDSTATE_RECORDING)
        running.set(true)
        handler.postDelayed(startupTimeout, 5000)
        val captureThread = Thread({
            try {
                val chunk = ByteArray(640) // 20ms
                var first = true
                while (running.get()) {
                    val count = audio.read(chunk, 0, chunk.size, AudioRecord.READ_BLOCKING)
                    if (count <= 0) {
                        if (running.get()) throw IllegalStateException("Microphone read failed")
                        break
                    }
                    synchronized(lock) {
                        if (!running.get()) return@synchronized
                        if (armed && System.nanoTime() >= endAtNanos) {
                            handler.post { finish() }
                        } else {
                            val copy = chunk.copyOf(count)
                            if (armed) {
                                check(queue.offer(copy)) { "Audio buffer overflow" }
                            } else {
                                ring.addLast(copy); ringBytes += count
                                while (ringBytes > 9600) ringBytes -= ring.removeFirst().size
                            }
                        }
                    }
                    if (first) {
                        first = false
                        handler.post { val callback = ready; ready = null; handler.removeCallbacks(startupTimeout); callback?.invoke(running.get()) }
                    }
                }
            } catch (_: Exception) {
                if (running.get()) handler.post { close(); failure() }
            } finally {
                audio.release()
            }
        }, "speech-prebuffer-capture")
        worker = captureThread
        captureThread.start()
    }

    fun begin(): Boolean = synchronized(lock) {
        if (!running.get() || armed) return@synchronized false
        queue.clear()
        for (chunk in ring) check(queue.offer(chunk))
        ring.clear(); ringBytes = 0
        inputEnded = false; armed = true
        endAtNanos = System.nanoTime() + 3_000_000_000L
        handler.postDelayed(deadline, 3000)
        true
    }

    fun attach(): ParcelFileDescriptor {
        check(armed && reader == null)
        val pipe = ParcelFileDescriptor.createPipe()
        reader = pipe[0]
        val output = ParcelFileDescriptor.AutoCloseOutputStream(pipe[1])
        writer = output
        Thread({
            try {
                while (armed && (!inputEnded || queue.isNotEmpty())) {
                    val bytes = queue.poll(50, TimeUnit.MILLISECONDS) ?: continue
                    output.write(bytes)
                }
            } catch (_: Exception) {
                if (armed && !inputEnded) handler.post { close(); failure() }
            } finally {
                try { output.close() } catch (_: Exception) {}
            }
        }, "speech-prebuffer-pipe").start()
        return pipe[0]
    }

    /** End capture, drain queued samples, then close the pipe to signal EOF. */
    fun finish() {
        handler.removeCallbacks(deadline)
        synchronized(lock) { inputEnded = true; running.set(false) }
        try { recorder?.stop() } catch (_: Exception) {}
    }

    /** Cancellation discards all samples and unblocks both native workers. */
    fun close() {
        armed = false
        finish()
        handler.removeCallbacks(startupTimeout)
        try { writer?.close() } catch (_: Exception) {}
        try { reader?.close() } catch (_: Exception) {}
        if (worker == null) { recorder?.release(); recorder = null }
        writer = null; reader = null
        synchronized(lock) { ring.clear(); ringBytes = 0; queue.clear() }
        val callback = ready; ready = null
        callback?.invoke(false)
        activity.application.unregisterActivityLifecycleCallbacks(this)
    }

    override fun onActivityPaused(target: Activity) { if (target === activity) close() }
    override fun onActivityDestroyed(target: Activity) { if (target === activity) close() }
    override fun onActivityCreated(a: Activity, b: Bundle?) {}
    override fun onActivityStarted(a: Activity) {}
    override fun onActivityResumed(a: Activity) {}
    override fun onActivityStopped(a: Activity) {}
    override fun onActivitySaveInstanceState(a: Activity, b: Bundle) {}
}
