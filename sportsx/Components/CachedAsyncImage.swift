//
//  CachedAsyncImage.swift
//  sportsx
//
//  Created by 任杰 on 2025/6/10.
//

import SwiftUI

// 升级版asyncImage，主要用于频繁展示的小图像
struct CachedAsyncImage: View {
    @StateObject private var loader = ImageLoader()
    let urlString: String
    let placeholder: Image
    let errorImage: Image
    
    var body: some View {
        Group {
            if let uiImage = loader.image {
                Image(uiImage: uiImage)
                    .resizable()
            } else if loader.hasError {
                errorImage
                    .resizable()
            } else {
                placeholder
                    .resizable()
            }
        }
        .onFirstAppear {
            loader.load(from: urlString)
        }
    }
}
