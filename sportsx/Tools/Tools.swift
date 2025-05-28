//
//  Tools.swift
//  sportsx
//
//  Created by 任杰 on 2024/9/13.
//

import Foundation
import CoreLocation
import SwiftUI

struct CoordinateConverter {
    
    // 判断是否在中国境内
    private static func outOfChina(lat: Double, lon: Double) -> Bool {
        return !(lon > 73.66 && lon < 135.05 && lat > 3.86 && lat < 53.55)
    }

    // 转换函数
    private static func transform(lat: Double, lon: Double) -> (lat: Double, lon: Double) {
        let pi = 3.14159265358979324
        let a = 6378245.0
        let ee = 0.00669342162296594323

        var dLat = transformLat(x: lon - 105.0, y: lat - 35.0)
        var dLon = transformLon(x: lon - 105.0, y: lat - 35.0)
        let radLat = lat / 180.0 * pi
        var magic = sin(radLat)
        magic = 1 - ee * magic * magic
        let sqrtMagic = sqrt(magic)
        dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * pi)
        dLon = (dLon * 180.0) / (a / sqrtMagic * cos(radLat) * pi)
        return (lat: dLat, lon: dLon)
    }

    private static func transformLat(x: Double, y: Double) -> Double {
        var ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * 3.14159265358979324) + 20.0 * sin(2.0 * x * 3.14159265358979324)) * 2.0 / 3.0
        ret += (20.0 * sin(y * 3.14159265358979324) + 40.0 * sin(y / 3.0 * 3.14159265358979324)) * 2.0 / 3.0
        ret += (160.0 * sin(y / 12.0 * 3.14159265358979324) + 320 * sin(y * 3.14159265358979324 / 30.0)) * 2.0 / 3.0
        return ret
    }

    private static func transformLon(x: Double, y: Double) -> Double {
        var ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * 3.14159265358979324) + 20.0 * sin(2.0 * x * 3.14159265358979324)) * 2.0 / 3.0
        ret += (20.0 * sin(x * 3.14159265358979324) + 40.0 * sin(x / 3.0 * 3.14159265358979324)) * 2.0 / 3.0
        ret += (150.0 * sin(x / 12.0 * 3.14159265358979324) + 300.0 * sin(x / 30.0 * 3.14159265358979324)) * 2.0 / 3.0
        return ret
    }

    // WGS-84 转 GCJ-02
    static func wgs84ToGcj02(lat: Double, lon: Double) -> CLLocationCoordinate2D {
        if outOfChina(lat: lat, lon: lon) {
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        let d = transform(lat: lat, lon: lon)
        let gcjLat = lat + d.lat
        let gcjLon = lon + d.lon
        return CLLocationCoordinate2D(latitude: gcjLat, longitude: gcjLon)
    }
    
    // GCJ-02 转 WGS-84
    static func gcj02ToWgs84(lat: Double, lon: Double) -> CLLocationCoordinate2D {
        if outOfChina(lat: lat, lon: lon) {
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        let d = transform(lat: lat, lon: lon)
        let wgsLat = lat - d.lat
        let wgsLon = lon - d.lon
        return CLLocationCoordinate2D(latitude: wgsLat, longitude: wgsLon)
    }
}

struct TimeDisplay {
    static func formattedTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02dm %02ds", minutes, seconds)
    }
}

struct AgeDisplay {
    static func calculateAge(from birthDateString: String) -> Int? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        guard let birthDate = dateFormatter.date(from: birthDateString) else {
            return nil // 解析失败
        }

        let calendar = Calendar.current
        let now = Date()
        let ageComponents = calendar.dateComponents([.year], from: birthDate, to: now)
        return ageComponents.year
    }
}

// MARK: - asyncImage支持拿到UIImage并处理
struct AsyncImageWithColorExtraction: View {
    let url: URL?
    let onImageLoaded: (UIImage) -> Void
    let placeholder: Image

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
                    .onAppear {
                        extractUIImage(from: image, completion: onImageLoaded)
                    }
            case .failure(_):
                placeholder
                    .resizable()
                    .scaledToFill()
                    .onAppear {
                        extractUIImage(from: placeholder, completion: onImageLoaded)
                    }
            case .empty:
                placeholder
                    .resizable()
                    .scaledToFill()
                    .onAppear {
                        extractUIImage(from: placeholder, completion: onImageLoaded)
                    }
            @unknown default:
                placeholder
                    .resizable()
                    .scaledToFill()
                    .onAppear {
                        extractUIImage(from: placeholder, completion: onImageLoaded)
                    }
            }
        }
    }

    private func extractUIImage(from image: Image, completion: @escaping (UIImage) -> Void) {
        let renderer = ImageRenderer(content: image)
        if let uiImage = renderer.uiImage {
            completion(uiImage)
        }
    }
}

struct ColorComputer {
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
