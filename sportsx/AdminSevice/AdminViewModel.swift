//
//  AdminViewModel.swift
//  sportsx
//
//  Created by 任杰 on 2025/6/3.
//
import Foundation
import UIKit
import _PhotosUI_SwiftUI


class EventBackendViewModel: ObservableObject {
    @Published var events: [EventCardEntry] = []
    @Published var showCreateSheet = false
    @Published var showUpdateSheet = false
    
    var hasMoreEvents: Bool = true
    var currentPage: Int = 1
    
    var selectedEventID: String = ""
    
    // 更新的event信息
    @Published var name: String = ""
    @Published var description: String = ""
    @Published var startDate: Date = Date()
    @Published var endDate: Date = Date().addingTimeInterval(3600*24)
    var image_url: String = ""
}

enum SportType: String, CaseIterable, Codable {
    case running
    case bike
    
    var displayName: String {
        switch self {
        case .running: return "跑步"
        case .bike: return "自行车"
        }
    }
}

struct EventCardEntry: Identifiable, Equatable {
    let id: UUID
    let event_id: String
    let name: String
    let description: String
    let start_date: String
    let end_date: String
    let season_name: String
    let region_name: String
    let sport_type: SportType
    let image_url: String
    
    /*init(
        id: UUID = UUID(),
        event_id: String,
        name: String,
        start_date: String,
        end_date: String,
        season_name: String,
        region_name: String,
        sport_type: SportType,
        image_url: String
    ) {
        self.id = id
        self.event_id = event_id
        self.name = name
        self.start_date = start_date
        self.end_date = end_date
        self.season_name = season_name
        self.region_name = region_name
        self.sport_type = sport_type
        self.image_url = image_url
    }*/
    
    init(from event: EventInfoDTO) {
        self.id = UUID()
        self.event_id = event.event_id
        self.name = event.name
        self.description = event.description
        self.start_date = event.start_date
        self.end_date = event.end_date
        self.season_name = event.season_name
        self.region_name = event.region_name
        self.sport_type = event.sport_type
        self.image_url = event.image_url
    }
    
    static func == (lhs: EventCardEntry, rhs: EventCardEntry) -> Bool {
        return lhs.event_id == rhs.event_id
    }
}

struct EventInfoDTO: Codable {
    let event_id: String
    let name: String
    let description: String
    let start_date: String
    let end_date: String
    let season_name: String
    let region_name: String
    let sport_type: SportType
    let image_url: String
}

struct EventsResponse: Codable {
    let events: [EventInfoDTO]
}
