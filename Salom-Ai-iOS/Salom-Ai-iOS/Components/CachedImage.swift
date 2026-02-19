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

    init(imageUrl: String, contentMode: SwiftUI.ContentMode = .fill, expiration: StorageExpiration = .days(7)) {
        self.imageUrl = URL(string: imageUrl)
        self.contentMode = contentMode
    }

    var body: some View {
        if let url = imageUrl {
            KFImage(url)
                .placeholder {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .shimmering(active: true)
                }
                .onFailure { error in
                    print("❌ Image load failed: \(error.localizedDescription)")
                }
                .retry(maxCount: 3, interval: .seconds(2))
                .cacheMemoryOnly(false)
                .fade(duration: 0.25)
                .resizable()
                .aspectRatio(contentMode: contentMode)
        } else {
            ZStack {
                Color.white.opacity(0.05)
                Image(systemName: "photo.badge.exclamationmark")
                    .foregroundColor(.white.opacity(0.3))
                    .font(.system(size: 24))
            }
        }
    }
}
