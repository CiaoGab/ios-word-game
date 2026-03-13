import AVFoundation

/// Centralized SFX manager for RUUN.
///
/// Design notes:
/// - Uses AVAudioEngine with a pre-allocated player-node pool (no per-sound attach/detach).
/// - All PCM buffers are generated procedurally at init — no audio asset files needed.
/// - Connects player nodes with `format: nil` so AVAudioEngine negotiates the hardware
///   format automatically. Avoids format-mismatch crashes on device.
/// - Buffer format is derived from the live engine after it starts, guaranteeing
///   compatibility between buffers and the audio graph.
/// - Pre-warmed at app launch via `SoundManager.prepare()` so first gameplay tap
///   never triggers engine setup.
final class SoundManager {

    static let shared = SoundManager()

    /// Call once at app launch (e.g. in WordFallApp.init) to pre-warm the audio
    /// engine before the first gameplay tap, avoiding first-tap latency or crashes.
    static func prepare() { _ = shared }

    // MARK: - Sound identifiers

    enum SoundID {
        case tileTap, tileDeselect
        case validSubmitImpact, validSubmitChime
        case invalidSubmit
        case tallyTick
        case roundCleared1, roundCleared2, roundCleared3, roundCleared4
        case buttonTap, modalOpen, modalClose
        case powerupStep1, powerupStep2
        case lockBreak, cascade
    }

    // MARK: - Internal state

    private let engine = AVAudioEngine()
    /// Actual hardware-negotiated format; derived from the live engine after start.
    private var format: AVAudioFormat
    private var buffers: [SoundID: AVAudioPCMBuffer] = [:]
    private let playerPool: [AVAudioPlayerNode]
    private var poolIndex: Int = 0

    private let tapThrottle: TimeInterval = 0.05
    private var lastTapTime: TimeInterval = 0

    // MARK: - Init

    private init() {
        // Provide a safe fallback; overwritten after the engine starts.
        format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!

        // 1. Configure AVAudioSession BEFORE touching AVAudioEngine.
        Self.configureAudioSession()

        // 2. Build player-node pool.
        var pool: [AVAudioPlayerNode] = []
        for _ in 0..<10 { pool.append(AVAudioPlayerNode()) }
        playerPool = pool

        // 3. Attach and connect with format: nil.
        //    AVAudioEngine negotiates the connection format to match the hardware
        //    output format, preventing format-mismatch crashes on device.
        for node in playerPool {
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: nil)
        }

        // 4. Start the engine so the graph is fully realized.
        do {
            try engine.start()
        } catch {
            #if DEBUG
            print("[SoundManager] ⚠️  engine.start() failed: \(error)")
            #endif
            // Engine didn't start — buildBuffers will still run but sounds won't play.
        }

        // 5. Derive the actual buffer format from the live output node.
        //    After engine.start(), outputNode reports the hardware-negotiated format.
        //    Using this format for PCM buffers guarantees schedule-buffer compatibility.
        let hwFormat = engine.outputNode.outputFormat(forBus: 0)
        if hwFormat.sampleRate > 0 && hwFormat.channelCount > 0 {
            format = hwFormat
        }
        // If hwFormat is unusable (engine failed to start), format stays at the fallback.

        #if DEBUG
        let sessionSR = AVAudioSession.sharedInstance().sampleRate
        print("[SoundManager] Session sample rate : \(sessionSR) Hz")
        print("[SoundManager] Buffer format        : \(format)")
        print("[SoundManager] Engine running       : \(engine.isRunning)")
        #endif

        // 6. Pre-generate all PCM buffers using the actual hardware format.
        buildBuffers()
    }

    // MARK: - Audio session

    private static func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            #if DEBUG
            print("[SoundManager] ⚠️  AVAudioSession setup failed: \(error)")
            #endif
        }
    }

    // MARK: - Buffer definitions

    private func buildBuffers() {
        buffers[.tileTap]           = sine(hz: 900,  dur: 0.065, vol: 0.16, atk: 0.003, dec: 0.055)
        buffers[.tileDeselect]      = sine(hz: 650,  dur: 0.055, vol: 0.12, atk: 0.003, dec: 0.048)
        buffers[.validSubmitImpact] = sine(hz: 523,  dur: 0.110, vol: 0.20, atk: 0.005, dec: 0.085)
        buffers[.validSubmitChime]  = sine(hz: 659,  dur: 0.140, vol: 0.17, atk: 0.005, dec: 0.110)
        buffers[.invalidSubmit]     = tri( hz: 210,  dur: 0.160, vol: 0.18, atk: 0.010, dec: 0.130)
        buffers[.tallyTick]         = sine(hz: 1050, dur: 0.038, vol: 0.09, atk: 0.002, dec: 0.032)
        buffers[.roundCleared1]     = sine(hz: 523,  dur: 0.180, vol: 0.18, atk: 0.005, dec: 0.140)
        buffers[.roundCleared2]     = sine(hz: 659,  dur: 0.200, vol: 0.20, atk: 0.005, dec: 0.160)
        buffers[.roundCleared3]     = sine(hz: 784,  dur: 0.220, vol: 0.22, atk: 0.005, dec: 0.180)
        buffers[.roundCleared4]     = sine(hz: 1047, dur: 0.260, vol: 0.24, atk: 0.005, dec: 0.220)
        buffers[.buttonTap]         = sine(hz: 820,  dur: 0.055, vol: 0.10, atk: 0.003, dec: 0.046)
        buffers[.modalOpen]         = sine(hz: 760,  dur: 0.080, vol: 0.10, atk: 0.006, dec: 0.065)
        buffers[.modalClose]        = sine(hz: 580,  dur: 0.072, vol: 0.09, atk: 0.005, dec: 0.060)
        buffers[.powerupStep1]      = sine(hz: 659,  dur: 0.100, vol: 0.16, atk: 0.005, dec: 0.080)
        buffers[.powerupStep2]      = sine(hz: 880,  dur: 0.140, vol: 0.18, atk: 0.005, dec: 0.115)
        buffers[.lockBreak]         = tri( hz: 340,  dur: 0.140, vol: 0.18, atk: 0.010, dec: 0.115)
        buffers[.cascade]           = sine(hz: 740,  dur: 0.090, vol: 0.13, atk: 0.004, dec: 0.074)
    }

    // MARK: - Buffer generation

    private func sine(hz: Float, dur: Float, vol: Float, atk: Float, dec: Float) -> AVAudioPCMBuffer? {
        makeBuffer(hz: hz, dur: dur, vol: vol, atk: atk, dec: dec, useTriangle: false)
    }

    private func tri(hz: Float, dur: Float, vol: Float, atk: Float, dec: Float) -> AVAudioPCMBuffer? {
        makeBuffer(hz: hz, dur: dur, vol: vol, atk: atk, dec: dec, useTriangle: true)
    }

    /// Generates a PCM buffer in `format` (mono or stereo, any sample rate).
    /// Signal is written to channel 0 then copied to any additional channels so the
    /// buffer is always compatible with the engine's output format.
    private func makeBuffer(hz: Float, dur: Float, vol: Float,
                            atk: Float, dec: Float, useTriangle: Bool) -> AVAudioPCMBuffer? {
        let sr       = Float(format.sampleRate)
        let channels = Int(format.channelCount)
        guard sr > 0, channels > 0 else { return nil }

        let n = Int(sr * dur)
        guard n > 0,
              let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(n))
        else { return nil }
        buf.frameLength = AVAudioFrameCount(n)

        let atkN = max(1, Int(sr * atk))
        let decN = max(1, Int(sr * dec))
        let ch0  = buf.floatChannelData![0]

        for i in 0..<n {
            let t = Float(i) / sr

            let raw: Float
            if useTriangle {
                let period = 1.0 / hz
                let phase  = t.truncatingRemainder(dividingBy: period) / period
                raw = phase < 0.5 ? (4.0 * phase - 1.0) : (3.0 - 4.0 * phase)
            } else {
                raw = sin(2.0 * .pi * hz * t)
            }

            let env: Float
            if i < atkN            { env = Float(i)     / Float(atkN) }
            else if i >= n - decN  { env = Float(n - i) / Float(decN) }
            else                   { env = 1.0 }

            ch0[i] = raw * env * vol
        }

        // Duplicate channel 0 into any additional channels (e.g. right stereo channel).
        for ch in 1..<channels {
            buf.floatChannelData![ch].initialize(from: ch0, count: n)
        }

        return buf
    }

    // MARK: - Playback

    private func play(_ id: SoundID) {
        guard AppSettings.soundEnabled, let buf = buffers[id] else { return }
        playBuffer(buf)
    }

    private func playBuffer(_ buf: AVAudioPCMBuffer) {
        // Restart engine if stopped (e.g. after an audio route change).
        if !engine.isRunning {
            do { try engine.start() } catch {
                #if DEBUG
                print("[SoundManager] ⚠️  engine.start() failed during playback: \(error)")
                #endif
                return
            }
        }
        let node = playerPool[poolIndex]
        poolIndex = (poolIndex + 1) % playerPool.count
        node.stop()
        node.scheduleBuffer(buf)
        node.play()
    }

    // MARK: - Game SFX API

    func playTileTap() {
        guard AppSettings.soundEnabled else { return }
        let now = Date().timeIntervalSinceReferenceDate
        guard now - lastTapTime >= tapThrottle else { return }
        lastTapTime = now
        play(.tileTap)
    }

    func playTileDeselect() { play(.tileDeselect) }

    func playValidSubmit() {
        play(.validSubmitImpact)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            self?.play(.validSubmitChime)
        }
    }

    func playInvalidSubmit() { play(.invalidSubmit) }

    func playTallyTick() { play(.tallyTick) }

    func playRoundCleared() {
        let steps: [(SoundID, TimeInterval)] = [
            (.roundCleared1, 0.00), (.roundCleared2, 0.10),
            (.roundCleared3, 0.20), (.roundCleared4, 0.32),
        ]
        for (id, delay) in steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.play(id)
            }
        }
    }

    func playButtonTap()  { play(.buttonTap)  }
    func playPowerupUse() {
        play(.powerupStep1)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) { [weak self] in
            self?.play(.powerupStep2)
        }
    }
    func playModalOpen()  { play(.modalOpen)  }
    func playModalClose() { play(.modalClose) }
    func playLockBreak()  { play(.lockBreak)  }
    func playCascade()    { play(.cascade)    }

    // MARK: - Legacy compatibility

    func playSelection() { playTileTap() }
    func playClear()     { playRoundCleared() }
}
