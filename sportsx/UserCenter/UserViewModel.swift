//
//  UserViewModel.swift
//  sportsx
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
    @Published var totalScore: Int = 0
    // 赛季总积分排名
    @Published var totalRank: Int = 0
    // 赛季荣誉
    var cups: [Cup] = []
    // 赛季总参与时间
    @Published var totalTime: Int = 0
    // 赛季总参与路程
    @Published var totalMeters: Int = 0
    // 赛季获得总奖金
    @Published var totalBonus: Int = 0
    
    // 赛季赛事积分记录汇总
    var competitionScoreRecords: [TrackScoreRecord] = []
    
    var gameSummaryCards: [GameSummaryCard] = []
    
    var userID: String
    var isNeedBack: Bool
    let sidebarWidth: CGFloat = 300 // 侧边栏宽度
    
    
    init(id: String, needBack: Bool) {
        userID = id
        isNeedBack = needBack
        
        competitionScoreRecords.append(TrackScoreRecord(scoreLevel: 100, score: 20))
        competitionScoreRecords.append(TrackScoreRecord(scoreLevel: 200, score: 150))
        competitionScoreRecords.append(TrackScoreRecord(scoreLevel: 500, score: 50))
        competitionScoreRecords.append(TrackScoreRecord(scoreLevel: 100, score: 20))
        competitionScoreRecords.append(TrackScoreRecord(scoreLevel: 200, score: 150))
        competitionScoreRecords.append(TrackScoreRecord(scoreLevel: 500, score: 50))
        competitionScoreRecords.append(TrackScoreRecord(scoreLevel: 100, score: 20))
        competitionScoreRecords.append(TrackScoreRecord(scoreLevel: 200, score: 150))
        competitionScoreRecords.append(TrackScoreRecord(scoreLevel: 500, score: 50))
        cups.append(Cup(level: .top1, image: "medal.fill"))
        cups.append(Cup(level: .top10, image: "medal.fill"))
        cups.append(Cup(level: .top10percent, image: "medal.fill"))
        let cards1: [MagicCard] = [
            MagicCard(id: "card2", modelID: "model_001", name: "Water Serpent", type: "魔法", level: "3", imageURL: "Ads", compensationValue: 0, sensorLocation: 0b000001, lucky: 31.2, energy: 80, grade: "B", description: "test"),
            MagicCard(id: "card3", modelID: "model_002", name: "Earth Golem", type: "动作", level: "4", imageURL: "Ads", compensationValue: 0, sensorLocation: 0b000010, lucky: 96.5, energy: 100, grade: "S", description: "test"),
            MagicCard(id: "card1", modelID: "model_001", name: "Fire Dragon", type: "团队", level: "5", imageURL: "Ads", compensationValue: 0, sensorLocation: 0b000001, lucky: 86.7, energy: 91, grade: "B+", description: "test")
        ]
        let cards2: [MagicCard] = [
            MagicCard(id: "card2", modelID: "model_001", name: "Water Serpent", type: "魔法", level: "3", imageURL: "Ads", compensationValue: 0, sensorLocation: 0b000001, lucky: 31.2, energy: 80, grade: "B", description: "test"),
            MagicCard(id: "card3", modelID: "model_002", name: "Earth Golem", type: "动作", level: "4", imageURL: "Ads", compensationValue: 0, sensorLocation: 0b000010, lucky: 96.5, energy: 100, grade: "S", description: "test"),
            MagicCard(id: "card1", modelID: "model_001", name: "Fire Dragon", type: "团队", level: "5", imageURL: "Ads", compensationValue: 0, sensorLocation: 0b000001, lucky: 86.7, energy: 91, grade: "B+", description: "test"),
            MagicCard(id: "card4", modelID: "model_001", name: "Fire Dragon", type: "团队", level: "5", imageURL: "Ads", compensationValue: 0, sensorLocation: 0b000001, lucky: 86.7, energy: 91, grade: "B+", description: "test"),
            MagicCard(id: "card5", modelID: "model_001", name: "Water Serpent", type: "魔法", level: "3", imageURL: "Ads", compensationValue: 0, sensorLocation: 0b000001, lucky: 31.2, energy: 80, grade: "B", description: "test")
        ]
        gameSummaryCards.append(GameSummaryCard(eventname: "赛事1", trackName: "赛道1", cityName: "上海", best_time: 55.55, rank: 5, previewBonus: 288, magicCards: cards1))
        gameSummaryCards.append(GameSummaryCard(eventname: "赛事1", trackName: "赛道2", cityName: "上海", best_time: 96.20, rank: 155, previewBonus: 40, magicCards: cards2))
        gameSummaryCards.append(GameSummaryCard(eventname: "赛事2", trackName: "赛道1", cityName: "上海", best_time: 105.11, rank: 862, previewBonus: 10, magicCards: cards2))
        
        // 外部入口且不是已登录用户请求数据存入currentUser
        if isNeedBack {
            if userManager.user.userID == userID {
                return
            } else {
                self.fetchUserInfo()
            }
        } else {
            userManager.fetchMeRole()
            userManager.fetchMeInfo()
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
                        self.downloadImages(avatar_url: self.currentUser.avatarImageURL, background_url: self.currentUser.backgroundImageURL)
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
                if let avg = ColorComputer.averageColor(from: image) {
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

struct TrackScoreRecord: Identifiable {
    let id = UUID()
    let name: String
    let eventName: String
    let city: String
    // 赛道对应积分级别
    let scoreLevel: Int
    // 用户获得的积分
    let score: Int
    
    init (
        name: String = "赛道名",
        eventName: String = "未知",
        city: String = "未知",
        scoreLevel: Int = 0,
        score: Int = 0
    ) {
        self.name = name
        self.eventName = eventName
        self.city = city
        self.scoreLevel = scoreLevel
        self.score = score
    }
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
        .onTapGesture {
            onEdit()
        }
    }
}

