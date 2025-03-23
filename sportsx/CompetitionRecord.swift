//
//  CompetitionRecord.swift
//  sportsx
//
//  Created by 任杰 on 2025/3/21.
//


import Foundation
import MapKit

// 比赛记录状态枚举
enum CompetitionStatus: String, Codable {
    case empty = "空"
    case incomplete = "未完成"
    case completed = "已完成"
}

// 比赛记录模型
struct CompetitionRecord: Identifiable {
    let id: UUID  // 唯一标识符
    let sportType: SportName // 比赛运动种类
    let fee: Int // 实际的报名费
    let eventName: String  // 赛事名称
    let trackName: String  // 赛道名称
    let trackStart: CLLocationCoordinate2D // 赛道出发点
    let trackEnd: CLLocationCoordinate2D // 赛道终点
    let isTeamCompetition: Bool  // 是否为组队比赛
    var status: CompetitionStatus  // 比赛状态
    var initDate: Date // 创建日期
    var startDate: Date?  // 开始日期
    var completionDate: Date?  // 完成日期，可为空
    var score: Double?  // 得分，可为空
    var duration: TimeInterval?  // 持续时间，可为空
    
    // 初始化方法
    init() {
        self.id = UUID()
        self.sportType = .Default
        self.fee = 0
        self.eventName = ""
        self.trackName = ""
        self.trackStart = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        self.trackEnd = CLLocationCoordinate2D(latitude: 1, longitude: 1)
        self.isTeamCompetition = false
        self.status = .empty
        self.initDate = Date()
        self.startDate = nil
        self.completionDate = nil
        self.score = nil
        self.duration = nil
    }
    
    init(
        id: UUID = UUID(),
        sportType: SportName,
        fee: Int,
        eventName: String,
        trackName: String,
        trackStart: CLLocationCoordinate2D,
        trackEnd: CLLocationCoordinate2D,
        isTeamCompetition: Bool,
        status: CompetitionStatus = .incomplete,
        initDate: Date = Date(),
        startDate: Date? = nil,
        completionDate: Date? = nil,
        score: Double? = nil,
        duration: TimeInterval? = nil
    ) {
        self.id = id
        self.sportType = sportType
        self.fee = fee
        self.eventName = eventName
        self.trackName = trackName
        self.trackStart = trackStart
        self.trackEnd = trackEnd
        self.isTeamCompetition = isTeamCompetition
        self.status = status
        self.initDate = initDate
        self.startDate = startDate
        self.completionDate = completionDate
        self.score = score
        self.duration = duration
    }
    
    // 格式化比赛类型
    var competitionTypeText: String {
        return isTeamCompetition ? "组队" : "单人"
    }
    
    // 格式化报名日期
    var formattedInitDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: initDate)
    }
    
    // 格式化开始日期
    var formattedStartDate: String {
        guard let date = startDate else { return "未开始" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
    
    // 格式化完成日期
    var formattedCompletionDate: String {
        guard let date = completionDate else { return "未完成" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
    
    // 格式化持续时间
    var formattedDuration: String {
        guard let duration = duration else { return "未知" }
        
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d时%02d分%02d秒", hours, minutes, seconds)
        } else {
            return String(format: "%d分%02d秒", minutes, seconds)
        }
    }
} 
