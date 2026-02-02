//
//  LoginViewModel.swift
//  sportsx
//
//  Created by 任杰 on 2024/8/8.
//

import Foundation
import Combine
import SwiftUI


class UserManager: ObservableObject {
    static let shared = UserManager()
    
    let navigationManager = NavigationManager.shared
    let config = GlobalConfig.shared
    @Published var user: User = User()          // 存储用户信息
    @Published var avatarImage: UIImage?        // 用户头像
    @Published var backgroundImage: UIImage?    // 用户封面
    @Published var backgroundColor: Color = .defaultBackground  // 用户封面背景色
    
    @Published var followerCount: Int = 0
    @Published var followedCount: Int = 0
    @Published var friendCount: Int = 0
    
    @Published var isLoggedIn: Bool = false
    @Published var showingLogin: Bool = false
    
    @Published var mailboxUnreadCount: Int = 0
    
    @Published var role: UserRole = UserRole.user  // 用户权限
    
    var originTransactionID: String? = nil
    
    var userRegion: LocalizedStringKey? {
        for (_, cities) in regionTable_HK {
            if let index = cities.firstIndex(where: { $0.regionID == user.location }) {
                return LocalizedStringKey(cities[index].regionName)
            }
        }
        for (_, cities) in regionTable {
            if let index = cities.firstIndex(where: { $0.regionID == user.location }) {
                return LocalizedStringKey(cities[index].regionName)
            }
        }
        return nil
    }
    
    private init() {}
    
    @MainActor
    func bootstrap() async {
        if KeychainHelper.standard.loadToken() {
            print("read access_token success")
            loadUserInfoCache()
            isLoggedIn = true
        } else {
            print("read access_token unsuccess")
            isLoggedIn = false
        }
    }
    
    // 登出账号
    func logoutUser() {
        user = User()
        avatarImage = nil
        backgroundImage = nil
        backgroundColor = .defaultBackground
        followerCount = 0
        followedCount = 0
        friendCount = 0
        
        role = UserRole.user
        
        isLoggedIn = false
        showingLogin = true
        
        KeychainHelper.standard.deleteToken()
        clearUserInfoCache()
        config.refreshCompetitionView = true
    }
    
    // 注销账号
    func cancelUser() {
        let request = APIRequest(path: "/user/delete", method: .post, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: EmptyResponse.self, showLoadingToast: true, showErrorToast: true) { result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    self.logoutUser()
                    self.navigationManager.backToHome()
                }
            default: break
            }
        }
    }
    
    func queryMailBox() {
        let request = APIRequest(path: "/mailbox/query_unread_status", method: .get, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: MailBoxStatus.self) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        self.mailboxUnreadCount = unwrappedData.unread_count
                    }
                }
            default: break
            }
        }
    }
    
    func fetchMeRole() {
        let request = APIRequest(path: "/user/me/role", method: .get, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: UserRole.self) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        self.role = unwrappedData
                    }
                }
            default: break
            }
        }
    }
    
    func fetchMeInfo() async {
        let request = APIRequest(path: "/user/me", method: .get, requiresAuth: true)
        
        let result = await NetworkService.sendAsyncRequest(with: request, decodingType: FetchMeUserResponse.self, showErrorToast: true)
        
        switch result {
        case .success(let data):
            if let unwrappedData = data {
                let user = unwrappedData.user
                let relation = unwrappedData.relation
                await MainActor.run {
                    friendCount = relation.friends
                    followerCount = relation.follower
                    followedCount = relation.followed
                    originTransactionID = unwrappedData.origin_transaction_id
                    self.user = User(from: user)
                    saveUserInfoToCache()
                }
                self.downloadImages(avatar_url: user.avatar_image_url, background_url: user.background_image_url)
            }
        default: break
        }
    }
    
    func downloadImages(avatar_url: String, background_url: String) {
        let avatarPath = getLocalImagePath(filename: "avatar.jpg")
        let backgroundPath = getLocalImagePath(filename: "background.jpg")

        NetworkService.downloadImage(from: avatar_url) { image in
            if let image = image {
                DispatchQueue.main.async {
                    self.avatarImage = image
                }
                if let data = image.pngData() {
                    try? data.write(to: avatarPath)
                }
            } else {
                DispatchQueue.main.async {
                    self.avatarImage = UIImage(named: "broken_image")
                }
            }
        }

        NetworkService.downloadImage(from: background_url) { image in
            if let image = image {
                DispatchQueue.main.async {
                    self.backgroundImage = image
                }
                if let data = image.pngData() {
                    try? data.write(to: backgroundPath)
                }
                if let avg = ImageTool.averageColor(from: image) {
                    DispatchQueue.main.async {
                        self.backgroundColor = avg.bestSoftDarkReadableColor()
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.backgroundImage = UIImage(named: "broken_image")
                }
            }
        }
    }
    
    func updateUserLocation(regionID: String) {
        guard var components = URLComponents(string: "/user/update_location") else { return }
        components.queryItems = [
            URLQueryItem(name: "regionID", value: regionID)
        ]
        guard let urlPath = components.string else { return }
        
        let request = APIRequest(path: urlPath, method: .post, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: EmptyResponse.self, showErrorToast: true) { _ in } 
    }
    
    func updateRelationInfo() {
        guard var components = URLComponents(string: "/user/relation_info") else { return }
        components.queryItems = [
            URLQueryItem(name: "user_id", value: user.userID)
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
    
    private func getLocalImagePath(filename: String) -> URL {
        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return directory.appendingPathComponent(filename)
    }
    
    func saveUserInfoToCache() {
        let defaults = UserDefaults.standard
        defaults.set(user.userID, forKey: "user.userID")
        defaults.set(user.appleIAPToken, forKey: "user.appleIAPToken")
        defaults.set(user.nickname, forKey: "user.nickname")
        defaults.set(user.phoneNumber, forKey: "user.phoneNumber")
        defaults.set(user.apple_email, forKey: "user.appleEmail")
        defaults.set(user.email, forKey: "user.email")
        defaults.set(user.avatarImageURL, forKey: "user.avatarImageURL")
        defaults.set(user.backgroundImageURL, forKey: "user.backgroundImageURL")
        defaults.set(user.introduction, forKey: "user.introduction")
        defaults.set(user.gender?.rawValue, forKey: "user.gender")
        defaults.set(user.birthday, forKey: "user.birthday")
        defaults.set(user.location, forKey: "user.location")
        defaults.set(user.identityAuthName, forKey: "user.identityAuthName")
        defaults.set(user.isRealnameAuth, forKey: "user.isRealnameAuth")
        defaults.set(user.isIdentityAuth, forKey: "user.isIdentityAuth")
        defaults.set(user.isDisplayGender, forKey: "user.isDisplayGender")
        defaults.set(user.isDisplayAge, forKey: "user.isDisplayAge")
        defaults.set(user.isDisplayLocation, forKey: "user.isDisplayLocation")
        defaults.set(user.enableAutoLocation, forKey: "user.enableAutoLocation")
        defaults.set(user.isDisplayIdentity, forKey: "user.isDisplayIdentity")
        defaults.set(followedCount, forKey: "followedCount")
        defaults.set(followerCount, forKey: "followerCount")
        defaults.set(friendCount, forKey: "friendCount")
        defaults.set(user.defaultSport.rawValue, forKey: "user.defaultSport")
        defaults.set(user.isVip, forKey: "user.isVip")
    }
    
    private func loadUserInfoCache() {
        let defaults = UserDefaults.standard
        let genderRaw = defaults.string(forKey: "user.gender")
        let sportRaw = defaults.string(forKey: "user.defaultSport")
        let gender = genderRaw.flatMap { Gender(rawValue: $0) }
        let defaultSport = sportRaw.flatMap { SportName(rawValue: $0) }
        user = User(
            userID: defaults.string(forKey: "user.userID") ?? "未知",
            appleIAPToken: defaults.string(forKey: "user.appleIAPToken") ?? "未知",
            nickname: defaults.string(forKey: "user.nickname") ?? "未登录",
            phoneNumber: defaults.string(forKey: "user.phoneNumber"),
            apple_email: defaults.string(forKey: "user.appleEmail"),
            email: defaults.string(forKey: "user.email"),
            avatarImageURL: defaults.string(forKey: "user.avatarImageURL") ?? "",
            backgroundImageURL: defaults.string(forKey: "user.backgroundImageURL") ?? "",
            introduction: defaults.string(forKey: "user.introduction"),
            gender: gender,
            birthday: defaults.string(forKey: "user.birthday"),
            location: defaults.string(forKey: "user.location"),
            identityAuthName: defaults.string(forKey: "user.identityAuthName"),
            isRealnameAuth: defaults.bool(forKey: "user.isRealnameAuth"),
            isIdentityAuth: defaults.bool(forKey: "user.isIdentityAuth"),
            isDisplayGender: defaults.bool(forKey: "user.isDisplayGender"),
            isDisplayAge: defaults.bool(forKey: "user.isDisplayAge"),
            isDisplayLocation: defaults.bool(forKey: "user.isDisplayLocation"),
            enableAutoLocation: defaults.bool(forKey: "user.enableAutoLocation"),
            isDisplayIdentity: defaults.bool(forKey: "user.isDisplayIdentity"),
            defaultSport: defaultSport ?? .Bike,
            isVip: defaults.bool(forKey: "user.isVip")
        )
        
        followedCount = defaults.integer(forKey: "followedCount")
        followerCount = defaults.integer(forKey: "followerCount")
        friendCount = defaults.integer(forKey: "friendCount")

        let avatarPath = getLocalImagePath(filename: "avatar.jpg")
        let backgroundPath = getLocalImagePath(filename: "background.jpg")

        if let avatarData = try? Data(contentsOf: avatarPath),
           let avatarImage = UIImage(data: avatarData) {
            self.avatarImage = avatarImage
        }

        if let bgData = try? Data(contentsOf: backgroundPath),
           let bgImage = UIImage(data: bgData) {
            self.backgroundImage = bgImage

            if let avg = ImageTool.averageColor(from: bgImage) {
                self.backgroundColor = avg.bestSoftDarkReadableColor()
            }
        }
    }
    
    private func clearUserInfoCache() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "user.userID")
        defaults.removeObject(forKey: "user.appleIAPToken")
        defaults.removeObject(forKey: "user.nickname")
        defaults.removeObject(forKey: "user.phoneNumber")
        defaults.removeObject(forKey: "user.appleEmail")
        defaults.removeObject(forKey: "user.email")
        defaults.removeObject(forKey: "user.avatarImageURL")
        defaults.removeObject(forKey: "user.backgroundImageURL")
        defaults.removeObject(forKey: "user.introduction")
        defaults.removeObject(forKey: "user.gender")
        defaults.removeObject(forKey: "user.birthday")
        defaults.removeObject(forKey: "user.location")
        defaults.removeObject(forKey: "user.identityAuthName")
        defaults.removeObject(forKey: "user.isRealnameAuth")
        defaults.removeObject(forKey: "user.isIdentityAuth")
        defaults.removeObject(forKey: "user.isDisplayGender")
        defaults.removeObject(forKey: "user.isDisplayAge")
        defaults.removeObject(forKey: "user.isDisplayLocation")
        defaults.removeObject(forKey: "user.enableAutoLocation")
        defaults.removeObject(forKey: "user.isDisplayIdentity")
        defaults.removeObject(forKey: "user.defaultSport")
        defaults.removeObject(forKey: "user.isVip")
        
        defaults.removeObject(forKey: "followedCount")
        defaults.removeObject(forKey: "followerCount")
        defaults.removeObject(forKey: "friendCount")
        
        let avatarPath = getLocalImagePath(filename: "avatar.png")
        let backgroundPath = getLocalImagePath(filename: "background.png")
        
        try? FileManager.default.removeItem(at: avatarPath)
        try? FileManager.default.removeItem(at: backgroundPath)
    }
}

enum DailyTaskType: String, Codable {
    case distance = "distance"
    case time = "time"
    
    var disPlayName: String {
        switch self {
        case .distance:
            return "km"
        case .time:
            return "min"
        }
    }
}

struct DailyTaskRewardResponse: Codable {
    let ccasset_type: CCAssetType?
    let ccasset_amount: Int?
    let cpasset_id: String?
    let cpasset_amount: Int?
}

struct DailyTaskDTO: Codable {
    let type: DailyTaskType
    let total_progress: Double
    let reward_stage1_type: CCAssetType
    let reward_stage1: Int
    let is_reward1_received: Bool
    let reward_stage2_type: CCAssetType
    let reward_stage2: Int
    let is_reward2_received: Bool
    let reward_stage3_url: String
    let is_reward3_received: Bool
    let progress: Double
}

struct DailyTaskInfo {
    let taskType: DailyTaskType
    let progress: Double
    let totalProgress: Double               // 任务总目标
    
    let reward_stage1_type: CCAssetType
    let reward_stage1: Int
    var reward_stage1_status: RewardState
    let reward_stage2_type: CCAssetType
    let reward_stage2: Int
    var reward_stage2_status: RewardState
    let reward_stage3_url: String
    var reward_stage3_status: RewardState
    
    init(from task: DailyTaskDTO) {
        taskType = task.type
        progress = task.progress
        totalProgress = task.total_progress
        reward_stage1 = task.reward_stage1
        reward_stage1_type = task.reward_stage1_type
        reward_stage1_status = task.is_reward1_received ? .claimed : (progress / totalProgress > 0.34 ? .available : .future)
        reward_stage2 = task.reward_stage2
        reward_stage2_type = task.reward_stage2_type
        reward_stage2_status = task.is_reward2_received ? .claimed : (progress / totalProgress > 0.67 ? .available : .future)
        reward_stage3_url = task.reward_stage3_url
        reward_stage3_status = task.is_reward3_received ? .claimed : (progress / totalProgress > 1.0 ? .available : .future)
    }
}

class DailyTaskManager: ObservableObject {
    static let shared = DailyTaskManager()
    
    @Published var task: DailyTaskInfo?
    @Published var reward1Loading: Bool = false
    @Published var reward2Loading: Bool = false
    @Published var reward3Loading: Bool = false
    
    
    private init() {}
    
    // 暂时硬编码奖励信息...
    func claimReward(stage: Int, sport: SportName, rewardImage: String? = nil, rewardCount: Int, rewardURL: String? = nil) {
        if stage == 1 {
            guard !reward1Loading else { return }
            reward1Loading = true
        }
        if stage == 2 {
            guard !reward2Loading else { return }
            reward2Loading = true
        }
        if stage == 3 {
            guard !reward3Loading else { return }
            reward3Loading = true
        }
        
        guard var components = URLComponents(string: "/competition/\(sport.rawValue)/claimed_daily_task_reward") else { return }
        components.queryItems = [
            URLQueryItem(name: "stage", value: "\(stage)")
        ]
        guard let urlPath = components.string else { return }
        
        let request = APIRequest(path: urlPath, method: .post, requiresAuth: true)
        NetworkService.sendRequest(with: request, decodingType: DailyTaskRewardResponse.self, showErrorToast: true) { result in
            DispatchQueue.main.async {
                if stage == 1 { self.reward1Loading = false }
                if stage == 2 { self.reward2Loading = false }
                if stage == 3 { self.reward3Loading = false }
                switch result {
                case .success(let data):
                    if let unwrappedData = data {
                        if let ccasset_type = unwrappedData.ccasset_type, let ccasset_amount = unwrappedData.ccasset_amount {
                            AssetManager.shared.updateCCAsset(type: ccasset_type, newBalance: ccasset_amount)
                        }
                        if let cpasset_id = unwrappedData.cpasset_id, let cpasset_amount = unwrappedData.cpasset_amount {
                            AssetManager.shared.updateCPAsset(assetID: cpasset_id, newBalance: cpasset_amount)
                        }
                        if stage == 1 { self.task?.reward_stage1_status = .claimed }
                        if stage == 2 { self.task?.reward_stage2_status = .claimed }
                        if stage == 3 { self.task?.reward_stage3_status = .claimed }
                        PopupWindowManager.shared.presentPopup(
                            title: "popup.claim_reward.title",
                            bottomButtons: [
                                .confirm()
                            ]
                        ) {
                            VStack {
                                Text("popup.claim_reward.content")
                                HStack(spacing: 10) {
                                    if let image = rewardImage {
                                        HStack(spacing: 0) {
                                            Image(image)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 20)
                                            Text(" * \(rewardCount)")
                                                .font(.system(size: 15))
                                                .fontWeight(.semibold)
                                        }
                                    }
                                    HStack(spacing: 0) {
                                        if let url = rewardURL {
                                            CachedAsyncImage(
                                                urlString: url
                                            )
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 30)
                                            .clipped()
                                            Text(" * \(rewardCount)")
                                                .font(.system(size: 15))
                                                .fontWeight(.semibold)
                                        }
                                    }
                                }
                            }
                            .foregroundStyle(Color.white)
                        }
                    }
                default:
                    break
                }
            }
        }
    }
    
    func queryDailyTask(sport: SportName) {
        DispatchQueue.main.async {
            self.task = nil
        }
        let request = APIRequest(path: "/competition/\(sport.rawValue)/query_daily_task_status", method: .get, requiresAuth: true)
        NetworkService.sendRequest(with: request, decodingType: DailyTaskDTO.self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    guard let unwrappedData = data else {
                        self.task = nil
                        return
                    }
                    self.task = DailyTaskInfo(from: unwrappedData)
                default:
                    break
                }
            }
        }
    }
}

struct FetchBaseUserResponse: Codable {
    let user: UserDTO
}

struct FetchMeUserResponse: Codable {
    let user: UserDTO
    let relation: RelationInfoResponse
    let origin_transaction_id: String?   // 最近订阅交易的 origin_transaction_id
}

struct FetchAnyUserResponse: Codable {
    let user: UserDTO
    let relation: RelationInfoResponse
    let relationship: UserRelationshipStatus
}

enum UserStatus: String, Codable {
    case normal = "normal"
    case banned = "banned"
    case deleted = "deleted"
}

enum UserRole: String, Codable {
    case user = "user"
    case admin = "admin"
}

enum Gender: String, Codable {
    case male = "male"
    case female = "female"
    
    var displayName: String {
        switch self {
        case .male: return "common.male"
        case .female: return "common.female"
        }
    }
}

enum FeedbackMailType: String, Codable, CaseIterable {
    case iap = "iap"             // iap问题反馈
    case bug = "bug"             // bug问题反馈
    case feature = "feature"     // 功能建议反馈
    case report = "report"       // 举报
    case other = "other"         // 其他
    
    var displayName: String {
        switch self {
        case .iap: return "user.setup.feedback.iap"
        case .bug: return "user.setup.feedback.bug"
        case .feature: return "user.setup.feedback.feature"
        case .report: return "user.setup.feedback.report"
        case .other: return "user.setup.feedback.other"
        }
    }
}

enum UserRelationshipStatus: String, Codable {
    case friend
    case following
    case follower
    case none
    
    var displayName: String {
        switch self {
        case .friend: return "user.page.friend"
        case .following: return "user.page.following"
        case .follower: return "user.page.follower"
        case .none: return "无关系"
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .friend: return .orange
        case .following: return .green
        case .follower: return .pink
        case .none: return .gray
        }
    }
}

struct RelationInfoResponse: Codable {
    let follower: Int
    let followed: Int
    let friends: Int
}

struct UserDTO: Codable {
    let user_id: String                 // 服务器端的唯一标识符
    let apple_iap_token: String         // 与 app store 中的 IAP 交易关联
    let nickname: String                // 昵称
    let phone_number: String?           // 手机号
    let apple_email: String?            // apple账号
    let email: String?                  // 邮箱
    let avatar_image_url: String        // 头像url
    let background_image_url: String    // 封面url
    
    let introduction: String?           // 简介
    let gender: Gender?                 // 性别
    let birthday: String?               // 生日
    let location: String?               // 地理位置
    let identity_auth_name: String?     // 身份名称
    
    let is_display_gender: Bool       // 是否展示性别
    let is_display_age: Bool          // 是否真实年龄
    let is_display_location: Bool     // 是否展示地理位置
    let enable_auto_location: Bool    // 是否使用最新定位的地理位置
    let is_display_identity: Bool     // 是否展示身份名称
    
    let default_sport: SportName      // 主页默认展示的运动
    let status: UserStatus              // 用户账号状态
    let is_vip: Bool
}

struct User: Identifiable, Codable, Hashable {
    var id: String { userID }
    let userID: String              // 服务器端的唯一标识符
    let appleIAPToken: String       // 与 app store 中的 IAP 交易关联
    var nickname: String            // 昵称
    var phoneNumber: String?        // 手机号
    var apple_email: String?        // Apple 账号
    var email: String?              // 邮箱
    var avatarImageURL: String      // 头像url
    var backgroundImageURL: String  // 封面url
    
    var introduction: String?        // 简介
    var gender: Gender?             // 性别 male/female
    var birthday: String?           // 生日
    var location: String?           // 地理位置ID
    var identityAuthName: String?   // 身份名称
    
    var isRealnameAuth: Bool    // 是否已实名认证
    var isIdentityAuth: Bool    // 是否已身份认证
    
    var isDisplayGender: Bool       // 是否展示性别
    var isDisplayAge: Bool          // 是否真实年龄
    var isDisplayLocation: Bool     // 是否展示地理位置
    var enableAutoLocation: Bool    // 是否使用最新定位的地理位置
    var isDisplayIdentity: Bool     // 是否展示身份名称
    var defaultSport: SportName     // 主页默认展示的运动
    let status: UserStatus
    var isVip: Bool
    
    init(
        userID: String = "未知",
        appleIAPToken: String = "",
        nickname: String = "未知",
        phoneNumber: String? = nil,
        apple_email: String? = nil,
        email: String? = nil,
        avatarImageURL: String = "",
        backgroundImageURL: String = "",
        introduction: String? = nil,
        gender: Gender? = nil,
        birthday: String? = nil,
        location: String? = nil,
        identityAuthName: String? = nil,
        isRealnameAuth: Bool = false,
        isIdentityAuth: Bool = false,
        isDisplayGender: Bool = false,
        isDisplayAge: Bool = false,
        isDisplayLocation: Bool = false,
        enableAutoLocation: Bool = false,
        isDisplayIdentity: Bool = false,
        defaultSport: SportName = .Bike,
        status: UserStatus = .normal,
        isVip: Bool = false
    ) {
        self.userID = userID
        self.appleIAPToken = appleIAPToken
        self.nickname = nickname
        self.phoneNumber = phoneNumber
        self.apple_email = apple_email
        self.email = email
        self.avatarImageURL = avatarImageURL
        self.backgroundImageURL = backgroundImageURL
        self.introduction = introduction
        self.gender = gender
        self.birthday = birthday
        self.location = location
        self.identityAuthName = identityAuthName
        self.isRealnameAuth = isRealnameAuth
        self.isIdentityAuth = isIdentityAuth
        self.isDisplayGender = isDisplayGender
        self.isDisplayAge = isDisplayAge
        self.isDisplayLocation = isDisplayLocation
        self.enableAutoLocation = enableAutoLocation
        self.isDisplayIdentity = isDisplayIdentity
        self.defaultSport = defaultSport
        self.status = status
        self.isVip = isVip
    }

    init(from dto: UserDTO) {
        self.userID = dto.user_id
        self.appleIAPToken = dto.apple_iap_token
        self.nickname = dto.nickname
        self.phoneNumber = dto.phone_number
        self.apple_email = dto.apple_email
        self.email = dto.email
        self.avatarImageURL = dto.avatar_image_url
        self.backgroundImageURL = dto.background_image_url
        self.introduction = dto.introduction
        self.gender = dto.gender
        self.birthday = dto.birthday
        self.location = dto.location
        self.identityAuthName = dto.identity_auth_name
        self.isRealnameAuth = (dto.gender != nil && dto.birthday != nil)
        self.isIdentityAuth = (dto.identity_auth_name != nil)
        self.isDisplayGender = dto.is_display_gender
        self.isDisplayAge = dto.is_display_age
        self.isDisplayLocation = dto.is_display_location
        self.enableAutoLocation = dto.enable_auto_location
        self.isDisplayIdentity = dto.is_display_identity
        self.defaultSport = dto.default_sport
        self.status = dto.status
        self.isVip = dto.is_vip
    }
}

struct MailBoxStatus: Codable {
    let has_unread: Bool
    let unread_count: Int
}
