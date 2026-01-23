//
//  AudioRecorder.swift
//  Salom-Ai-iOS
//
//  Created by Alijonov Shohruhmirzo on 22/11/25.
//

import Foundation
import AVFoundation
import Combine

final class AudioRecorder: NSObject, ObservableObject {
    private var audioRecorder: AVAudioRecorder?
    @Published var isRecording = false
    @Published var recordingURL: URL?
    @Published var audioLevel: Float = 0.0
    
    private var timer: Timer?
    
    override init() {
        super.init()
    }
    
    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    func startRecording() {
        let recordingSession = AVAudioSession.sharedInstance()
        
        do {
            try recordingSession.setCategory(.playAndRecord, mode: .default)
            try recordingSession.setActive(true)
            
            let docPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let audioFilename = docPath.appendingPathComponent("recording.m4a")
            
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 16000, // Standard for STT
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            
            DispatchQueue.main.async {
                self.isRecording = true
                self.recordingURL = nil
                self.startMonitoring()
            }
            
        } catch {
            print("Failed to start recording: \(error)")
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        stopMonitoring()
        DispatchQueue.main.async {
            self.isRecording = false
            self.recordingURL = self.audioRecorder?.url
            self.audioRecorder = nil
            self.audioLevel = 0.0
        }
    }
    
    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self, let recorder = self.audioRecorder else { return }
            recorder.updateMeters()
            // Normalize power (typically -160 to 0 dB) to 0.0 - 1.0
            let power = recorder.averagePower(forChannel: 0)
            let normalized = max(0.0, (power + 50) / 50) // Adjust range as needed
            self.audioLevel = normalized
        }
    }
    
    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
}

extension AudioRecorder: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            stopRecording()
        }
    }
}
