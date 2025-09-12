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
        guard let duration = interval else { return "无数据" }
        
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

// MARK: - 通用的 JSON 枚举类型，可表示任意 JSON 结构
enum JSONValue: Codable {
    case string(String)
    case number(Double)
    case object([String: JSONValue])
    case array([JSONValue])
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if container.decodeNil() {
            self = .null
        } else {
            throw DecodingError.typeMismatch(
                JSONValue.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported JSON type")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .number(let v): try container.encode(v)
        case .object(let v): try container.encode(v)
        case .array(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        case .null: try container.encodeNil()
        }
    }
}

// 便捷取值方法
extension JSONValue {
    var stringValue: String? {
        if case .string(let v) = self { return v }
        return nil
    }
    
    var doubleValue: Double? {
        if case .number(let v) = self { return v }
        return nil
    }
    
    var intValue: Int? {
        if case .number(let v) = self { return Int(v) }
        return nil
    }
    
    var boolValue: Bool? {
        if case .bool(let v) = self { return v }
        return nil
    }
    
    var objectValue: [String: JSONValue]? {
        if case .object(let v) = self { return v }
        return nil
    }
    
    var arrayValue: [JSONValue]? {
        if case .array(let v) = self { return v }
        return nil
    }
    
    // 从嵌套路径里取值（支持多级 key）
    subscript(path: String...) -> JSONValue? {
        /*var current: JSONValue? = self
         for key in path {
         if case .object(let dict)? = current {
         current = dict[key]
         } else {
         return nil
         }
         }
         return current*/
        return self.value(for: path)
    }
    
    func value(for keys: [String]) -> JSONValue? {
        var current = self
        for key in keys {
            if case .object(let dict) = current, let next = dict[key] {
                current = next
            } else {
                return nil
            }
        }
        return current
    }
    
    mutating func applyingMultiplier(for paths: [[String]], multiplier: Double) {
        for path in paths {
            self = self.updateValue(at: path) { old in
                if case .number(let v) = old {
                    return .number(v * multiplier)
                } else {
                    return old
                }
            }
        }
    }
    
    // 递归更新 JSONValue 中的某个路径
    private func updateValue(at path: [String], transform: (JSONValue) -> JSONValue) -> JSONValue {
        guard let first = path.first else { return self }
        
        switch self {
        case .object(var dict):
            if path.count == 1 {
                if let old = dict[first] {
                    dict[first] = transform(old)
                }
            } else if let nested = dict[first] {
                dict[first] = nested.updateValue(at: Array(path.dropFirst()), transform: transform)
            }
            return .object(dict)
        default:
            return self
        }
    }
    
    // 将 JSONValue 转成 JSON 字符串
    func toJSONString(prettyPrinted: Bool = true) -> String? {
        let encoder = JSONEncoder()
        if prettyPrinted {
            encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        } else {
            encoder.outputFormatting = [.withoutEscapingSlashes]
        }
        do {
            let data = try encoder.encode(self)
            return String(data: data, encoding: .utf8)
        } catch {
            print("JSONValue 转字符串失败: \(error)")
            return nil
        }
    }
}
