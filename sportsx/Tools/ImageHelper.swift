//
//  ImageHelper.swift
//  sportsx
//
//  Created by 任杰 on 2025/6/10.
//

import SwiftUI

// 图片加载器
class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var hasError: Bool = false
    
    private var task: URLSessionDataTask?
    private let maxRetryCount = 3
    private var retryCount = 0
    
    func load(from urlString: String) {
        guard image == nil else { return }
        guard let url = URL(string: NetworkService.baseDomain + urlString) else { return }
        
        loadImage(from: url)
    }
    
    private func loadImage(from url: URL) {
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 5)
        
        task = URLSession.shared.dataTask(with: request) { [weak self] data, response, _ in
            guard let self = self else { return }
            
            if let data = data, let uiImage = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.image = uiImage
                    self.hasError = false
                }
            } else {
                self.retryOrFail(url: url)
            }
        }
        task?.resume()
    }
    
    private func retryOrFail(url: URL) {
        retryCount += 1
        if retryCount <= maxRetryCount {
            DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                self.loadImage(from: url)
            }
        } else {
            DispatchQueue.main.async {
                self.hasError = true
            }
        }
    }
    
    func cancel() {
        task?.cancel()
    }
}

struct ImageTool {
    // 图片压缩(jpeg格式)
    static func compressImage(_ image: UIImage, maxSizeKB: Int = 300) -> Data? {
        var compression: CGFloat = 1.0
        let maxBytes = maxSizeKB * 1024
        guard var data = image.jpegData(compressionQuality: compression) else { return nil }

        while data.count > maxBytes && compression > 0.1 {
            compression -= 0.1
            if let newData = image.jpegData(compressionQuality: compression) {
                data = newData
            } else {
                break
            }
            print("size: \(data.count) compression: \(compression)")
        }
        return data
    }
    
    // 计算图片的平均颜色
    static func averageColor(from image: UIImage) -> UIColor? {
        guard let ciImage = CIImage(image: image) else { return nil }
        let extent = ciImage.extent
        let context = CIContext()
        let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: ciImage,
            kCIInputExtentKey: CIVector(cgRect: extent)
        ])!
        
        guard let outputImage = filter.outputImage else { return nil }
        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(outputImage,
                       toBitmap: &bitmap,
                       rowBytes: 4,
                       bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBA8,
                       colorSpace: CGColorSpaceCreateDeviceRGB())
        
        return UIColor(
            red: CGFloat(bitmap[0]) / 255.0,
            green: CGFloat(bitmap[1]) / 255.0,
            blue: CGFloat(bitmap[2]) / 255.0,
            alpha: 1.0
        )
    }
}
