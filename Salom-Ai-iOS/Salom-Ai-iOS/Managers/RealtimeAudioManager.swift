//
//  RealtimeAudioManager.swift
//  Salom-Ai-iOS
//
//  Audio recording and playback manager for real-time voice
//

import Foundation
import AVFoundation
import Combine

class RealtimeAudioManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var audioLevel: Float = 0.0
    /// RMS of the streaming PCM playback (assistant voice). Drives the
    /// visualizer when the OpenAI provider is speaking.
    @Published var streamingPlayerLevel: Float = 0.0

    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var audioPlayer: AVAudioPlayer?
    // Streaming output: OpenAI Realtime sends 24 kHz PCM16 deltas which we
    // schedule on this player node. CRITICAL: the player node is attached to
    // the SAME engine as the mic — that's what gives iOS Voice Processing IO
    // (VPIO) a reference signal so AEC actually works and the assistant
    // doesn't cut itself off from its own speaker output.
    private var streamingPlayerNode: AVAudioPlayerNode?
    private var streamingFormat: AVAudioFormat?
    private var pendingStreamingChunks: Int = 0
    /// 24 kHz PCM16 — matches OpenAI Realtime's audio.output.format.
    private let streamingOutputRate: Double = 24000

    // Recording sample rate is provider-configurable:
    //   Yandex STT expects 16 kHz PCM16
    //   OpenAI Realtime expects 24 kHz PCM16
    private let sampleRate: Double
    private let channelCount: AVAudioChannelCount = 1
    private var shouldResumeRecording = false

    // HPF State
    private var prevX: Int16 = 0
    private var prevY: Float = 0.0

    var onAudioChunk: ((Data) -> Void)?
    var onSpeechDetected: (() -> Void)?
    var onSilenceDetected: (() -> Void)?
    /// Fires when the streaming player drains (all queued chunks played).
    /// OpenAIRealtimeManager uses this to flip voice state back to .listening.
    var onStreamingDrained: (() -> Void)?
    
    init(sampleRate: Double = 16000) {
        self.sampleRate = sampleRate
        super.init()
        setupAudioSession()
        print("🎚️ [RealtimeAudio] Configured @ \(Int(sampleRate)) Hz")
    }
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            // .voiceChat optimizes hardware for human voice frequencies
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
            print("✅ [RealtimeAudio] Audio session configured")
        } catch {
            print("❌ [RealtimeAudio] Failed to setup audio session: \(error.localizedDescription)")
        }
    }
    
    func startRecording() {
        guard !isRecording else {
            print("⚠️ [RealtimeAudio] Already recording")
            return
        }
        
        print("🎤 [RealtimeAudio] Starting recording")
        
        // 1. Ensure Session is Active
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch {
            print("❌ [RealtimeAudio] Failed to activate session: \(error)")
            return
        }
        
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            print("❌ [RealtimeAudio] Failed to create audio engine")
            return
        }
        
        inputNode = audioEngine.inputNode
        guard let inputNode = inputNode else {
            print("❌ [RealtimeAudio] No input node available")
            return
        }

        // -------------------------------------------------------------------
        // Voice Processing IO (VPIO) — the real fix for assistant self-cutoff.
        //
        // VPIO is iOS's hardware-accelerated AEC + noise suppression + AGC.
        // It replaces the underlying audio unit on the inputNode. Without it,
        // we only have session-level `.voiceChat` AEC, which on iPhone speaker
        // is too weak: the assistant's voice leaks back through the mic and
        // triggers OpenAI's server VAD → response gets cancelled mid-word.
        //
        // VPIO requires BOTH buses of the audio unit to be connected (input
        // for the mic, output for the speaker reference signal). That's why
        // we attach a player node to mainMixerNode BEFORE enabling VPIO —
        // otherwise the output bus has nothing to render and the unit spams
        // `auou/vpio/appl, render err: -1` continuously.
        // -------------------------------------------------------------------

        // 1) Attach the streaming player BEFORE enabling VPIO so the engine
        //    has a complete output graph at the moment VPIO turns on.
        let outFormat = AVAudioFormat(
            standardFormatWithSampleRate: streamingOutputRate,
            channels: 1
        )
        if let outFormat = outFormat {
            let player = AVAudioPlayerNode()
            streamingPlayerNode = player
            streamingFormat = outFormat
            audioEngine.attach(player)
            audioEngine.connect(player, to: audioEngine.mainMixerNode, format: outFormat)
        }

        // 2) Enable VPIO on the input chain.
        do {
            try inputNode.setVoiceProcessingEnabled(true)
            print("✅ [RealtimeAudio] VPIO (hardware AEC + NS + AGC) enabled")
        } catch {
            print("⚠️ [RealtimeAudio] setVoiceProcessingEnabled failed: \(error.localizedDescription) — falling back to session-level AEC")
        }

        // Configure input format (mono, PCM, sample rate from init).
        // Use outputFormat(forBus: 0) because InputNode is a source.
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // CRITICAL: Check if format is valid to prevent crash.
        if inputFormat.sampleRate == 0 || inputFormat.channelCount == 0 {
            print("❌ [RealtimeAudio] Invalid input format: \(inputFormat). Retrying in 100ms...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.startRecording()
            }
            return
        }

        let recordingFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: channelCount,
            interleaved: false
        )

        guard let recordingFormat = recordingFormat else {
            print("❌ [RealtimeAudio] Failed to create recording format")
            return
        }

        // 3) Install tap on input node.
        let bufferSize: AVAudioFrameCount = 4096
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            if let convertedBuffer = self.convertBuffer(buffer, to: recordingFormat) {
                self.calculateAudioLevel(from: convertedBuffer)
                if let pcmData = self.bufferToPCMData(convertedBuffer) {
                    self.onAudioChunk?(pcmData)
                }
            }
        }

        // 4) Start engine + arm the streaming player so future schedule calls
        //    begin playing immediately.
        do {
            try audioEngine.start()
            streamingPlayerNode?.play()
            DispatchQueue.main.async { self.isRecording = true }
            print("✅ [RealtimeAudio] Recording started (engine + streaming player armed)")
        } catch {
            print("❌ [RealtimeAudio] Failed to start audio engine: \(error.localizedDescription)")
        }
    }

    // MARK: - Streaming PCM16 output (OpenAI Realtime)

    /// Schedule a 24 kHz PCM16-LE chunk on the streaming player node. Safe
    /// to call from anywhere — drops silently if the engine isn't running.
    func enqueueStreamingPCM16(_ pcm16: Data) {
        guard let player = streamingPlayerNode,
              let format = streamingFormat,
              audioEngine?.isRunning == true else {
            return
        }
        let sampleCount = pcm16.count / 2
        guard sampleCount > 0 else { return }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                            frameCapacity: AVAudioFrameCount(sampleCount)) else {
            return
        }
        buffer.frameLength = AVAudioFrameCount(sampleCount)
        guard let channel = buffer.floatChannelData?.pointee else { return }

        var sumSq: Float = 0
        pcm16.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            let ints = raw.bindMemory(to: Int16.self)
            for i in 0..<sampleCount {
                let f = Float(ints[i]) / Float(Int16.max)
                channel[i] = f
                sumSq += f * f
            }
        }
        let rms = sqrt(sumSq / Float(sampleCount))

        pendingStreamingChunks += 1
        DispatchQueue.main.async {
            self.streamingPlayerLevel = rms
            self.isPlaying = true
        }

        player.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.pendingStreamingChunks = max(0, self.pendingStreamingChunks - 1)
                if self.pendingStreamingChunks == 0 {
                    self.isPlaying = false
                    self.streamingPlayerLevel = 0.0
                    self.onStreamingDrained?()
                }
            }
        }
    }

    /// Drop all queued playback (mid-response barge-in).
    func flushStreaming() {
        guard let player = streamingPlayerNode else { return }
        player.stop()
        player.reset()
        pendingStreamingChunks = 0
        if audioEngine?.isRunning == true {
            player.play()  // re-arm for the next response
        }
        DispatchQueue.main.async {
            self.isPlaying = false
            self.streamingPlayerLevel = 0.0
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }

        print("🎤 [RealtimeAudio] Stopping recording")

        inputNode?.removeTap(onBus: 0)
        streamingPlayerNode?.stop()
        if let player = streamingPlayerNode, let engine = audioEngine {
            engine.detach(player)
        }
        streamingPlayerNode = nil
        streamingFormat = nil
        pendingStreamingChunks = 0
        // Disable VPIO before tearing down so the audio unit cleanly resets.
        try? inputNode?.setVoiceProcessingEnabled(false)
        audioEngine?.stop()
        audioEngine = nil
        inputNode = nil
        
        DispatchQueue.main.async {
            self.isRecording = false
            self.audioLevel = 0.0
        }
        
        print("✅ [RealtimeAudio] Recording stopped")
    }
    
    func playAudio(data: Data) {
        print("🔊 [RealtimeAudio] Playing audio: \(data.count) bytes")
        
        // 1. Stop Recording & Engine
        if isRecording {
            print("⏸️ [RealtimeAudio] Pausing recording for playback")
            shouldResumeRecording = true
            stopRecording()
        }
        
        // 2. Stop current playback
        if let player = audioPlayer, player.isPlaying {
            player.stop()
        }
        
        // 3. Configure Session for Playback
        // Switching to .playback ensures volume is high and routed to speaker
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            print("❌ [RealtimeAudio] Failed to set session for playback: \(error.localizedDescription)")
        }
        
        // 4. Initialize & Play
        do {
            // Backend sends MP3 audio from Yandex TTS
            // AVAudioPlayer can handle MP3 natively - no header manipulation needed
            // Only add WAV header if data is truly raw PCM (no known audio header)
            var audioData = data
            let headerPrefix = data.prefix(4)
            let headerStr = String(data: headerPrefix, encoding: .ascii) ?? ""

            // Check for known audio formats: RIFF (WAV), ID3/0xFF (MP3), fLaC, OggS
            let isMP3 = headerPrefix.count >= 2 && (
                (headerPrefix[headerPrefix.startIndex] == 0xFF && (headerPrefix[headerPrefix.index(after: headerPrefix.startIndex)] & 0xE0) == 0xE0) ||
                headerStr.hasPrefix("ID3")
            )
            let isKnownFormat = headerStr == "RIFF" || headerStr == "fLaC" || headerStr == "OggS" || isMP3

            if !isKnownFormat && data.count > 44 {
                print("⚠️ [RealtimeAudio] Unknown format, adding WAV header (48kHz)")
                audioData = addWavHeader(to: data, sampleRate: 48000)
            } else {
                print("✅ [RealtimeAudio] Detected known audio format, playing directly")
            }

            audioPlayer = try AVAudioPlayer(data: audioData)
            audioPlayer?.delegate = self
            audioPlayer?.volume = 1.0
            
            if audioPlayer?.prepareToPlay() == true {
                let success = audioPlayer?.play() ?? false
                if success {
                    DispatchQueue.main.async { self.isPlaying = true }
                    print("✅ [RealtimeAudio] Playback started (dur: \(String(format: "%.2f", audioPlayer?.duration ?? 0))s)")
                } else {
                    print("❌ [RealtimeAudio] Failed to play")
                    finishPlayback()
                }
            } else {
                print("❌ [RealtimeAudio] Failed to prepare")
                finishPlayback()
            }
        } catch {
            print("❌ [RealtimeAudio] Player init failed: \(error.localizedDescription)")
            finishPlayback()
        }
    }

    func stopPlayback() {
        audioPlayer?.stop()
        finishPlayback()
    }
    
    private func finishPlayback() {
        DispatchQueue.main.async {
            self.isPlaying = false
        }
        
        // Resume recording if needed
        if shouldResumeRecording {
            shouldResumeRecording = false
            print("▶️ [RealtimeAudio] Resuming recording after playback")
            
            // Switch back to Record category
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
                try session.setActive(true)
            } catch {
                print("❌ [RealtimeAudio] Failed to revert session to record: \(error.localizedDescription)")
            }
            
            startRecording()
        }
    }
    
    // Helper: Add WAV header to raw PCM data
    private func addWavHeader(to pcmData: Data, sampleRate: Int = 48000, channels: Int = 1, bitsPerSample: Int = 16) -> Data {
        var header = Data()
        
        let totalDataLen = pcmData.count
        let byteRate = sampleRate * channels * bitsPerSample / 8
        let blockAlign = channels * bitsPerSample / 8
        
        // RIFF chunk
        header.append(contentsOf: "RIFF".utf8)
        var chunkSize = Int32(36 + totalDataLen).littleEndian
        header.append(Data(bytes: &chunkSize, count: 4))
        header.append(contentsOf: "WAVE".utf8)
        
        // fmt chunk
        header.append(contentsOf: "fmt ".utf8)
        var subchunk1Size = Int32(16).littleEndian
        header.append(Data(bytes: &subchunk1Size, count: 4))
        var audioFormat = Int16(1).littleEndian // PCM
        header.append(Data(bytes: &audioFormat, count: 2))
        var numChannels = Int16(channels).littleEndian
        header.append(Data(bytes: &numChannels, count: 2))
        var sampleRate32 = Int32(sampleRate).littleEndian
        header.append(Data(bytes: &sampleRate32, count: 4))
        var byteRate32 = Int32(byteRate).littleEndian
        header.append(Data(bytes: &byteRate32, count: 4))
        var blockAlign16 = Int16(blockAlign).littleEndian
        header.append(Data(bytes: &blockAlign16, count: 2))
        var bitsPerSample16 = Int16(bitsPerSample).littleEndian
        header.append(Data(bytes: &bitsPerSample16, count: 2))
        
        // data chunk
        header.append(contentsOf: "data".utf8)
        var subchunk2Size = Int32(totalDataLen).littleEndian
        header.append(Data(bytes: &subchunk2Size, count: 4))
        
        return header + pcmData
    }
    
    private func convertBuffer(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let converter = AVAudioConverter(from: buffer.format, to: format) else {
            print("❌ [RealtimeAudio] Failed to create converter")
            return nil
        }
        
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * format.sampleRate / buffer.format.sampleRate)
        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else {
            print("❌ [RealtimeAudio] Failed to create converted buffer")
            return nil
        }
        
        var error: NSError?
        converter.convert(to: convertedBuffer, error: &error) { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        
        if let error = error {
            print("❌ [RealtimeAudio] Conversion error: \(error.localizedDescription)")
            return nil
        }
        
        return convertedBuffer
    }
    
    private func bufferToPCMData(_ buffer: AVAudioPCMBuffer) -> Data? {
        guard let channelData = buffer.int16ChannelData else {
            return nil
        }
        
        let frameCount = Int(buffer.frameLength)
        let channelDataPointer = channelData.pointee
        
        // Apply High-Pass Filter (DC Blocker)
        // y[n] = x[n] - x[n-1] + R * y[n-1]
        let R: Float = 0.95 // Cutoff around 120Hz at 16kHz
        
        for i in 0..<frameCount {
            let x = channelDataPointer[i]
            let y = Float(x) - Float(prevX) + R * prevY
            
            // Clamp and update
            let clampedY = min(max(y, -32768), 32767)
            channelDataPointer[i] = Int16(clampedY)
            
            prevX = x
            prevY = y
        }
        
        let dataSize = frameCount * MemoryLayout<Int16>.size
        return Data(bytes: channelDataPointer, count: dataSize)
    }
    
    // VAD Configuration
    private let silenceThreshold: Float = 0.03 // Increased from 0.01 to reduce noise sensitivity
    private let silenceDuration: TimeInterval = 1.2 // Increased from 0.8 to prevent cutting off too early
    private let minSpeechDuration: TimeInterval = 0.1 // Minimum duration to consider as speech
    
    private var silenceStartTime: Date?
    private var isSpeaking = false
    private var potentialSpeechDuration: TimeInterval = 0
    
    private func calculateAudioLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.int16ChannelData else { return }
        
        let channelDataPointer = channelData.pointee
        let frameLength = Int(buffer.frameLength)
        let duration = Double(frameLength) / buffer.format.sampleRate
        
        var sum: Float = 0.0
        for i in 0..<frameLength {
            let sample = Float(channelDataPointer[i]) / Float(Int16.max)
            sum += sample * sample
        }
        
        let rms = sqrt(sum / Float(frameLength))
        
        DispatchQueue.main.async {
            self.audioLevel = rms
            self.processVAD(level: rms, duration: duration)
        }
    }
    
    private func processVAD(level: Float, duration: TimeInterval) {
        if level > silenceThreshold {
            // Potential speech detected
            potentialSpeechDuration += duration
            
            if potentialSpeechDuration >= minSpeechDuration {
                if !isSpeaking {
                    isSpeaking = true
                    print("🗣️ [RealtimeAudio] Speech started (dur: \(String(format: "%.3f", potentialSpeechDuration))s, lvl: \(String(format: "%.3f", level)))")
                    onSpeechDetected?()
                }
                silenceStartTime = nil
            }
        } else {
            // Below threshold
            if !isSpeaking {
                // If we haven't triggered speech yet, reset the potential duration
                potentialSpeechDuration = 0
            } else {
                // We are speaking, check for silence timeout
                if silenceStartTime == nil {
                    silenceStartTime = Date()
                } else if let start = silenceStartTime, Date().timeIntervalSince(start) >= silenceDuration {
                    // Silence duration exceeded
                    print("🤫 [RealtimeAudio] Silence detected (end of utterance)")
                    isSpeaking = false
                    silenceStartTime = nil
                    potentialSpeechDuration = 0
                    onSilenceDetected?()
                }
            }
        }
    }
}

// MARK: - AVAudioPlayerDelegate
extension RealtimeAudioManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("✅ [RealtimeAudio] Audio playback finished")
        finishPlayback()
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("❌ [RealtimeAudio] Decode error: \(error?.localizedDescription ?? "unknown")")
        finishPlayback()
    }
}
