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
    var nextTrackCursor: String? = nil              // 赛道分页游标
    @Published var sortType: RouteSortType = .participation     // 赛道排序方式（热度/距离）

    // 赛道的用户态信息（熟悉度 + 我的排名），登录后按页批量拉取填充；key 为 trackID
    @Published var trackUserInfos: [String: RunningTrackUserInfo] = [:]

    // 当前选中赛道的排名信息（从 trackUserInfos 派生）
    var selectedRankInfo: RunningUserRankCard? {
        guard let trackID = selectedTrack?.trackID else { return nil }
        return trackUserInfos[trackID]?.rankInfo
    }

    // 队伍管理相关
    @Published var showCreateTeamSheet: Bool = false
    @Published var showJoinTeamSheet: Bool = false
    //@Published var showTeamCodeSheet: Bool = false
    
    // 显示选中的team详情页
    @Published var selectedTeamDetail: RunningTeamAppliedCard?
    
    // 当前最近报名的record
    var currentRecord: RunningRaceRecord?
    
    // 当前赛道可加入的队伍
    @Published var availableTeams: [RunningTeamAppliedCard] = []
    @Published var didLoad: Bool = false
    
    init() {}
    
    func resetAll() {
        events = []
        tracks = []
        selectedEvent = nil
        selectedTrack = nil
    }
    
    func fetchEvents(with regionID: String) {
        guard var components = URLComponents(string: "/competition/running/query_events") else { return }
        components.queryItems = [
            URLQueryItem(name: "region_id", value: regionID)
        ]
        guard let urlPath = components.string else { return }
        
        let request = APIRequest(path: urlPath, method: .get)
        
        DispatchQueue.main.async {
            self.isEventsLoading = true
        }
        
        NetworkService.sendRequest(with: request, decodingType: RunningEventsResponse.self, showErrorToast: true) { result in
            DispatchQueue.main.async {
                self.isEventsLoading = false
                switch result {
                case .success(let data):
                    guard let data else { return }
                    
                    let newEvents = data.events.map { RunningEvent(from: $0) }
                    self.events = newEvents
                    self.selectedEvent = newEvents.first
                    if !newEvents.isEmpty {
                        self.fetchTracks()
                    }
                case .failure:
                    self.events = []
                    self.tracks = []
                    self.selectedEvent = nil
                    self.selectedTrack = nil
                }
            }
        }
    }
    
    func fetchTracks(reset: Bool = true) {
        guard !events.isEmpty, let event = selectedEvent else { return }
        guard !isTracksLoading else { return }

        if reset {
            tracks = []
            nextTrackCursor = nil
        }

        guard var components = URLComponents(string: "/competition/running/query_tracks") else { return }
        var query = [
            URLQueryItem(name: "event_id", value: event.eventID),
            URLQueryItem(name: "sort_type", value: sortType.rawValue),
            URLQueryItem(name: "limit", value: "10")
        ]
        if let loc = LocationManager.shared.getLocation() {
            query.append(URLQueryItem(name: "lat", value: "\(loc.coordinate.latitude)"))
            query.append(URLQueryItem(name: "lng", value: "\(loc.coordinate.longitude)"))
        }
        if let cursor = nextTrackCursor {
            query.append(URLQueryItem(name: "cursor", value: cursor))
        }
        components.queryItems = query
        guard let urlPath = components.string else { return }

        let request = APIRequest(path: urlPath, method: .get)

        DispatchQueue.main.async {
            self.isTracksLoading = true
        }

        NetworkService.sendRequest(with: request, decodingType: RunningTracksResponse.self, showErrorToast: true) { result in
            DispatchQueue.main.async {
                self.isTracksLoading = false
                switch result {
                case .success(let data):
                    guard let data else { return }
                    guard let selectedEvent = self.selectedEvent, event.eventID == selectedEvent.eventID else { return }
                    let newTracks = data.tracks.map { RunningTrack(from: $0) }
                    if reset {
                        self.tracks = newTracks
                        self.selectedTrack = newTracks.first
                    } else {
                        self.tracks.append(contentsOf: newTracks)
                    }
                    self.nextTrackCursor = data.next_cursor
                    // 登录后批量拉取这页赛道的用户态信息（熟悉度 + 我的排名）
                    self.fetchTracksUserInfo(trackIDs: newTracks.map { $0.trackID })
                case .failure:
                    if reset {
                        self.tracks = []
                        self.selectedTrack = nil
                    }
                }
            }
        }
    }

    // 批量拉取赛道用户态信息（熟悉度 + 排名），按 track_id 填充 trackUserInfos
    func fetchTracksUserInfo(trackIDs: [String]) {
        guard userManager.isLoggedIn, !trackIDs.isEmpty else { return }
        let body: [String: Any] = ["track_ids": trackIDs]
        guard let encodedBody = try? JSONSerialization.data(withJSONObject: body) else { return }
        var headers: [String: String] = [:]
        headers["Content-Type"] = "application/json"

        let request = APIRequest(path: "/competition/running/query_tracks_user_info", method: .post, headers: headers, body: encodedBody, requiresAuth: true)
        NetworkService.sendRequest(with: request, decodingType: RunningTracksUserInfoResponse.self) { result in
            switch result {
            case .success(let data):
                guard let data else { return }
                DispatchQueue.main.async {
                    for info in data.infos {
                        self.trackUserInfos[info.track_id] = RunningTrackUserInfo(from: info)
                    }
                }
            default: break
            }
        }
    }
    
    // 切换赛事：重置分页并重新拉取首页赛道
    func switchEvent(to event: RunningEvent) {
        selectedEvent = event
        fetchTracks(reset: true)
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
        
        NetworkService.sendRequest(with: request, decodingType: EmptyResponse.self, showLoadingToast: true, showErrorToast: true) { result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    self.teamCode = ""
                    ToastManager.shared.show(toast: Toast(message: "competition.team.join.toast.success"))
                }
            default: break
            }
        }
    }
    
    @MainActor
    func queryPublicTeams(withLoadingToast: Bool, reset: Bool) async {
        if reset {
            publicTeams = []
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
                var tempTeams: [RunningTeamAppliedCard] = []
                for team in unwrappedData.teams {
                    tempTeams.append(RunningTeamAppliedCard(from: team))
                }
                if reset {
                    publicTeams = tempTeams
                } else {
                    publicTeams.append(contentsOf: tempTeams)
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

// 赛道用户态信息（熟悉度 + 我的排名），批量接口返回
struct RunningTrackUserInfo {
    let familiarity: Double?
    let rankInfo: RunningUserRankCard?

    init(from dto: RunningTrackUserInfoDTO) {
        self.familiarity = dto.familiarity
        if let r = dto.rank_info {
            self.rankInfo = RunningUserRankCard(from: r)
        } else {
            self.rankInfo = nil
        }
    }
}

struct RunningTrackUserInfoDTO: Codable {
    let track_id: String
    let familiarity: Double
    let rank_info: RunningUserRankInfoDTO?
}

struct RunningTracksUserInfoResponse: Codable {
    let infos: [RunningTrackUserInfoDTO]
}
