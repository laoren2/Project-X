//
//  PendingWorkoutUpload.swift
//  sportsx
//
//  运动结束上传失败时的本地待上传数据信封
//  当 race / free training / route training 结束上传失败时，将完整请求数据落盘，
//  待网络恢复后由用户在记录页手动重传。
//
//  Created by Claude on 2026/6/15.
//

import Foundation


// 待上传记录所属类别，决定其在哪个入口（比赛记录页 / 训练历史页）展示
enum PendingUploadCategory: String, Codable {
    case race           // 比赛模式
    case training       // 训练模式（自由训练 + 路线训练）
}

// 待上传记录的运动模式，决定 endpoint 与列表展示文案
enum PendingUploadMode: String, Codable {
    case raceSingle     // 单人比赛
    case raceTeam       // 组队比赛
    case freeTraining   // 自由训练
    case routeTraining  // 路线训练

    var displayIcon: String {
        switch self {
        case .raceSingle:   return "arena"
        case .raceTeam:     return "arena"
        case .freeTraining: return "free_training"
        case .routeTraining: return "route_training"
        }
    }
    
    var displayNameKey: String {
        switch self {
        case .raceSingle:   return "upload.pending.mode.race_single"
        case .raceTeam:     return "upload.pending.mode.race_team"
        case .freeTraining: return "upload.pending.mode.free_training"
        case .routeTraining: return "upload.pending.mode.route_training"
        }
    }
}

// 一条待上传的运动数据信封（落盘为单个 JSON 文件）
struct PendingWorkoutUpload: Codable, Identifiable {
    let id: String                      // client_upload_id（UUID），同时作为服务端去重幂等键与本地文件名
    let userID: String                  // 所属用户（按用户隔离存储）
    let sport: SportName                // 运动类型
    let category: PendingUploadCategory // 类别（决定入口归属）
    let mode: PendingUploadMode         // 模式（决定 endpoint 与文案）
    let endpointPath: String            // finish 接口路径，重传时直接使用
    let body: Data                      // 已编码的请求体 JSON，重传时按字节原样 POST
    let createdAt: Date                 // 运动结束（入队）时间

    // 展示摘要，避免列表页解析庞大的 body
    let distanceMeters: Double          // 总距离/m
    let duration: TimeInterval          // 时长/s
    let title: String?                  // 赛道名 / 路线名，自由训练为 nil
}
