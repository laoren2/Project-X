//
//  EventModel.swift
//  sportsx
//
//  Created by 任杰 on 2025/3/14.
//

import Foundation
import CoreLocation


// 赛道数据结构
struct Track: Identifiable {
    let id = UUID()
    let trackIndex: Int
    let name: String
    var eventName: String = "未知"
    var from: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 0, longitude: 0)
    var to: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 1, longitude: 1)
    
    // 添加新的属性
    var elevationDifference: Int = 0 // 海拔差(米)
    var regionName: String = "" // 覆盖的地理区域
    var fee: Int = 0 // 报名费
    var prizePool: Int = 0 // 奖金池金额
    var totalParticipants: Int = 0 // 总参与人数
    var currentParticipants: Int = 0 // 当前参与人数
}

// 赛事数据结构
struct Event: Identifiable {
    let id = UUID()
    let eventIndex: Int
    let name: String
    var city: String = "未知"
    let description: String
    var tracks: [Track] // 修改为可变属性
    
    init(eventIndex: Int, name: String, city: String, description: String = "", tracks: [Track] = []) {
        self.eventIndex = eventIndex
        self.name = name
        self.city = city
        self.description = description
        self.tracks = tracks
    }
}
