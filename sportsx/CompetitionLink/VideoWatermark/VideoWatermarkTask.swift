//
//  VideoWatermarkTask.swift
//  sportsx
//
//  本地视频水印任务的可持久化模型。任务创建后保存运动快照，重试不依赖网络。
//

import Foundation
import CoreGraphics
import Photos

enum VideoWatermarkRecordKind: String, Codable {
    case race
    case freeTraining
    case routeTraining
}

enum VideoWatermarkTaskStatus: String, Codable, CaseIterable {
    case waiting
    case processing
    case paused
    case succeeded
    case failed

    var isActive: Bool { self == .waiting || self == .processing || self == .paused }
    var isTerminal: Bool { self == .succeeded || self == .failed }
}

enum VideoWatermarkTaskStage: String, Codable {
    case preparingSource
    case downloadingSource
    case generating
}

enum VideoWatermarkOutputResolution: Int, Codable, CaseIterable, Identifiable {
    case p720 = 720
    case p1080 = 1080
    case p2k = 1440
    case p4k = 2160

    var id: Int { rawValue }
    var displayTitle: String {
        switch self {
        case .p720: return "720p"
        case .p1080: return "1080p"
        case .p2k: return "2K"
        case .p4k: return "4K"
        }
    }
    var longEdge: CGFloat { CGFloat(rawValue) * 16 / 9 }
    var requiresVip: Bool { self == .p2k || self == .p4k }
}

enum VideoWatermarkOutputFrameRate: Int, Codable, CaseIterable, Identifiable {
    case fps30 = 30
    case fps60 = 60

    var id: Int { rawValue }
    var displayTitle: String { "\(rawValue)fps" }
    var requiresVip: Bool { self == .fps60 }

    /// 兼容 NTSC 标准帧率：29.97 与 59.94/59.97 分别视为 30、60fps 档位。
    var minimumInputFrameRate: Double {
        switch self {
        case .fps30: return 29.5
        case .fps60: return 59.5
        }
    }
}

enum VideoWatermarkOutputDynamicRange: String, Codable, CaseIterable, Identifiable {
    case sdr
    case hdr

    var id: String { rawValue }
    var displayTitle: String { rawValue.uppercased() }
    var requiresVip: Bool { self == .hdr }
}

struct VideoWatermarkOutputFormat: Codable, Equatable {
    var resolution: VideoWatermarkOutputResolution
    var frameRate: VideoWatermarkOutputFrameRate
    var dynamicRange: VideoWatermarkOutputDynamicRange
}

/// 相册资源的持久化引用。任务创建时只保存这组小型元数据，原片在真正处理前再写入任务目录。
struct VideoWatermarkPhotoAssetReference: Codable, Equatable {
    let localIdentifier: String
    let resourceTypeRawValue: Int
    let originalFilename: String

    var sourceExtension: String {
        let ext = (originalFilename as NSString).pathExtension.lowercased()
        return ext.isEmpty ? "mov" : ext
    }
}

enum VideoWatermarkMetric: String, Codable, CaseIterable, Identifiable {
    case route
    case speed
    case altitude
    case heartRate
    case logo

    var id: String { rawValue }
    var titleKey: String {
        switch self {
        case .route: return "video_watermark.metric.route"
        case .speed: return "video_watermark.metric.speed"
        case .altitude: return "video_watermark.metric.altitude"
        case .heartRate: return "video_watermark.metric.heart_rate"
        case .logo: return "video_watermark.metric.logo"
        }
    }
    var iconName: String {
        switch self {
        case .route: return "point.topleft.down.to.point.bottomright.curvepath"
        case .speed: return "speedometer"
        case .altitude: return "triangle.fill"
        case .heartRate: return "heart.fill"
        case .logo: return "single_app_icon"
        }
    }
}

/// 归一化布局可在不同视频分辨率、横竖屏导出间保持一致。
struct VideoWatermarkLayout: Codable, Equatable {
    var x: Double
    var y: Double
    var scale: Double

    // 实际 scale 在导入视频后由 VideoWatermarkScalePolicy 根据封面画布尺寸计算。
    static let route = VideoWatermarkLayout(x: 0.5, y: 0.2, scale: 1)
    static let speed = VideoWatermarkLayout(x: 0.5, y: 0.77, scale: 1)
    static let altitude = VideoWatermarkLayout(x: 0.5, y: 0.87, scale: 1)
    static let heartRate = VideoWatermarkLayout(x: 0.5, y: 0.67, scale: 1)
    static let logo = VideoWatermarkLayout(x: 0.5, y: 0.94, scale: 1)
}

struct VideoWatermarkMotionPoint: Codable, Identifiable {
    var id: Double { timestamp }
    let lat: Double
    let lon: Double
    let speed: Double
    let altitude: Double
    let heartRate: Double?
    let timestamp: TimeInterval
}

struct VideoWatermarkWorkoutSnapshot: Codable {
    let recordID: String
    let sport: SportName
    let kind: VideoWatermarkRecordKind
    let points: [VideoWatermarkMotionPoint]

    init(recordID: String, sport: SportName, kind: VideoWatermarkRecordKind, basePath: [PathPoint]) {
        self.recordID = recordID
        self.sport = sport
        self.kind = kind
        self.points = basePath.map {
            VideoWatermarkMotionPoint(lat: $0.lat, lon: $0.lon, speed: $0.speed, altitude: $0.altitude, heartRate: $0.heart_rate, timestamp: $0.timestamp)
        }
    }

    var startTime: TimeInterval? { points.first?.timestamp }
    var endTime: TimeInterval? { points.last?.timestamp }
    var hasHeartRate: Bool { points.contains { $0.heartRate != nil } }
}

final class VideoWatermarkEditorStore: NavigationStore {
    let workout: VideoWatermarkWorkoutSnapshot

    init(workout: VideoWatermarkWorkoutSnapshot) {
        self.workout = workout
    }
}

struct VideoWatermarkMediaInfo: Codable {
    let sourceFileName: String
    let outputFileName: String
    let container: String
    let codec: String
    let width: Int
    let height: Int
    let nominalFrameRate: Double
    let duration: TimeInterval
    let creationTime: TimeInterval
    let effectiveVideoStart: TimeInterval
    let effectiveDuration: TimeInterval
    let hasAudio: Bool
    let sourceByteCount: Int64
    let isHDR: Bool

    var effectiveVideoEnd: TimeInterval { effectiveVideoStart + effectiveDuration }
    var supportsHDR: Bool { isHDR }
}

struct VideoWatermarkTask: Codable, Identifiable {
    let id: UUID
    let userID: String
    let createdAt: Date
    var updatedAt: Date
    /// 成片成功写入的时间。与创建/失败时间分离，供任务卡片展示最近一次成功生成时间。
    var completedAt: Date?
    var status: VideoWatermarkTaskStatus
    var progress: Double
    var failureMessage: String?
    var stage: VideoWatermarkTaskStage?
    let workout: VideoWatermarkWorkoutSnapshot
    var media: VideoWatermarkMediaInfo
    /// nil 表示 PhotosPicker 无法解析 PHAsset，原片已在 App 沙盒内。
    let photoAssetReference: VideoWatermarkPhotoAssetReference?
    let outputFormat: VideoWatermarkOutputFormat
    var selectedMetrics: Set<VideoWatermarkMetric>
    var layouts: [VideoWatermarkMetric: VideoWatermarkLayout]
    var outputByteCount: Int64?
    var outputDeleted: Bool

    init(userID: String, workout: VideoWatermarkWorkoutSnapshot, media: VideoWatermarkMediaInfo, photoAssetReference: VideoWatermarkPhotoAssetReference? = nil, outputFormat: VideoWatermarkOutputFormat, selectedMetrics: Set<VideoWatermarkMetric>, layouts: [VideoWatermarkMetric: VideoWatermarkLayout]) {
        self.id = UUID()
        self.userID = userID
        self.createdAt = Date()
        self.updatedAt = Date()
        self.completedAt = nil
        self.status = .waiting
        self.progress = 0
        self.failureMessage = nil
        self.stage = nil
        self.workout = workout
        self.media = media
        self.photoAssetReference = photoAssetReference
        self.outputFormat = outputFormat
        self.selectedMetrics = selectedMetrics
        self.layouts = layouts
        self.outputByteCount = nil
        self.outputDeleted = false
    }

    var displayTitleKey: String {
        switch workout.kind {
        case .race: return "video_watermark.record.race"
        case .freeTraining: return "video_watermark.record.free_training"
        case .routeTraining: return "video_watermark.record.route_training"
        }
    }
}
