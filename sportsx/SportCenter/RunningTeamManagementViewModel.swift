//
//  RunningTeamManagementViewModel.swift
//  sportsx
//
//  Created by 任杰 on 2025/8/5.
//

import Foundation
import CoreLocation
//import SwiftUI


class RunningTeamManagementViewModel: ObservableObject {
    let user = UserManager.shared
    
    // 所有队伍列表
    @Published var myCreatedTeams: [RunningTeamCard] = []
    @Published var myJoinedTeams: [RunningTeamCard] = []
    @Published var myAppliedTeams: [RunningTeamAppliedCard] = []
    
    let competitionManager = CompetitionManager.shared
    
    // 选中的队伍（用于详情展示）
    var detailTeamID: String = ""
    var manageTeamID: String = ""
    //@Published var showDetail: Bool = false
    //@Published var showManage: Bool = false
    //@Published var selectedAppliedCard: RunningTeamAppliedCard?
    @Published var showDetailSheet: Bool = false
    @Published var selectedDescription: String = ""
    //@Published var showDescription: Bool = false
    
    // 提示信息
    @Published var showAlert = false
    @Published var showCardAlert = false    // 控制teamManageCard弹出的alert
    var alertMessage = ""
    
    // 当前选择的Tab
    @Published var selectedTab = 0
    
    var hasMoreCreatedTeams: Bool = true
    var hasMoreAppliedTeams: Bool = true
    var hasMoreJoinedTeams: Bool = true
    var createdPage: Int = 1
    var appliedPage: Int = 1
    var joinedPage: Int = 1
    let pageSize: Int = 10
    
    @Published var isCreatedLoading: Bool = false
    @Published var isAppliedLoading: Bool = false
    @Published var isJoinedLoading: Bool = false

    @MainActor
    func queryAppliedTeams(withLoadingToast: Bool, reset: Bool) async {
        if reset {
            myAppliedTeams.removeAll()
            appliedPage = 1
        }
        isAppliedLoading = true
        
        guard var components = URLComponents(string: "/competition/running/query_applied_teams") else { return }
        components.queryItems = [
            URLQueryItem(name: "page", value: "\(appliedPage)"),
            URLQueryItem(name: "size", value: "\(pageSize)")
        ]
        guard let urlPath = components.string else { return }
        let request = APIRequest(path: urlPath, method: .get, requiresAuth: true)
        let result = await NetworkService.sendAsyncRequest(with: request, decodingType: RunningTeamAppliedResponse.self, showLoadingToast: withLoadingToast, showErrorToast: true)
        
        isAppliedLoading = false
        
        switch result {
        case .success(let data):
            if let unwrappedData = data {
                for team in unwrappedData.teams {
                    myAppliedTeams.append(RunningTeamAppliedCard(from: team))
                }
                if unwrappedData.teams.count < self.pageSize {
                    hasMoreAppliedTeams = false
                } else {
                    hasMoreAppliedTeams = true
                    appliedPage += 1
                }
            }
        default: break
        }
    }
    
    @MainActor
    func queryCreatedTeams(withLoadingToast: Bool, reset: Bool) async {
        if reset {
            myCreatedTeams.removeAll()
            createdPage = 1
        }
        isCreatedLoading = true
        
        guard var components = URLComponents(string: "/competition/running/query_created_teams") else { return }
        components.queryItems = [
            URLQueryItem(name: "page", value: "\(createdPage)"),
            URLQueryItem(name: "size", value: "\(pageSize)")
        ]
        guard let urlPath = components.string else { return }
        let request = APIRequest(path: urlPath, method: .get, requiresAuth: true)
        let result = await NetworkService.sendAsyncRequest(with: request, decodingType: RunningTeamResponse.self, showLoadingToast: withLoadingToast, showErrorToast: true)
        
        isCreatedLoading = false
        
        switch result {
        case .success(let data):
            if let unwrappedData = data {
                for team in unwrappedData.teams {
                    myCreatedTeams.append(RunningTeamCard(from: team))
                }
                if unwrappedData.teams.count < self.pageSize {
                    hasMoreCreatedTeams = false
                } else {
                    hasMoreCreatedTeams = true
                    createdPage += 1
                }
            }
        default: break
        }
    }
    
    @MainActor
    func queryJoinedTeams(withLoadingToast: Bool, reset: Bool) async {
        if reset {
            myJoinedTeams.removeAll()
            joinedPage = 1
        }
        isJoinedLoading = true
        
        guard var components = URLComponents(string: "/competition/running/query_joined_teams") else { return }
        components.queryItems = [
            URLQueryItem(name: "page", value: "\(joinedPage)"),
            URLQueryItem(name: "size", value: "\(pageSize)")
        ]
        guard let urlPath = components.string else { return }
        let request = APIRequest(path: urlPath, method: .get, requiresAuth: true)
        let result = await NetworkService.sendAsyncRequest(with: request, decodingType: RunningTeamResponse.self, showLoadingToast: withLoadingToast, showErrorToast: true)
        
        isJoinedLoading = false
        
        switch result {
        case .success(let data):
            if let unwrappedData = data {
                for team in unwrappedData.teams {
                    myJoinedTeams.append(RunningTeamCard(from: team))
                }
                if unwrappedData.teams.count < self.pageSize {
                    hasMoreJoinedTeams = false
                } else {
                    hasMoreJoinedTeams = true
                    joinedPage += 1
                }
            }
        default: break
        }
    }
    
    // 取消申请加入
    func cancelApplied(teamID: String) {
        guard var components = URLComponents(string: "/competition/running/cancel_applied_join_team") else { return }
        components.queryItems = [
            URLQueryItem(name: "team_id", value: teamID)
        ]
        guard let urlPath = components.string else { return }
        let request = APIRequest(path: urlPath, method: .post, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: EmptyResponse.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true) { result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    if let index = self.myAppliedTeams.firstIndex(where: { $0.team_id == teamID }) {
                        self.myAppliedTeams.remove(at: index)
                    }
                }
            default: break
            }
        }
    }
}

class RunningTeamDetailViewModel: ObservableObject {
    @Published var teamInfo: RunningTeamDetailInfo?
    
    func queryTeam(with teamID: String) {
        guard var components = URLComponents(string: "/competition/running/query_team_detail") else { return }
        components.queryItems = [
            URLQueryItem(name: "team_id", value: teamID)
        ]
        guard let urlPath = components.url?.absoluteString else { return }
        
        let request = APIRequest(path: urlPath, method: .get, requiresAuth: true)
        NetworkService.sendRequest(with: request, decodingType: RunningTeamDetailDTO.self, showLoadingToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        self.teamInfo = RunningTeamDetailInfo(from: unwrappedData)
                    }
                }
            default: break
            }
        }
    }
}

class RunningTeamManageViewModel: ObservableObject {
    let globalConfig = GlobalConfig.shared
    @Published var showTeamEditor: Bool = false
    @Published var showAppliedDetail: Bool = false
    @Published var selectedAppliedMemberID: String = ""
    @Published var selectedIntroduction: String?
    
    @Published var teamInfo: RunningTeamManageInfo?
    @Published var members: [RunningTeamMember] = []
    @Published var request_members: [RunningTeamAppliedMember] = []
    
    
    @Published var is_public: Bool = false
    @Published var is_locked: Bool = false
    @Published var is_ready: Bool = false
    
    @Published var tempTitle: String = ""
    @Published var tempDescription: String = ""
    @Published var tempDate: Date = Date()
    
    let teamID: String
    
    init(teamID: String) {
        self.teamID = teamID
    }
    
    func queryTeam() {
        guard var components = URLComponents(string: "/competition/running/query_team_manage") else { return }
        components.queryItems = [
            URLQueryItem(name: "team_id", value: teamID)
        ]
        guard let urlPath = components.url?.absoluteString else { return }
        
        let request = APIRequest(path: urlPath, method: .get, requiresAuth: true)
        NetworkService.sendRequest(with: request, decodingType: RunningTeamManageDTO.self, showLoadingToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        self.teamInfo = RunningTeamManageInfo(from: unwrappedData)
                        if let team = self.teamInfo {
                            self.tempTitle = team.title
                            self.tempDescription = team.description
                            self.is_public = team.is_public
                            self.is_locked = team.is_locked
                            self.is_ready = team.is_ready
                            if let date = team.competition_date {
                                self.tempDate = date
                            }
                        }
                        for member in unwrappedData.members {
                            self.members.append(RunningTeamMember(from: member))
                        }
                        for request_member in unwrappedData.request_members {
                            self.request_members.append(RunningTeamAppliedMember(from: request_member))
                        }
                    }
                }
            default: break
            }
        }
    }
    
    func saveTeamInfo() {
        var headers: [String: String] = [:]
        headers["Content-Type"] = "application/json"
        let body: [String: String] = [
            "team_id": teamID,
            "title": tempTitle,
            "description": tempDescription,
            "competition_date": ISO8601DateFormatter().string(from: tempDate)
        ]
        guard let encodedBody = try? JSONEncoder().encode(body) else {
            return
        }
        let request = APIRequest(path: "/competition/running/update_team_info", method: .post, headers: headers, body: encodedBody, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: RunningTeamUpdateResponse.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                self.globalConfig.refreshTeamManageView = true
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        self.teamInfo?.title = unwrappedData.title
                        self.teamInfo?.description = unwrappedData.description
                        self.teamInfo?.competition_date = ISO8601DateFormatter().date(from: unwrappedData.competition_date)
                        self.showTeamEditor = false
                    }
                }
            default: break
            }
        }
    }
    
    func updateTeamPublicStatus(isPublic: Bool) {
        var headers: [String: String] = [:]
        headers["Content-Type"] = "application/json"
        let body: [String: String] = [
            "team_id": teamID,
            "new_status": "\(isPublic)"
        ]
        guard let encodedBody = try? JSONEncoder().encode(body) else {
            return
        }
        let request = APIRequest(path: "/competition/running/update_team_public_status", method: .post, headers: headers, body: encodedBody, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: Bool.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                self.globalConfig.refreshTeamManageView = true
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        self.is_public = unwrappedData
                    }
                }
            default: break
            }
        }
    }
    
    func updateTeamLockStatus(isLocked: Bool) {
        var headers: [String: String] = [:]
        headers["Content-Type"] = "application/json"
        let body: [String: String] = [
            "team_id": teamID,
            "new_status": "\(isLocked)"
        ]
        guard let encodedBody = try? JSONEncoder().encode(body) else {
            return
        }
        let request = APIRequest(path: "/competition/running/update_team_lock_status", method: .post, headers: headers, body: encodedBody, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: Bool.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                self.globalConfig.refreshTeamManageView = true
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        self.is_locked = unwrappedData
                    }
                }
            default: break
            }
        }
    }
    
    func updateTeamToReadyStatus() {
        guard var components = URLComponents(string: "/competition/running/update_team_ready_status") else { return }
        components.queryItems = [
            URLQueryItem(name: "team_id", value: teamID)
        ]
        guard let urlPath = components.string else { return }
        
        let request = APIRequest(path: urlPath, method: .post, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: Bool.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                self.globalConfig.refreshTeamManageView = true
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        self.is_ready = unwrappedData
                    }
                }
            default: break
            }
        }
    }
    
    func removeMember(with memberID: String) {
        guard var components = URLComponents(string: "/competition/running/remove_team_member") else { return }
        components.queryItems = [
            URLQueryItem(name: "team_id", value: teamID),
            URLQueryItem(name: "member_id", value: memberID)
        ]
        guard let urlPath = components.string else { return }
        
        let request = APIRequest(path: urlPath, method: .post, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: RunningTeamMemberUpdateResponse.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                self.globalConfig.refreshTeamManageView = true
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        self.members = unwrappedData.members.map { RunningTeamMember(from: $0) }
                    }
                }
            default: break
            }
        }
    }
    
    func rejectApplied() {
        guard var components = URLComponents(string: "/competition/running/reject_applied_request") else { return }
        components.queryItems = [
            URLQueryItem(name: "team_id", value: teamID),
            URLQueryItem(name: "member_id", value: selectedAppliedMemberID)
        ]
        guard let urlPath = components.string else { return }
        
        let request = APIRequest(path: urlPath, method: .post, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: EmptyResponse.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true) { result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    self.showAppliedDetail = false
                    if let index = self.request_members.firstIndex(where: { $0.member_id == self.selectedAppliedMemberID }) {
                        self.request_members.remove(at: index)
                    }
                }
            default: break
            }
        }
    }
    
    func approveApplied() {
        guard var components = URLComponents(string: "/competition/running/approve_applied_request") else { return }
        components.queryItems = [
            URLQueryItem(name: "team_id", value: teamID),
            URLQueryItem(name: "member_id", value: selectedAppliedMemberID)
        ]
        guard let urlPath = components.string else { return }
        
        let request = APIRequest(path: urlPath, method: .post, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: RunningTeamMemberUpdateResponse.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                self.globalConfig.refreshTeamManageView = true
                DispatchQueue.main.async {
                    self.showAppliedDetail = false
                    if let index = self.request_members.firstIndex(where: { $0.member_id == self.selectedAppliedMemberID }) {
                        self.request_members.remove(at: index)
                    }
                    if let unwrappedData = data {
                        self.members = unwrappedData.members.map { RunningTeamMember(from: $0) }
                    }
                }
            default: break
            }
        }
    }
}
