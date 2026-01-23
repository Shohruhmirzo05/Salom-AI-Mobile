//
//  CachedImage.swift
//  Salom-Ai-iOS
//
//  Created by Shohruhmirzo Alijonov on 13/12/24.
//

import SwiftUI
import Kingfisher

struct CachedImage: View {
    
    let imageUrl: URL?
    let contentMode: SwiftUI.ContentMode
    
    init(imageUrl: String, contentMode: SwiftUI.ContentMode = .fill, expiration: StorageExpiration = .days(1)) {
        self.imageUrl = URL(string: imageUrl)
        self.contentMode = contentMode
    }
    
    @State private var loadFailed: Bool = false
    @State private var isLoading: Bool = true
    
    var body: some View {
        Group {
            if let url = imageUrl {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            Rectangle()
                                .fill(Color.white.opacity(0.1))
                                .shimmering(active: true)
                        }
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: contentMode)
                    case .failure(let error):
                        ZStack {
                            Color.white.opacity(0.05)
                            Image(systemName: "photo.badge.exclamationmark")
                                .foregroundColor(.white.opacity(0.3))
                                .font(.system(size: 24))
                        }
                        .onAppear {
                            print("❌ Image load failed: \(error)")
                        }
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                ZStack {
                    Color.white.opacity(0.05)
                    Image(systemName: "photo.badge.exclamationmark")
                        .foregroundColor(.white.opacity(0.3))
                        .font(.system(size: 24))
                }
            }
        }
        .background(Color.white.opacity(0.05))
    }
}
