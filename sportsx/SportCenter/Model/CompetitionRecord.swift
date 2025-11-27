//
//  CompetitionRecord.swift
//  sportsx
//
//  Created by 任杰 on 2025/3/21.
//
import SwiftUI
import Foundation
import MapKit


// 比赛记录状态枚举
enum CompetitionStatus: String, Codable {
    case notStarted = "notStarted"          // 记录未开始
    case recording = "recording"            // 记录进行中
    case completed = "completed"            // 记录已完成（可能存在数据统计延迟的情况如受部分卡牌影响）
    case expired = "expired"                // 记录已过期（可能由于非正常结束等原因已被服务端清理）
    case toBeVerified = "toBeVerified"      // 运动数据待校验
    case invalid = "invalid"                // 运动数据校验失败
    
    var displayName: String {
        switch self {
        case .notStarted:
            return "未开始"
        case .recording:
            return "进行中"
        case .completed:
            return "已完成"
        case .expired:
            return "已过期"
        case .toBeVerified:
            return "校验中"
        case .invalid:
            return "校验失败"
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .notStarted:
            return .gray
        case .recording:
            return .orange
        case .completed:
            return .green
        case .expired:
            return .gray
        case .toBeVerified:
            return .orange
        case .invalid:
            return .red
        }
    }
}

// 队伍成员结构
struct MemberRecord: Identifiable {
    let id = UUID()
    let userID: String?     // server userid
    let name: String        // 用户昵称
    let avatar: String      // 头像
    var startTime: Date     // 开始比赛的时间
    var endTime: Date       // 结束比赛的时间
}

// bike比赛记录
struct BikeRaceRecord: Identifiable, Equatable {
    var id: String { record_id }
    let record_id: String                   // 唯一标识符id
    let regionName: String                  // 区域名
    let eventName: String                   // 赛事名
    let trackName: String                   // 赛道名
    let trackStart: CLLocationCoordinate2D  // 赛道出发点
    let trackStartRadius: Int               // 赛道出发点半径
    let trackEnd: CLLocationCoordinate2D    // 赛道终点
    let trackEndRadius: Int                 // 赛道终点半径
    let trackEndDate: Date?                 // 赛道结束时间
    let status: CompetitionStatus           // 比赛状态
    let startDate: Date?                    // 记录比赛开始时间
    let endDate: Date?                      // 记录比赛完成时间
    let duration: TimeInterval?             // 比赛成绩
    let isTeam: Bool                        // 是否为组队比赛
    let teamTitle: String?                  // 队伍名称
    let teamCompetitionDate: Date?          // 队伍比赛时间
    let createdDate: Date?                  // 记录的创建时间
    
    init(from record: BikeRaceRecordDTO) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.record_id = record.record_id
        self.regionName = record.region_name
        self.eventName = record.event_name
        self.trackName = record.track_name
        self.trackStart = CLLocationCoordinate2D(latitude: record.track_start_lat, longitude: record.track_start_lng)
        self.trackStartRadius = record.track_start_radius
        self.trackEnd = CLLocationCoordinate2D(latitude: record.track_end_lat, longitude: record.track_end_lng)
        self.trackEndRadius = record.track_end_radius
        self.trackEndDate = ISO8601DateFormatter().date(from: record.track_end_date)
        self.status = record.status
        self.startDate = formatter.date(from: record.start_date ?? "")
        self.endDate = formatter.date(from: record.end_date ?? "")
        self.duration = record.duration_seconds
        self.isTeam = record.is_team
        self.teamTitle = record.team_title
        self.teamCompetitionDate = ISO8601DateFormatter().date(from: record.team_competition_date ?? "")
        self.createdDate = formatter.date(from: record.created_at)
    }
    
    // 格式化比赛类型
    var competitionTypeText: String {
        return isTeam ? "队伍" : "单人"
    }
    
    static func == (lhs: BikeRaceRecord, rhs: BikeRaceRecord) -> Bool {
        return lhs.record_id == rhs.record_id
    }
}

struct BikeRaceRecordDTO: Codable {
    let record_id: String
    let region_name: String
    let event_name: String
    let track_name: String
    let track_start_lat: Double
    let track_start_lng: Double
    let track_start_radius: Int
    let track_end_lat: Double
    let track_end_lng: Double
    let track_end_radius: Int
    let track_end_date: String
    let status: CompetitionStatus
    let start_date: String?
    let end_date: String?
    let duration_seconds: TimeInterval?
    let is_team: Bool
    let team_title: String?
    let team_competition_date: String?
    let created_at: String
}

struct BikeRaceRecordResponse: Codable {
    let records: [BikeRaceRecordDTO]
}

struct BikeRegisterResponse: Codable {
    let record: BikeRaceRecordDTO
    let asset_id: String
    let new_balance: Int
}

// Running比赛记录
struct RunningRaceRecord: Identifiable, Equatable {
    var id: String { record_id }
    let record_id: String                   // 唯一标识符id
    let regionName: String                  // 区域名
    let eventName: String                   // 赛事名
    let trackName: String                   // 赛道名
    let trackStart: CLLocationCoordinate2D  // 赛道出发点
    let trackStartRadius: Int               // 赛道出发点半径
    let trackEnd: CLLocationCoordinate2D    // 赛道终点
    let trackEndRadius: Int                 // 赛道终点半径
    let trackEndDate: Date?                 // 赛道结束时间
    let status: CompetitionStatus           // 比赛状态
    let startDate: Date?                    // 记录比赛开始时间
    let endDate: Date?                      // 记录比赛完成时间
    let duration: TimeInterval?             // 比赛成绩
    let isTeam: Bool                        // 是否为组队比赛
    let teamTitle: String?                  // 队伍名称
    let teamCompetitionDate: Date?          // 队伍比赛时间
    let createdDate: Date?                  // 记录的创建时间
    
    init(from record: RunningRaceRecordDTO) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.record_id = record.record_id
        self.regionName = record.region_name
        self.eventName = record.event_name
        self.trackName = record.track_name
        self.trackStart = CLLocationCoordinate2D(latitude: record.track_start_lat, longitude: record.track_start_lng)
        self.trackStartRadius = record.track_start_radius
        self.trackEnd = CLLocationCoordinate2D(latitude: record.track_end_lat, longitude: record.track_end_lng)
        self.trackEndRadius = record.track_end_radius
        self.trackEndDate = ISO8601DateFormatter().date(from: record.track_end_date)
        self.status = record.status
        self.startDate = formatter.date(from: record.start_date ?? "")
        self.endDate = formatter.date(from: record.end_date ?? "")
        self.duration = record.duration_seconds
        self.isTeam = record.is_team
        self.teamTitle = record.team_title
        self.teamCompetitionDate = ISO8601DateFormatter().date(from: record.team_competition_date ?? "")
        self.createdDate = formatter.date(from: record.created_at)
    }
    
    // 格式化比赛类型
    var competitionTypeText: String {
        return isTeam ? "队伍" : "单人"
    }
    
    static func == (lhs: RunningRaceRecord, rhs: RunningRaceRecord) -> Bool {
        return lhs.record_id == rhs.record_id
    }
}

struct RunningRaceRecordDTO: Codable {
    let record_id: String
    let region_name: String
    let event_name: String
    let track_name: String
    let track_start_lat: Double
    let track_start_lng: Double
    let track_start_radius: Int
    let track_end_lat: Double
    let track_end_lng: Double
    let track_end_radius: Int
    let track_end_date: String
    let status: CompetitionStatus
    let start_date: String?
    let end_date: String?
    let duration_seconds: TimeInterval?
    let is_team: Bool
    let team_title: String?
    let team_competition_date: String?
    let created_at: String
}

struct RunningRaceRecordResponse: Codable {
    let records: [RunningRaceRecordDTO]
}

struct RunningRegisterResponse: Codable {
    let record: RunningRaceRecordDTO
    let asset_id: String
    let new_balance: Int
}
