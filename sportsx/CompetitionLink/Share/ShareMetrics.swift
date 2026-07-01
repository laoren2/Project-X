//
//  ShareMetrics.swift
//  sportsx
//
//  运动结算分享图所需的「运动无关」通用数据模型。
//  由各结算页根据 basePath / 结算信息计算后传入分享编辑器。
//

import Foundation
import CoreLocation

// 可叠加到分享图上的元素类型（logo 之外的指标元素用户可自选添加）
enum ShareElementKind: String, CaseIterable, Identifiable {
    case track          // 平滑后的轨迹路径
    case sportIcon      // 运动种类图标（bike / running）
    case duration       // 运动时间
    case pace           // 平均配速 / 均速（按运动自适应）
    case heartRate      // 平均心率
    case elevationGain  // 累计海拔爬升
    case cadence        // 骑行踏频 / 跑步步频（标签按运动自适应）
    case logo           // App Logo（Movmov）

    var id: String { rawValue }

    // 元素开关 chip 的标题
    var titleKey: String {
        switch self {
        case .track:         return "share.element.track"
        case .sportIcon:     return "share.element.sport"
        case .duration:      return "share.element.duration"
        case .pace:          return "share.element.pace"
        case .heartRate:     return "share.element.heart_rate"
        case .elevationGain: return "share.element.elevation_gain"
        case .cadence:       return "share.element.pedal_cadence"   // 默认踏频，UI 层按运动覆盖为步频
        case .logo:          return "share.element.logo"
        }
    }

    var iconName: String {
        switch self {
        case .track:         return "point.topleft.down.curvedto.point.bottomright.up"
        case .sportIcon:     return "figure.run"
        case .duration:      return "clock"
        case .pace:          return "speedometer"
        case .heartRate:     return "heart.fill"
        case .elevationGain: return "arrowtriangle.up.fill"
        case .cadence:       return "pedalCadence"
        case .logo:          return "single_app_icon"
        }
    }
}

struct ShareMetrics {
    let sport: SportName
    /// 按活动段（segment）分组的原始轨迹坐标：段间为暂停缺口，绘制时各段独立、绝不跨段连线。
    /// race/route 恒为单段；free training 暂停后会拆成多段。
    let coordinateSegments: [[CLLocationCoordinate2D]]
    let duration: TimeInterval                  // 运动时间（秒）
    let distanceMeters: Double                  // 总距离（米）
    let avgSpeedKmh: Double                     // 平均速度（km/h）
    let avgHeartRate: Double?                   // 平均心率（bpm），无则不可添加
    let elevationGain: Double                   // 累计爬升（米）
    let avgCadence: Double?                     // 骑行=平均踏频(rpm) / 跑步=平均步频(spm)，无则不可添加

    /// 展平后的全部坐标（地图取景、可用性判断等不关心分段处用）
    var coordinates: [CLLocationCoordinate2D] { coordinateSegments.flatMap { $0 } }

    // 跑步显示配速（/km），其余显示均速（km/h）
    var isPaceSport: Bool { sport == .Running }

    var durationText: String { TimeDisplay.formattedTime(duration) }

    var paceOrSpeedText: String {
        if isPaceSport {
            return SpeedHelper.paceString(from: avgSpeedKmh)
        } else {
            return String(format: "%.1f", avgSpeedKmh)
        }
    }

    // 配速/均速单位（跑步 /km，其余 km/h）
    var paceOrSpeedUnitKey: String { isPaceSport ? "/km" : "speed.km/h" }

    var heartRateText: String {
        guard let hr = avgHeartRate else { return "--" }
        return "\(Int(hr))"
    }

    var elevationGainText: String { String(format: "%.0f", elevationGain) }

    // 是否有有效心率（无则该元素不可添加）
    var hasHeartRate: Bool { avgHeartRate != nil }

    // 踏频 / 步频（按运动自适应标签与单位）
    var hasCadence: Bool { avgCadence != nil }
    var cadenceText: String {
        guard let c = avgCadence else { return "--" }
        return "\(Int(c.rounded()))"
    }
    // 跑步显示步频、其余显示踏频
    var cadenceLabelKey: String { sport == .Running ? "share.element.step_cadence" : "share.element.pedal_cadence" }
    var cadenceUnitKey: String { sport == .Running ? "stepCadence.unit" : "pedalCadence.unit" }
    var cadenceImageName: String { sport == .Running ? "stepCadence" : "pedalCadence" }
}

extension ShareMetrics {
    /// 从基础轨迹点构建通用指标
    static func make(sport: SportName, basePath: [PathPoint], avgCadence: Double? = nil) -> ShareMetrics {
        // 按 segment 分组：相邻点 segment 不同即开启新段（暂停缺口），绘制时各段独立不连线。
        var segments: [[CLLocationCoordinate2D]] = []
        var prevSegment: Int? = nil
        for p in basePath {
            let coord = CLLocationCoordinate2D(latitude: p.lat, longitude: p.lon)
            if p.segment == prevSegment, !segments.isEmpty {
                segments[segments.count - 1].append(coord)
            } else {
                segments.append([coord])
            }
            prevSegment = p.segment
        }

        // 距离 & 时长 & 爬升：段感知，跨 segment（暂停缺口）的弦一律不计。
        // race/route 单段（segment 恒为 0），行为与原先一致。
        var distance: Double = 0
        var duration: TimeInterval = 0
        var gain: Double = 0
        for i in 0..<max(basePath.count - 1, 0) {
            let p1 = basePath[i], p2 = basePath[i + 1]
            guard p1.segment == p2.segment else { continue }
            distance += GeographyTool.haversineDistance(lat1: p1.lat, lon1: p1.lon, lat2: p2.lat, lon2: p2.lon)
            duration += max(p2.timestamp - p1.timestamp, 0)
            let delta = p2.altitude - p1.altitude
            if delta > 0.5 { gain += delta }
        }
        let avgSpeedKmh = duration > 0 ? (distance / duration) * 3.6 : 0

        // 平均心率
        let hrs = basePath.compactMap { $0.heart_rate }
        let avgHR: Double? = hrs.isEmpty ? nil : hrs.reduce(0, +) / Double(hrs.count)

        return ShareMetrics(
            sport: sport,
            coordinateSegments: segments,
            duration: duration,
            distanceMeters: distance,
            avgSpeedKmh: avgSpeedKmh,
            avgHeartRate: avgHR,
            elevationGain: gain,
            avgCadence: avgCadence
        )
    }
}
