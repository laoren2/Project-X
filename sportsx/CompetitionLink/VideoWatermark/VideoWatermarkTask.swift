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
    case predictedRank
    case pbTime
    case pbDistance
    case logo

    var id: String { rawValue }
    var titleKey: String {
        switch self {
        case .route: return "video_watermark.metric.route"
        case .speed: return "video_watermark.metric.speed"
        case .altitude: return "video_watermark.metric.altitude"
        case .heartRate: return "video_watermark.metric.heart_rate"
        case .predictedRank: return "video_watermark.metric.predicted_rank"
        case .pbTime: return "video_watermark.metric.pb_time"
        case .pbDistance: return "video_watermark.metric.pb_distance"
        case .logo: return "video_watermark.metric.logo"
        }
    }
    var iconName: String {
        switch self {
        case .route: return "point.topleft.down.to.point.bottomright.curvepath"
        case .speed: return "speedometer"
        case .altitude: return "triangle.fill"
        case .heartRate: return "heart.fill"
        case .predictedRank: return "list.number"
        case .pbTime: return "clock.arrow.circlepath"
        case .pbDistance: return "ruler"
        case .logo: return "single_app_icon"
        }
    }

    var isPaceMetric: Bool {
        switch self {
        case .predictedRank, .pbTime, .pbDistance:
            return true
        default:
            return false
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

/// 保存实时页使用的“本时刻累计卡牌减时”，用于离线回放同一套有效用时口径。
struct VideoWatermarkPacePoint: Codable {
    let timestamp: TimeInterval
    let cumulativeCardBonus: Double
}

/// 服务端在完赛、更新本次榜单之前冻结的基线。字段与 PaceSnapshotResponse 对齐。
struct VideoWatermarkPaceSnapshot: Codable {
    let version: Int
    let finish_times: [Double]
    let pb_profile: SplitProfile?
    let route_data: JSONValue
}

/// 创建任务时预计算并持久化，确保导出和重试不会重新查询或因算法状态改变而漂移。
struct VideoWatermarkPaceFrame: Codable {
    let timestamp: TimeInterval
    let rank: Int?
    let total: Int
    let deltaTime: Double?
    let deltaDistance: Double?
}

struct VideoWatermarkWorkoutSnapshot: Codable {
    let recordID: String
    let sport: SportName
    let kind: VideoWatermarkRecordKind
    let points: [VideoWatermarkMotionPoint]
    /// nil 兼容已存在的本地视频任务；它们只是不支持新增的配速水印。
    let pacePoints: [VideoWatermarkPacePoint]?

    init(recordID: String, sport: SportName, kind: VideoWatermarkRecordKind, basePath: [PathPoint], pacePoints: [VideoWatermarkPacePoint] = []) {
        self.recordID = recordID
        self.sport = sport
        self.kind = kind
        self.points = basePath.map {
            VideoWatermarkMotionPoint(lat: $0.lat, lon: $0.lon, speed: $0.speed, altitude: $0.altitude, heartRate: $0.heart_rate, timestamp: $0.timestamp)
        }
        self.pacePoints = pacePoints
    }

    var startTime: TimeInterval? { points.first?.timestamp }
    var endTime: TimeInterval? { points.last?.timestamp }
    var hasHeartRate: Bool { points.contains { $0.heartRate != nil } }
}

final class VideoWatermarkEditorStore: NavigationStore {
    let workout: VideoWatermarkWorkoutSnapshot
    let paceSnapshotPath: String?

    init(workout: VideoWatermarkWorkoutSnapshot, paceSnapshotPath: String? = nil) {
        self.workout = workout
        self.paceSnapshotPath = paceSnapshotPath
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
    /// 仅用于导入时尝试自动对齐。部分运动相机导出的视频不会保留可靠的该元数据。
    let creationTime: TimeInterval?
    let hasAudio: Bool
    let sourceByteCount: Int64
    let isHDR: Bool

    var supportsHDR: Bool { isHDR }
}

/// 水印片段在原视频时间轴和运动数据时间轴之间的一对一映射。
/// 原视频始终完整导出；只有落在该片段内的帧会绘制水印。
struct VideoWatermarkOverlayRange: Codable, Equatable {
    var videoStart: TimeInterval
    var workoutStart: TimeInterval
    var duration: TimeInterval

    var videoEnd: TimeInterval { videoStart + duration }
    var workoutEnd: TimeInterval { workoutStart + duration }

    func contains(videoTime: TimeInterval) -> Bool {
        videoTime >= videoStart && videoTime <= videoEnd
    }

    func workoutTime(for videoTime: TimeInterval) -> TimeInterval? {
        guard contains(videoTime: videoTime) else { return nil }
        return workoutStart + (videoTime - videoStart)
    }
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
    let paceSnapshot: VideoWatermarkPaceSnapshot?
    /// nil 兼容已存在的本地视频任务；新任务始终写入数组（可为空）。
    let paceTimeline: [VideoWatermarkPaceFrame]?
    var media: VideoWatermarkMediaInfo
    var overlayRange: VideoWatermarkOverlayRange
    /// nil 表示 PhotosPicker 无法解析 PHAsset，原片已在 App 沙盒内。
    let photoAssetReference: VideoWatermarkPhotoAssetReference?
    let outputFormat: VideoWatermarkOutputFormat
    var selectedMetrics: Set<VideoWatermarkMetric>
    var layouts: [VideoWatermarkMetric: VideoWatermarkLayout]
    var outputByteCount: Int64?
    var outputDeleted: Bool

    init(userID: String, workout: VideoWatermarkWorkoutSnapshot, paceSnapshot: VideoWatermarkPaceSnapshot?, paceTimeline: [VideoWatermarkPaceFrame], media: VideoWatermarkMediaInfo, overlayRange: VideoWatermarkOverlayRange, photoAssetReference: VideoWatermarkPhotoAssetReference? = nil, outputFormat: VideoWatermarkOutputFormat, selectedMetrics: Set<VideoWatermarkMetric>, layouts: [VideoWatermarkMetric: VideoWatermarkLayout]) {
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
        self.paceSnapshot = paceSnapshot
        self.paceTimeline = paceTimeline
        self.media = media
        self.overlayRange = overlayRange
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
