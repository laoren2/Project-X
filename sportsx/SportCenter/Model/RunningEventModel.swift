//
//  RunningEventModel.swift
//  sportsx
//
//  Created by 任杰 on 2025/6/15.
//

import Foundation
import CoreLocation


// 跑步赛道地形类型
enum RunningTrackTerrainType: String, Codable, CaseIterable {
    case road = "road"
    case mountain = "mountain"
    //case other = "other"
    
    var displayName: String {
        switch self {
        case .road:
            return "competition.terrain.road"
        case .mountain:
            return "competition.terrain.mountain"
        //case .other:
        //    return "competition.terrain.other"
        }
    }
}

// 赛道数据结构
struct RunningTrack: Identifiable, Equatable {
    var id: String { trackID }
    let trackID: String
    let name: String
    let startDate: Date?
    let endDate: Date?
    let routeType: RouteType
    let routePoints: [RoutePoint]       // 赛道路线（多检查点，坐标为 wgs84）
    let image_url: String
    let terrainType: RunningTrackTerrainType
    let singleRegisterCardUrl: String
    let teamRegisterCardUrl: String
    
    // 添加新的属性
    let elevationDifference: Int        // 海拔差(米)
    let regionName: String              // 覆盖的地理区域
    let prizePool: Int                  // 奖金池金额
    let distance: Double                // 路程距离
    let score: Int                      // 积分
    let totalParticipants: Int          // 总参与人数（实时榜）
    let participateCount: Int           // 报名/比赛记录数（热度排序与展示）
    let distanceToUser: Double?         // 起点到用户距离（米，distance 排序时返回）
    let currentParticipants: Int = 0    // 当前参与人数
    
    init(from track: RunningTrackInfoDTO) {
        self.trackID = track.track_id
        self.name = track.name
        self.startDate = DateParser.parseISO8601(track.start_date)
        self.endDate = DateParser.parseISO8601(track.end_date)
        self.routeType = track.route_type
        self.routePoints = [RoutePoint](routeData: track.route_data)
        self.image_url = track.image_url ?? ""      // 由热门路线转换的赛道暂无封面图
        self.terrainType = track.terrain_type
        self.singleRegisterCardUrl = track.single_register_card_url
        self.teamRegisterCardUrl = track.team_register_card_url
        self.elevationDifference = track.elevation_difference
        self.regionName = track.sub_region_name
        self.prizePool = track.prize_pool
        self.distance = track.distance
        self.score = track.score
        self.totalParticipants = track.totalParticipants
        self.participateCount = track.participate_count
        self.distanceToUser = track.distance_to_user
    }

    static func == (lhs: RunningTrack, rhs: RunningTrack) -> Bool {
        return lhs.trackID == rhs.trackID
    }
}

// 赛事数据结构
struct RunningEvent: Identifiable {
    var id: String { eventID }
    let eventID: String
    let name: String
    let description: String
    let startDate: Date?         // 赛事的开始时间
    let endDate: Date?           // 赛事的结束时间
    let image_url: String
    var tracks: [RunningTrack] = []    // 修改为可变属性
    
    init(from event: RunningEventInfoDTO) {
        self.eventID = event.event_id
        self.name = event.name
        self.description = event.description
        self.startDate = ISO8601DateFormatter().date(from: event.start_date) ?? Date()
        self.endDate = ISO8601DateFormatter().date(from: event.end_date) ?? Date()
        self.image_url = event.image_url
    }
}

struct RunningEventInfoDTO: Codable {
    let event_id: String
    let name: String
    let description: String
    let start_date: String
    let end_date: String
    let image_url: String
}

struct RunningEventsResponse: Codable {
    let events: [RunningEventInfoDTO]
}

struct RunningTrackInfoDTO: Codable {
    let track_id: String
    let name: String
    
    let start_date: String
    let end_date: String
    let image_url: String?
    let terrain_type: RunningTrackTerrainType
    let single_register_card_url: String
    let team_register_card_url: String

    let route_type: RouteType
    let route_data: JSONValue

    let elevation_difference: Int   // 海拔差(米)
    let sub_region_name: String     // 覆盖的地理子区域
    let prize_pool: Int             // 奖金池金额
    let distance: Double
    let score: Int
    let totalParticipants: Int
    let participate_count: Int
    let distance_to_user: Double?
}

struct RunningTracksResponse: Codable {
    let tracks: [RunningTrackInfoDTO]
    let next_cursor: String?
}
