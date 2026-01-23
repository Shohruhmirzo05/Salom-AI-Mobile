//
//  RealtimeVisualizerView.swift
//  Salom-Ai-iOS
//
//  Created by Salom AI on 27/11/25.
//

import SwiftUI

struct RealtimeVisualizerView: View {
    let audioLevel: Float
    let state: RealtimeVoiceState
    
    @State private var breathingPhase: CGFloat = 0.0
    
    var body: some View {
        ZStack {
            // Background glow
            Circle()
                .fill(stateColor.opacity(0.2))
                .frame(width: 200, height: 200)
                .scaleEffect(1 + CGFloat(audioLevel) * 2)
                .blur(radius: 20)
            
            // Outer ripple 1
            Circle()
                .stroke(stateColor.opacity(0.3), lineWidth: 1)
                .frame(width: 180, height: 180)
                .scaleEffect(1 + CGFloat(audioLevel) * 2.5)
                .opacity(0.4)
            
            // Outer ripple 2
            Circle()
                .stroke(stateColor.opacity(0.2), lineWidth: 1)
                .frame(width: 220, height: 220)
                .scaleEffect(1 + CGFloat(audioLevel) * 3.0)
                .opacity(0.3)

            // Middle ripple
            Circle()
                .stroke(stateColor.opacity(0.4), lineWidth: 2)
                .frame(width: 160, height: 160)
                .scaleEffect(1 + CGFloat(audioLevel) * 1.5)
                .opacity(0.5)
            
            // Core circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [stateColor, stateColor.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)
                .scaleEffect(1 + CGFloat(audioLevel) * 0.8) // Smoother core scaling
                .shadow(color: stateColor.opacity(0.5), radius: 10 + CGFloat(audioLevel) * 10, x: 0, y: 0)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            
            // Icon
            Image(systemName: stateIcon)
                .font(.system(size: 40))
                .foregroundColor(.white)
                .opacity(0.9)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: audioLevel)
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                breathingPhase = 1.0
            }
        }
    }
    
    private var stateColor: Color {
        switch state {
        case .idle: return .gray
        case .listening: return .blue
        case .transcribing: return .purple
        case .thinking: return .orange
        case .speaking: return .green
        }
    }
    
    private var stateIcon: String {
        switch state {
        case .idle: return "mic.slash"
        case .listening: return "mic"
        case .transcribing: return "waveform"
        case .thinking: return "brain"
        case .speaking: return "speaker.wave.2"
        }
    }
}
