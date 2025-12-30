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
    // 图片压缩(jpeg格式)，二分法调整压缩比例，必要时缩小分辨率
    static func compressImage(_ image: UIImage, maxSizeKB: Int = 300) -> Data? {
        var resizedImage: UIImage = image
        let maxBytes = maxSizeKB * 1024
        var compression: CGFloat = 1.0
        guard var data = image.jpegData(compressionQuality: compression) else { return nil }
        //print("原始大小: \(data.count)")
        
        if data.count <= maxBytes {
            return data
        }
        
        // 压缩
        var resize: CGFloat = 1 - 0.05 * min(CGFloat(data.count / maxBytes), 10)
        while resize >= 0.1 {
            if let resized = resizeImage(resizedImage, scale: resize) {
                resizedImage = resized
                compression = 1.0
                while compression >= 0.1 {
                    //print("\(resize) \(compression) \(data.count) \(maxBytes)")
                    compression -= 0.2
                    if let newData = resizedImage.jpegData(compressionQuality: compression) {
                        data = newData
                        if data.count <= maxBytes {
                            return data
                        }
                    } else {
                        break
                    }
                }
                resize -= 0.2
            } else {
                break
            }
        }
        return data
    }

    // 按比例缩小图像
    private static func resizeImage(_ image: UIImage, scale: CGFloat) -> UIImage? {
        // 避免非整数像素尺寸导致的边缘取样问题
        let width = floor(image.size.width * scale)
        let height = floor(image.size.height * scale)
        guard width > 0, height > 0 else { return nil }
        let newSize = CGSize(width: width, height: height)
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        // 如果源图是 JPEG（无 alpha），使用 opaque=true 可避免白边
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        let resizedImage = renderer.image { ctx in
            ctx.cgContext.interpolationQuality = .high
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resizedImage
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
