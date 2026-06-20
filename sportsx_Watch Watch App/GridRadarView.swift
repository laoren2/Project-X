//
//  GridRadarView.swift
//  sportsx_Watch Watch App
//
//  free training 雷达指引：圆形雷达背景 + 指向最近 buff 奖励网格的箭头 + 距离。
//  方位/距离由手表本地 GPS + 朝向实时计算。
//

import SwiftUI
import CoreLocation

struct GridRadarView: View {
    let grids: [WatchGrid]
    let userLocation: CLLocation?
    let headingDegrees: Double      // 设备朝向（真北 0°，顺时针），雷达「上方」= 该方向

    private let maxRange: Double = 1000   // 雷达最远显示距离（米），超出夹到边缘

    // MARK: - 抽象雷达
    var body: some View {
        GeometryReader { geo in
            let radius = min(geo.size.width, geo.size.height) / 2 - 4
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            ZStack {
                // 同心环 + 径向渐变（运动感）
                Circle()
                    .fill(RadialGradient(colors: [Color.orange.opacity(0.15), .clear],
                                         center: .center, startRadius: 0, endRadius: radius))
                ForEach(1...3, id: \.self) { i in
                    Circle()
                        .stroke(Color.orange.opacity(0.18), lineWidth: 1)
                        .frame(width: radius * 2 * CGFloat(i) / 3,
                               height: radius * 2 * CGFloat(i) / 3)
                }
                // 奖励网格指示
                ForEach(markers(center: center, radius: radius)) { marker in
                    rewardMarker(marker)
                        .position(marker.point)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private func rewardMarker(_ marker: GridMarker) -> some View {
        VStack(spacing: 1) {
            if marker.inRange {
                // 范围内：真实点位上显示 reward 图标 + 金色光晕
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [Color.yellow.opacity(0.35), .clear],
                                             center: .center, startRadius: 1, endRadius: 10))
                        .frame(width: 20, height: 20)
                    Image(Self.rewardIconName(marker.reward))
                        .resizable()
                        .scaledToFit()
                        .frame(height: 16)
                }
            } else {
                // 范围外：边缘箭头指向网格方向（雷达上方=朝向）
                Image(systemName: "location.north.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.orange)
                    .rotationEffect(.degrees(marker.angle))
            }
            Text(marker.distanceText)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white)
                .lineLimit(1)
        }
    }

    // MARK: - 方位/距离计算
    private struct GridMarker: Identifiable {
        let id: String
        let point: CGPoint
        let angle: Double        // 相对朝向的方位角（度，顺时针，0=正上）
        let distanceText: String
        let inRange: Bool        // distance < maxRange：在雷达范围内
        let reward: String
    }

    private func markers(center: CGPoint, radius: CGFloat) -> [GridMarker] {
        guard let user = userLocation else { return [] }
        return grids.map { grid in
            let target = CLLocation(latitude: grid.lat, longitude: grid.lon)
            let distance = user.distance(from: target)
            let bearing = Self.bearing(from: user.coordinate, to: target.coordinate)
            let relative = (bearing - headingDegrees).truncatingRemainder(dividingBy: 360)
            let rad = relative * .pi / 180
            // 真实归一化位置（不再加下限）；范围外夹到 0.9R 边缘留出标记空间
            let norm = min(max(distance / maxRange, 0), 1)
            let r = radius * CGFloat(min(norm, 0.9))
            let point = CGPoint(x: center.x + r * CGFloat(sin(rad)),
                                y: center.y - r * CGFloat(cos(rad)))
            return GridMarker(id: grid.id, point: point, angle: relative,
                              distanceText: Self.distanceText(distance),
                              inRange: distance < maxRange, reward: grid.reward)
        }
    }

    // reward_type → 手表资源图标名（与手机 CCAssetType.iconName 对齐）
    private static func rewardIconName(_ reward: String) -> String {
        switch reward {
        case "coupon": return "coupon"
        case "voucher": return "voucher"
        case "stone1": return "green_stone"
        case "stone2": return "blue_stone"
        case "stone3": return "red_stone"
        default: return "coin"
        }
    }

    private static func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    private static func distanceText(_ meters: Double) -> String {
        meters < 1000
            ? "\(Int(meters.rounded()))m"
            : String(format: "%.1fkm", meters / 1000)
    }
}
