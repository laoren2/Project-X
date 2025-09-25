//
//  RunningCompetitionViewModel.swift
//  sportsx
//
//  Created by 任杰 on 2025/6/15.
//

import Foundation
import CoreLocation
import UIKit


class RunningCompetitionViewModel: ObservableObject {
    let appState = AppState.shared
    let competitionManager = CompetitionManager.shared
    let userManager = UserManager.shared
    
    @Published var isEventsLoading = false      // 赛事列表的加载状态
    @Published var isTracksLoading = false      // 赛道列表的加载状态
    
    @Published var events: [RunningEvent] = []         // 赛事列表
    @Published var tracks: [RunningTrack] = []         // 赛道列表
    @Published var selectedEvent: RunningEvent?        // 当前选中赛事
    @Published var selectedTrack: RunningTrack?        // 当前选中赛道
    
    @Published var selectedRankInfo: RunningUserRankCard?
    
    // 队伍管理相关
    @Published var showCreateTeamSheet: Bool = false
    @Published var showJoinTeamSheet: Bool = false
    //@Published var showTeamCodeSheet: Bool = false
    
    // 显示选中的team详情页
    @Published var selectedTeamDetail: RunningTeamAppliedCard?
    
    // alert信息
    @Published var showAlert = false    // 控制各子页面、弹窗内的alert
    @Published var showSingleRegisterAlert = false  // 控制主页面的alert
    var alertMessage = ""
    var teamRegisterSuccessAlert: Bool = false  // 组队报名失败和成功的alert格式不一致
    
    // 当前最近报名的record
    var currentRecord: RunningRaceRecord?
    
    // 当前赛道可加入的队伍
    @Published var availableTeams: [RunningTeamAppliedCard] = []
    
    
    init() {}
    
    func resetAll() {
        events = []
        tracks = []
        selectedEvent = nil
        selectedTrack = nil
    }
    
    func fetchEvents(with city: String) {
        DispatchQueue.main.async {
            self.events.removeAll()
            self.selectedEvent = nil
        }
        if city == "未知" { return }
        DispatchQueue.main.async {
            self.isEventsLoading = true
        }
        guard var components = URLComponents(string: "/competition/running/query_events") else { return }
        components.queryItems = [
            URLQueryItem(name: "region_name", value: city)
        ]
        guard let urlPath = components.string else { return }
        
        let request = APIRequest(path: urlPath, method: .get)
            
        NetworkService.sendRequest(with: request, decodingType: RunningEventsResponse.self, showErrorToast: true) { result in
            DispatchQueue.main.async {
                self.isEventsLoading = false
            }
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        for event in unwrappedData.events {
                            self.events.append(RunningEvent(from: event))
                        }
                        if !self.events.isEmpty {
                            self.selectedEvent = self.events[0]
                        }
                        self.fetchTracks()
                    }
                }
            case .failure:
                DispatchQueue.main.async {
                    self.tracks.removeAll()
                    self.selectedTrack = nil
                }
            }
        }
    }
    
    func fetchTracks() {
        tracks.removeAll()
        selectedTrack = nil
        guard !events.isEmpty else { return }
        guard let event = selectedEvent else { return }
        
        isTracksLoading = true
        guard var components = URLComponents(string: "/competition/running/query_tracks") else { return }
        components.queryItems = [
            URLQueryItem(name: "event_id", value: event.eventID)
        ]
        guard let urlPath = components.string else { return }
            
        let request = APIRequest(path: urlPath, method: .get)
            
        NetworkService.sendRequest(with: request, decodingType: RunningTracksResponse.self, showErrorToast: true) { result in
            DispatchQueue.main.async {
                self.isTracksLoading = false
            }
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        for track in unwrappedData.tracks {
                            self.tracks.append(RunningTrack(from: track))
                        }
                        if !self.tracks.isEmpty {
                            if let index = self.events.firstIndex(where: { $0.eventID == self.selectedEvent?.eventID }) {
                                self.events[index].tracks = self.tracks
                            }
                            self.selectedTrack = self.tracks[0]
                        }
                    }
                }
            default: break
            }
        }
    }
    
    func queryRankInfo(trackID: String) {
        guard var components = URLComponents(string: "/competition/running/query_me_rank") else { return }
        components.queryItems = [
            URLQueryItem(name: "track_id", value: trackID)
        ]
        guard let urlPath = components.string else { return }
            
        let request = APIRequest(path: urlPath, method: .get, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: RunningUserRankInfoDTO.self, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        let rankInfo = RunningUserRankCard(from: unwrappedData)
                        if let eventIndex = self.events.firstIndex(where: { $0.eventID == self.selectedEvent?.eventID }),
                           let trackIndex = self.events[eventIndex].tracks.firstIndex(where: { $0.trackID == trackID }),
                           let index = self.tracks.firstIndex(where: { $0.trackID == trackID }) {
                            self.tracks[index].rankInfo = rankInfo
                            self.events[eventIndex].tracks[trackIndex].rankInfo = rankInfo
                        }
                        self.selectedRankInfo = rankInfo
                    }
                }
            default: break
            }
        }
    }
    
    // 切换赛事
    func switchEvent(to event: RunningEvent) {
        //selectedEvent?.tracks = tracks  // 缓存赛事里的所有赛道
        selectedEvent = event
        
        if event.tracks.isEmpty {
            fetchTracks()
        } else {
            tracks = event.tracks
            selectedTrack = tracks[0]   // 手动重置为第一个赛道
        }
        
        // 重新获取排行榜数据
        //fetchLeaderboard(gender: gender, reset: true)
    }
    
    // 切换赛道
    func switchTrack(to track: RunningTrack) {
        selectedTrack = track
    }
}

class RunningTeamJoinViewModel: ObservableObject {
    @Published var publicTeams: [RunningTeamAppliedCard] = []
    @Published var isLoading: Bool = false
    @Published var teamCode: String = ""
    @Published var selectedDescription: String = ""
    var selectedTeamID: String = ""
    
    @Published var showIntroSheet: Bool = false
    @Published var showDetailSheet: Bool = false
    
    var hasMore: Bool = true
    var page: Int = 1
    let pageSize: Int = 10
    
    let trackID: String
    
    init(trackID: String) {
        self.trackID = trackID
    }
    
    // 直接通过队伍码加入队伍
    func joinTeam() {
        guard var components = URLComponents(string: "/competition/running/join_team") else { return }
        components.queryItems = [
            URLQueryItem(name: "team_code", value: teamCode)
        ]
        guard let urlPath = components.string else { return }
        let request = APIRequest(path: urlPath, method: .post, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: EmptyResponse.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true) { result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    self.teamCode = ""
                }
            default: break
            }
        }
    }
    
    @MainActor
    func queryPublicTeams(withLoadingToast: Bool, reset: Bool) async {
        if reset {
            publicTeams.removeAll()
            page = 1
        }
        isLoading = true
        
        guard var components = URLComponents(string: "/competition/running/query_public_teams") else { return }
        components.queryItems = [
            URLQueryItem(name: "track_id", value: "\(trackID)"),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "size", value: "\(pageSize)")
        ]
        guard let urlPath = components.string else { return }
        let request = APIRequest(path: urlPath, method: .get, requiresAuth: true)
        let result = await NetworkService.sendAsyncRequest(with: request, decodingType: RunningTeamAppliedResponse.self, showLoadingToast: withLoadingToast, showErrorToast: true)
        
        isLoading = false
        
        switch result {
        case .success(let data):
            if let unwrappedData = data {
                for team in unwrappedData.teams {
                    publicTeams.append(RunningTeamAppliedCard(from: team))
                }
                if unwrappedData.teams.count < self.pageSize {
                    hasMore = false
                } else {
                    hasMore = true
                    page += 1
                }
            }
        default: break
        }
    }
}

struct RunningUserRankCard {
    var recordID: String?
    var rank: Int?
    var duration: Double?
    var voucherAmount: Int?
    var score: Int?
    
    init(from rank_info: RunningUserRankInfoDTO) {
        self.recordID = rank_info.record_id
        self.rank = rank_info.rank
        self.duration = rank_info.duration_seconds
        self.voucherAmount = rank_info.reward_voucher_amount
        self.score = rank_info.score
    }
}

struct RunningUserRankInfoDTO: Codable {
    let record_id: String?
    let rank: Int?
    let duration_seconds: Double?
    let reward_voucher_amount: Int?
    let score: Int?
}
