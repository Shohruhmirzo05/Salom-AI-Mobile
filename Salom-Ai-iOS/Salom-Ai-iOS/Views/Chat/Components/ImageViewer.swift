//
//  ImageViewer.swift
//  Salom-Ai-iOS
//
//  Created by Alijonov Shohruhmirzo on 24/11/25.
//

import SwiftUI
import Photos

struct ImageViewer: View {
    let url: URL
    let onClose: () -> Void
    
    @State private var isSaving = false
    @State private var saveStatus: String?
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Image
            CachedImage(imageUrl: url.absoluteString, contentMode: .fit)
                .ignoresSafeArea()
            
            // Controls Overlay
            VStack {
                // Top Bar
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white.opacity(0.8))
                            .background(Circle().fill(Color.black.opacity(0.2)))
                    }
                    Spacer()
                }
                .padding(.top, 50)
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Bottom Bar
                VStack(spacing: 16) {
                    if let saveStatus {
                        Text(saveStatus)
                            .font(.footnote)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                            .transition(.opacity)
                    }
                    
                    HStack(spacing: 20) {
                        ShareLink(item: url) {
                            VStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 24))
                                Text("Ulashish")
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.ultraThinMaterial)
                            .cornerRadius(16)
                        }
                        
                        Button {
                            Task { await saveToPhotos() }
                        } label: {
                            VStack(spacing: 4) {
                                if isSaving {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "arrow.down.circle")
                                        .font(.system(size: 24))
                                }
                                Text("Saqlash")
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.ultraThinMaterial)
                            .cornerRadius(16)
                        }
                    }
                    .foregroundColor(.white)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .statusBar(hidden: true)
    }
    
    private func saveToPhotos() async {
        isSaving = true
        defer { isSaving = false }
        
        do {
            let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
            if status == .notDetermined {
                let granted = await PHPhotoLibrary.requestAuthorization(for: .addOnly) == .authorized
                if !granted {
                    saveStatus = "Galereyaga saqlash uchun ruxsat kerak."
                    return
                }
            } else if status == .denied || status == .restricted || status == .limited {
                saveStatus = "Galereyaga saqlash uchun ruxsat kerak."
                return
            }
            
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else {
                saveStatus = "Rasmni ochib bo'lmadi."
                return
            }
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            saveStatus = "Galereyaga saqlandi ✅"
            
            // Hide status after 2 seconds
            try? await Task.sleep(nanoseconds: 2 * 1_000_000_000)
            saveStatus = nil
        } catch {
            saveStatus = "Saqlashda xatolik"
        }
    }
}
