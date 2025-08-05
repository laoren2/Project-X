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

struct DateDisplay {
    static func formattedDate(_ date: Date?) -> String {
        guard let date = date else {
            return "未知"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        formatter.locale = Locale(identifier: "zh_CN")
        
        return formatter.string(from: date)
    }
}

struct TimeDisplay {
    static func formattedTime(_ interval: TimeInterval?, showFraction: Bool = false) -> String {
        guard let duration = interval else { return "未知" }
        
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        let fraction = duration - Double(totalSeconds)
        
        if showFraction {
            let fractionalSeconds = Double(seconds) + fraction
            if hours > 0 {
                return String(format: "%02d:%02d:%05.2f", hours, minutes, fractionalSeconds)
            } else {
                return String(format: "%02d:%05.2f", minutes, fractionalSeconds)
            }
        } else {
            if hours > 0 {
                return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
            } else {
                return String(format: "%02d:%02d", minutes, seconds)
            }
        }
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


