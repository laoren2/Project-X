//
//  UserViewModel.swift
//  sportsx
//  todo: 简化逻辑，将主页 noNeedBack 的 UserView 和 NeedBack 的 UserView 分开
//
//  Created by 任杰 on 2025/4/18.
//

import Foundation
import SwiftUI

class UserViewModel: ObservableObject {
    let navigationManager = NavigationManager.shared
    let userManager = UserManager.shared
    
    @Published var sport: SportName = .Default // 默认运动
    
    @Published var currentUser = User()         // 非登录用户的用户数据
    @Published var avatarImage: UIImage?        // 非登录用户的头像
    @Published var backgroundImage: UIImage?    // 非登录用户的封面
    @Published var backgroundColor: Color = .defaultBackground      // 非登录用户的封面背景色
    @Published var followerCount: Int = 0       // 非登录用户的粉丝数
    @Published var followedCount: Int = 0       // 非登录用户的关注数
    @Published var friendCount: Int = 0         // 非登录用户的好友数
    
    @Published var relationship: UserRelationshipStatus = .none     // 与当前登录用户的关系
    
    @Published var showSidebar = false  // 侧边栏是否显示
    
    // 赛季总积分
    @Published var totalScore: Int?
    // 赛季总积分排名
    @Published var totalRank: Int?
    // 赛季荣誉
    //var cups: [Cup] = []
    // 赛季总参与时间
    @Published var totalTime: Int = 0
    // 赛季总参与路程
    @Published var totalMeters: Int = 0
    // 赛季获得总奖金
    @Published var totalBonus: Int = 0
    
    // 赛季赛事积分记录汇总
    @Published var competitionScoreRecords: [CareerRecord] = []
    
    @Published var gameSummaryCards: [GameSummaryCard] = []
    
    @Published var selectedSeason: SeasonSelectableInfo?
    @Published var seasons: [SeasonSelectableInfo] = []
    
    var userID: String
    var isNeedBack: Bool
    let sidebarWidth: CGFloat = 300 // 侧边栏宽度
    
    
    init(id: String, needBack: Bool) {
        userID = id
        isNeedBack = needBack
        
        // 外部入口且不是已登录用户请求数据存入currentUser
        if isNeedBack {
            if userManager.user.userID == userID {
                sport = userManager.user.defaultSport
                queryHistoryCareers()
                queryCurrentRecords()
                return
            } else {
                self.fetchUserInfo()
            }
        } else {
            userManager.fetchMeRole()
            Task {
                await userManager.fetchMeInfo()
                await MainActor.run {
                    sport = userManager.user.defaultSport
                }
            }
        }
    }
    
    func fetchUserInfo() {
        guard var components = URLComponents(string: "/user/anyone") else { return }
        components.queryItems = [
            URLQueryItem(name: "user_id", value: userID)
        ]
        if userManager.isLoggedIn {
            components.queryItems?.append(URLQueryItem(name: "my_id", value: userManager.user.userID))
        }
        guard let urlPath = components.string else { return }
        
        let request = APIRequest(path: urlPath, method: .get, requiresAuth: false)
        
        NetworkService.sendRequest(with: request, decodingType: FetchAnyUserResponse.self, showLoadingToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        self.relationship = unwrappedData.relationship
                        self.friendCount = unwrappedData.relation.friends
                        self.followedCount = unwrappedData.relation.followed
                        self.followerCount = unwrappedData.relation.follower
                        self.currentUser = User(from: unwrappedData.user)
                        self.sport = unwrappedData.user.default_sport
                        self.downloadImages(avatar_url: self.currentUser.avatarImageURL, background_url: self.currentUser.backgroundImageURL)
                    }
                }
            default: break
            }
        }
    }
    
    func queryHistoryCareers() {
        seasons = [SeasonSelectableInfo(seasonID: "未知", seasonName: "未知")]
        selectedSeason = nil
        guard var components = URLComponents(string: "/competition/\(sport.rawValue)/query_history_seasons") else { return }
        guard let urlPath = components.string else { return }
        let request = APIRequest(path: urlPath, method: .get)
        
        NetworkService.sendRequest(with: request, decodingType: SeasonSelectableResponse.self, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        var tempSeasons: [SeasonSelectableInfo] = []
                        for season in unwrappedData.seasons {
                            tempSeasons.append(SeasonSelectableInfo(from: season))
                        }
                        self.seasons = tempSeasons
                        if !self.seasons.isEmpty {
                            self.selectedSeason = self.seasons[0]
                        }
                    }
                }
            default: break
            }
        }
    }
    
    func queryCareerData() {
        totalScore = nil
        totalRank = nil
        guard let season = selectedSeason else { return }
        
        guard var components = URLComponents(
            string: "/competition/\(sport.rawValue)/" + (isNeedBack ? "query_user_career_data" : "query_me_career_data" )
        ) else { return }
        components.queryItems = [
            URLQueryItem(name: "season_id", value: season.seasonID)
        ]
        if isNeedBack {
            components.queryItems?.append(URLQueryItem(name: "user_id", value: userID))
        }
        guard let urlPath = components.string else { return }
        let request = APIRequest(path: urlPath, method: .get, requiresAuth: !isNeedBack)
        
        NetworkService.sendRequest(with: request, decodingType: CareerDataDTO.self, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        self.totalScore = unwrappedData.total_score
                        self.totalRank = unwrappedData.total_rank
                    }
                }
            default: break
            }
        }
    }
    
    func queryCareerRecords() {
        competitionScoreRecords = []
        guard let season = selectedSeason else { return }
        
        guard var components = URLComponents(
            string: "/competition/\(sport.rawValue)/" + (isNeedBack ? "query_user_career_records" : "query_me_career_records")
        ) else { return }
        components.queryItems = [
            URLQueryItem(name: "season_id", value: season.seasonID)
        ]
        if isNeedBack {
            components.queryItems?.append(URLQueryItem(name: "user_id", value: userID))
        }
        guard let urlPath = components.string else { return }
        let request = APIRequest(path: urlPath, method: .get, requiresAuth: !isNeedBack)
        
        NetworkService.sendRequest(with: request, decodingType: CareerRecordResponse.self, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        for record in unwrappedData.records {
                            self.competitionScoreRecords.append(CareerRecord(from: record))
                        }
                    }
                }
            default: break
            }
        }
    }
    
    func queryCurrentRecords() {
        gameSummaryCards = []
        guard var components = URLComponents(
            string: "/competition/\(sport.rawValue)/" + (isNeedBack ? "query_user_current_best_records" : "query_me_current_best_records")
        ) else { return }
        if isNeedBack {
            components.queryItems = [
                URLQueryItem(name: "user_id", value: userID)
            ]
        }
        guard let urlPath = components.string else { return }
        let request = APIRequest(path: urlPath, method: .get, requiresAuth: !isNeedBack)
        
        NetworkService.sendRequest(with: request, decodingType: GameSummaryResponse.self, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        for record in unwrappedData.records {
                            self.gameSummaryCards.append(GameSummaryCard(from: record))
                        }
                    }
                }
            default: break
            }
        }
    }
    
    func downloadImages(avatar_url: String, background_url: String) {
        NetworkService.downloadImage(from: avatar_url) { image in
            if let image = image {
                DispatchQueue.main.async {
                    self.avatarImage = image
                }
            } else {
                print("下载头像失败")
            }
        }
        NetworkService.downloadImage(from: background_url) { image in
            if let image = image {
                DispatchQueue.main.async {
                    self.backgroundImage = image
                }
                if let avg = ImageTool.averageColor(from: image) {
                    DispatchQueue.main.async {
                        self.backgroundColor = avg.bestSoftDarkReadableColor()
                    }
                }
            } else {
                print("下载封面失败")
            }
        }
    }
    
    func follow() {
        guard var components = URLComponents(string: "/user/follow") else { return }
        components.queryItems = [
            URLQueryItem(name: "user_id", value: userID)
        ]
        guard let urlPath = components.string else { return }
        
        let request = APIRequest(path: urlPath, method: .post, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: UserRelationshipStatus.self, showErrorToast: true) {result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        self.relationship = unwrappedData
                    }
                }
                self.updateRelationInfo()
                self.userManager.updateRelationInfo()
            default: break
            }
        }
    }
    
    func cancelFollow() {
        guard var components = URLComponents(string: "/user/cancel_follow") else { return }
        components.queryItems = [
            URLQueryItem(name: "user_id", value: userID)
        ]
        guard let urlPath = components.string else { return }
        
        let request = APIRequest(path: urlPath, method: .post, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: UserRelationshipStatus.self, showErrorToast: true) {result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        self.relationship = unwrappedData
                    }
                }
                self.updateRelationInfo()
                self.userManager.updateRelationInfo()
            default: break
            }
        }
    }
    
    func updateRelationInfo() {
        guard var components = URLComponents(string: "/user/relation_info") else { return }
        components.queryItems = [
            URLQueryItem(name: "user_id", value: userID)
        ]
        guard let urlPath = components.string else { return }
        
        let request = APIRequest(path: urlPath, method: .get, requiresAuth: false)
        
        NetworkService.sendRequest(with: request, decodingType: RelationInfoResponse.self, showErrorToast: true) {result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        self.friendCount = unwrappedData.friends
                        self.followerCount = unwrappedData.follower
                        self.followedCount = unwrappedData.followed
                    }
                }
            default: break
            }
        }
    }
}

struct CareerRecord: Identifiable {
    var id: String { recordID }
    let recordID: String
    let trackID: String
    let trackName: String
    let eventName: String
    let region: String
    // 赛道对应积分
    let trackScore: Int
    // 用户获得的积分
    let score: Int
    let recordDate: Date?
    
    init (from record: CareerRecordDTO) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.recordID = record.record_id
        self.trackID = record.track_id
        self.trackName = record.track_name
        self.eventName = record.event_name
        self.region = record.region
        self.trackScore = record.track_score
        self.score = record.score
        self.recordDate = formatter.date(from: record.record_date)
    }
}

struct CareerRecordDTO: Codable {
    let record_id: String
    let track_id: String
    let track_name: String
    let event_name: String
    let region: String
    let track_score: Int
    let score: Int
    let record_date: String
}

struct CareerRecordResponse: Codable {
    let records: [CareerRecordDTO]
}

struct CareerDataDTO: Codable {
    let total_score: Int?
    let total_rank: Int?
    //let total_time: Double
    //let total_distance: Double
    //let total_bonus: Double
}

enum CupLevel {
    case top1
    case top2
    case top3
    case top10
    case top1percent
    case top3percent
    case top10percent
}

struct Cup: Identifiable {
    let id = UUID()
    let level: CupLevel
    let image: String
}

struct SetUpItemView<Content: View>: View {
    let icon: String
    let title: String
    let showChevron: Bool
    let showDivider: Bool
    let isDarkScheme: Bool
    let onEdit: (() -> Void)
    let trailingView: (() -> Content)
    
    
    init(
        icon: String,
        title: String,
        showChevron: Bool = true,
        showDivider: Bool = true,
        isDarkScheme: Bool = true,
        onEdit: @escaping (() -> Void),
        @ViewBuilder trailingView: @escaping () -> Content =  { EmptyView() }
    ) {
        self.icon = icon
        self.title = title
        self.showChevron = showChevron
        self.showDivider = showDivider
        self.isDarkScheme = isDarkScheme
        self.onEdit = onEdit
        self.trailingView = trailingView
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Image(systemName: icon)
                    .foregroundColor(isDarkScheme ? .secondText : .black)
                    .frame(width: 18, height: 18, alignment: .leading)
                
                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(isDarkScheme ? .secondText : .black)
                    
                Spacer()
                
                trailingView()
                
                if showChevron {
                    Image(systemName: "chevron.right")
                        .foregroundColor(isDarkScheme ? .white.opacity(0.8) : .black.opacity(0.8))
                }
            }
            .padding(.vertical, 15)
            .padding(.horizontal)
            
            if showDivider {
                Divider()
                    .padding(.leading, 80)
            }
        }
        .background(.ultraThinMaterial)
        .exclusiveTouchTapGesture {
            onEdit()
        }
    }
}

struct SeasonSelectableInfo: Identifiable, Equatable {
    var id: String { seasonID }
    let seasonID: String
    let seasonName: String
    
    init(seasonID: String, seasonName: String) {
        self.seasonID = seasonID
        self.seasonName = seasonName
    }
    
    init(from season: SeasonSelectableDTO) {
        self.seasonID = season.season_id
        self.seasonName = season.season_name
    }
    
    static func == (lhs: SeasonSelectableInfo, rhs: SeasonSelectableInfo) -> Bool {
        return lhs.id == rhs.id
    }
}

struct SeasonSelectableDTO: Codable {
    let season_id: String
    let season_name: String
}

struct SeasonSelectableResponse: Codable {
    let seasons: [SeasonSelectableDTO]
}
