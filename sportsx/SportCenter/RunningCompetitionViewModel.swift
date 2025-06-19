//
//  RunningCompetitionViewModel.swift
//  sportsx
//
//  Created by 任杰 on 2025/6/15.
//

import Foundation
import CoreLocation

class RunningCompetitionViewModel: ObservableObject {
    let appState = AppState.shared
    let competitionManager = CompetitionManager.shared
    let user = UserManager.shared
    
    @Published var isEventsLoading = false      // 赛事列表的加载状态
    @Published var isTracksLoading = false      // 赛道列表的加载状态
    
    @Published var events: [RunningEvent] = []         // 赛事列表
    @Published var tracks: [RunningTrack] = []         // 赛道列表
    @Published var selectedEvent: RunningEvent?        // 当前选中赛事
    @Published var selectedTrack: RunningTrack?        // 当前选中赛道
    
    // 排行榜信息
    @Published var leaderboardEntries: [LeaderboardEntry] = []
    @Published var gender: String = "male"      // 排行榜性别
    @Published var isLoadingMore = false        // 排行榜的加载状态
    private var currentLeaderboardPage = 0      // 当前排行榜分页页码
    private var leaderboardFetchCount = 0       // 更新排行榜的引用计数，在频繁更新时显示加载状态
    
    
    // 队伍管理相关
    @Published var showCreateTeamSheet: Bool = false
    @Published var showJoinTeamSheet: Bool = false
    @Published var showTeamCodeSheet: Bool = false
    
    // 添加队伍字段
    @Published var teamTitle: String = ""
    @Published var teamDescription: String = ""
    @Published var teamSize: Int = 5 // 默认值
    @Published var teamCompetitionDate = Date().addingTimeInterval(86400 * 7) // 默认一周后
    @Published var isPublic: Bool = false
    
    // 显示选中的team详情页
    @Published var selectedTeamDetail: Team?
    
    // alert信息
    @Published var showAlert = false    // 控制各子页面、弹窗内的alert
    @Published var showSingleRegisterAlert = false  // 控制主页面的alert
    var alertMessage = ""
    var teamRegisterSuccessAlert: Bool = false  // 组队报名失败和成功的alert格式不一致
    
    // 当前最近报名的record
    var currentRecord: CompetitionRecord?
    
    
    
    // 上一次位置更新时记录的位置，用于截流
    private var lastLocation: CLLocation?
    // 上一次位置更新时记录的时间，用于截流
    private var lastLocationUpdateTime: Date?
    
    // 当前赛道可加入的队伍
    @Published var availableTeams: [Team] = []
    
    
    init() {}
    
    func resetAll() {
        events = []
        tracks = []
        leaderboardEntries = []
        selectedEvent = nil
        selectedTrack = nil
    }
    
    func fetchEvents(with city: String) {
        events.removeAll()
        selectedEvent = nil
        if city == "未知" { return }
        
        isEventsLoading = true
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
                            self.selectedTrack = self.tracks[0]
                        }
                    }
                }
            default: break
            }
        }
    }
    
    // 切换赛事
    func switchEvent(to event: RunningEvent) {
        selectedEvent?.tracks = tracks  // 缓存赛事里的所有赛道
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
        
        // 重新获取排行榜数据
        //fetchLeaderboard(gender: gender, reset: true)
    }
    
    // 验证队伍是否属于所选赛道
    func verifyTrack() -> Bool {
        return true
    }
    
    // 验证用户是否在队伍内
    func verifyInTeam(teamCode: String) -> Bool {
        // 实际应用中应该向服务器验证
        // 模拟验证队伍码
        let allJoinedTeams = competitionManager.myCreatedTeams + competitionManager.myJoinedTeams
        return (allJoinedTeams.first(where: { $0.teamCode == teamCode }) != nil)
    }
    
    // 防止在同一个队伍内重复报名
    func verifyRepeatRegister(teamCode: String) -> Bool {
        let allJoinedTeams = competitionManager.myCreatedTeams + competitionManager.myJoinedTeams
        if let index = allJoinedTeams.firstIndex(where: { $0.teamCode == teamCode }), let memberIndex = allJoinedTeams[index].members.firstIndex(where: { $0.userID == user.user.userID }) {
            return allJoinedTeams[index].members[memberIndex].isRegistered
        }
        return true
    }
    
    // 验证队伍是否存在
    func verifyTeamCode(teamCode: String) -> Bool {
        // 验证服务器中是否存在该队伍
        let allTeams = competitionManager.myCreatedTeams + competitionManager.myJoinedTeams + competitionManager.myAppliedTeams + competitionManager.availableTeams
        return (allTeams.first(where: { $0.teamCode == teamCode }) != nil)
    }
    
    // 检查队伍是否处于锁定状态
    func verifyTeamLocked(teamCode: String) -> Bool {
        // 检查服务器中队伍的锁定状态
        if let index = availableTeams.firstIndex(where: { $0.teamCode == teamCode }) {
            return availableTeams[index].isLocked
        }
        
        return true
    }
    
    
    // 创建队伍
    func createTeam() {
        guard selectedTrack != nil else {
            print("当前赛道数据无效")
            return
        }
        
        // 重置表单数据
        teamTitle = ""
        teamDescription = ""
        teamSize = 5
        teamCompetitionDate = Date().addingTimeInterval(86400 * 7) // 默认一周后
        isPublic = false
        
        // 显示创建队伍表单
        showCreateTeamSheet = true
    }
    
    // 提交创建队伍表单
    func submitCreateTeamForm() {
        guard !teamTitle.isEmpty else { return }
        guard let event = selectedEvent else { return }
        guard let track = selectedTrack else { return }
        
        // 调用TeamManagementViewModel创建队伍
        let teamCode = createTeam(
            title: teamTitle,
            description: teamDescription,
            maxMembers: teamSize,
            competitionDate: teamCompetitionDate,
            //eventId: event.eventIndex,
            //trackId: track.trackIndex,
            eventName: event.name,
            trackName: track.name,
            isPublic: isPublic
        )
        
        // 关闭sheet
        showCreateTeamSheet = false
        
        // 显示队伍码的提示或其他成功反馈
        print("成功创建队伍，队伍码: \(teamCode)")
    }
    
    // 获取当前赛道可加入的队伍
    func fetchAvailableTeams() {
        // 模拟从服务器获取数据
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.availableTeams = self.competitionManager.availableTeams
        }
    }
    
    // 创建新队伍
    func createTeam(title: String, description: String, maxMembers: Int, competitionDate: Date, eventName: String, trackName: String, isPublic: Bool) -> String {
        // 生成队伍码
        let teamCode = generateTeamCode()
        
        // 创建一个新的队伍
        let newTeam = Team(
            captainID: user.user.userID,
            captainName: user.user.nickname,
            captainAvatar: user.user.avatarImageURL,
            title: title,
            description: description,
            maxMembers: maxMembers,
            members: [
                TeamMember(
                    userID: user.user.userID,
                    name: user.user.nickname,
                    avatar: user.user.avatarImageURL,
                    isLeader: true,
                    joinTime: Date(),
                    isRegistered: false
                ),
                TeamMember(
                    userID: "测试2队员id",
                    name: "测试2队员",
                    avatar: "测试2队员头像",
                    isLeader: false,
                    joinTime: Date(),
                    isRegistered: false
                )
            ],
            teamCode: teamCode,
            eventName: eventName,
            trackName: trackName,
            //trackID: trackId,
            //eventID: eventId,
            creationDate: Date(),
            competitionDate: competitionDate,
            pendingRequests: [
                TeamMember(
                    userID: "测试1队员id",
                    name: "测试1队员",
                    avatar: "测试1队员头像",
                    isLeader: false,
                    joinTime: Date(),
                    isRegistered: false
                )
            ],
            isPublic: isPublic
        )
        
        // 添加到我创建的队伍列表
        competitionManager.myCreatedTeams.append(newTeam)
        // 如果为公开队伍则添加到对应赛道的队伍列表中
        if newTeam.isPublic {
            competitionManager.availableTeams.append(newTeam)
        }
        
        // 实际应用中，这里应该向服务器发起请求保存队伍信息
        
        // 返回队伍码
        return teamCode
    }
    
    // 生成队伍码
    private func generateTeamCode() -> String {
        // 生成6位数字和字母组合的队伍码
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<6).map { _ in letters.randomElement()! })
    }
    
    func fetchLeaderboard(gender: String, reset: Bool = false) {
        // 确保有选中的赛事和赛道
        //print("count+: \(leaderboardFetchCount)")
        guard selectedEvent != nil else {
            print("没有可用的赛事数据")
            // 清空排行榜数据
            if reset {
                leaderboardEntries = []
            }
            return
        }
        
        guard selectedTrack != nil else {
            print("没有可用的赛道数据")
            // 清空排行榜数据
            if reset {
                leaderboardEntries = []
            }
            return
        }
        
        // 模拟网络请求，这里需要替换成真实的网络请求代码
        if reset {
            currentLeaderboardPage = 0
            leaderboardEntries = []
        }
        
        isLoadingMore = true
        leaderboardFetchCount += 1
        
        // 模拟网络请求
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
            // 模拟不同赛事和赛道的排行榜数据
            var newEntries: [LeaderboardEntry] = []
            
            // 根据不同的赛事和赛道生成不同的排行榜数据
            for i in 1...20 {
                let userId = "user\(i + self.currentLeaderboardPage * 20)_\(self.selectedEvent?.name)_\(self.selectedTrack?.name)"
                let nickname = "选手\(i + self.currentLeaderboardPage * 20)"
                
                // 根据性别和赛道生成不同的成绩
                let baseTime: Double = 5555
                
                // 添加一些随机性
                let randomFactor = Double(arc4random_uniform(1000)) / 10.0
                let bestTime = baseTime + randomFactor - Double(i) * 30.0 // 排名越高，成绩越好
                
                newEntries.append(LeaderboardEntry(
                    user_id: userId,
                    nickname: nickname,
                    best_time: bestTime,
                    avatarImageURL: "/avatar/\(userId).jpg",
                    predictBonus: 0
                ))
            }
            
            DispatchQueue.main.async {
                self.leaderboardFetchCount -= 1
                //print("count-: \(self.leaderboardFetchCount)")
                if self.leaderboardFetchCount == 0 {
                    self.leaderboardEntries.append(contentsOf: newEntries)
                    self.currentLeaderboardPage += 1
                    self.isLoadingMore = false
                    print("fetchLeaderboard success: \(gender),\(self.currentLeaderboardPage)")
                }
            }
        }
    }
}
