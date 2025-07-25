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
    static let shared = UserManager() // 单例模式
    
    let navigationManager = NavigationManager.shared
    let config = GlobalConfig.shared
    @Published var user: User = User() // 存储用户信息
    @Published var avatarImage: UIImage?        // 用户头像
    @Published var backgroundImage: UIImage?    // 用户封面
    @Published var backgroundColor: Color = .defaultBackground  // 用户封面背景色
    
    @Published var followerCount: Int = 0
    @Published var followedCount: Int = 0
    @Published var friendCount: Int = 0
    
    @Published var isLoggedIn: Bool = false
    @Published var showingLogin: Bool = false
    
    var role: UserRole = UserRole.user  // 用户权限
        
    private init() {
        if let token = KeychainHelper.standard.read(forKey: "access_token") {
            print("read access_token success : \(token)")
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
        
        KeychainHelper.standard.delete(forKey: "access_token")
        clearUserInfoCache()
    }
    
    // 注销账号
    func cancelUser() {
        let request = APIRequest(path: "/user/delete", method: .post, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: EmptyResponse.self, showLoadingToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let success):
                let successToast = Toast(message: "账号已成功注销", duration: 2)
                DispatchQueue.main.async {
                    ToastManager.shared.show(toast: successToast)
                    self.logoutUser()
                    self.navigationManager.backToHome()
                }
            default: break
            }
        }
    }
    
    func fetchMeRole() {
        let request = APIRequest(path: "/user/me/role", method: .get, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: UserRole.self, showErrorToast: true) { result in
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
    
    func fetchMeInfo() {
        let request = APIRequest(path: "/user/me", method: .get, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: FetchMeUserResponse.self, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    let user = unwrappedData.user
                    let relation = unwrappedData.relation
                    DispatchQueue.main.async {
                        self.friendCount = relation.friends
                        self.followerCount = relation.follower
                        self.followedCount = relation.followed
                        self.user = User(
                            userID: user.user_id,
                            nickname: user.nickname,
                            phoneNumber: user.phone_number,
                            avatarImageURL: user.avatar_image_url,
                            backgroundImageURL: user.background_image_url,
                            introduction: user.introduction,
                            gender: user.gender,
                            birthday: user.birthday,
                            location: user.location,
                            identityAuthName: user.identity_auth_name,
                            isRealnameAuth: user.is_realname_auth,
                            isIdentityAuth: user.is_identity_auth,
                            isDisplayGender: user.is_display_gender,
                            isDisplayAge: user.is_display_age,
                            isDisplayLocation: user.is_display_location,
                            enableAutoLocation: user.enable_auto_location,
                            isDisplayIdentity: user.is_display_identity
                        )
                        self.saveUserInfoToCache()
                    }
                    self.downloadImages(avatar_url: user.avatar_image_url, background_url: user.background_image_url)
                }
            default: break
            }
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
                print("下载头像失败")
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
                print("下载封面失败")
            }
        }
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
        defaults.set(user.nickname, forKey: "user.nickname")
        defaults.set(user.phoneNumber, forKey: "user.phoneNumber")
        defaults.set(user.avatarImageURL, forKey: "user.avatarImageURL")
        defaults.set(user.backgroundImageURL, forKey: "user.backgroundImageURL")
        defaults.set(user.introduction, forKey: "user.introduction")
        defaults.set(user.gender, forKey: "user.gender")
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
    }
    
    private func loadUserInfoCache() {
        let defaults = UserDefaults.standard
        let user = User(
            userID: defaults.string(forKey: "user.userID") ?? "未知",
            nickname: defaults.string(forKey: "user.nickname") ?? "未登录",
            phoneNumber: defaults.string(forKey: "user.phoneNumber") ?? "未知",
            avatarImageURL: defaults.string(forKey: "user.avatarImageURL") ?? "",
            backgroundImageURL: defaults.string(forKey: "user.backgroundImageURL") ?? "",
            introduction: defaults.string(forKey: "user.introduction"),
            gender: defaults.string(forKey: "user.gender"),
            birthday: defaults.string(forKey: "user.birthday"),
            location: defaults.string(forKey: "user.location"),
            identityAuthName: defaults.string(forKey: "user.identityAuthName"),
            isRealnameAuth: defaults.bool(forKey: "user.isRealnameAuth"),
            isIdentityAuth: defaults.bool(forKey: "user.isIdentityAuth"),
            isDisplayGender: defaults.bool(forKey: "user.isDisplayGender"),
            isDisplayAge: defaults.bool(forKey: "user.isDisplayAge"),
            isDisplayLocation: defaults.bool(forKey: "user.isDisplayLocation"),
            enableAutoLocation: defaults.bool(forKey: "user.enableAutoLocation"),
            isDisplayIdentity: defaults.bool(forKey: "user.isDisplayIdentity")
        )
        self.user = user
        
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
        defaults.removeObject(forKey: "user.nickname")
        defaults.removeObject(forKey: "user.phoneNumber")
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
        
        defaults.removeObject(forKey: "followedCount")
        defaults.removeObject(forKey: "followerCount")
        defaults.removeObject(forKey: "friendCount")
        
        let avatarPath = getLocalImagePath(filename: "avatar.png")
        let backgroundPath = getLocalImagePath(filename: "background.png")
        
        try? FileManager.default.removeItem(at: avatarPath)
        try? FileManager.default.removeItem(at: backgroundPath)
    }
}

struct FetchBaseUserResponse: Codable {
    let user: UserDTO
}

struct FetchMeUserResponse: Codable {
    let user: UserDTO
    let relation: RelationInfoResponse
}

struct FetchAnyUserResponse: Codable {
    let user: UserDTO
    let relation: RelationInfoResponse
    let relationship: UserRelationshipStatus
}

enum UserRole: String, Codable {
    case user = "user"
    case admin = "admin"
}

enum UserRelationshipStatus: String, Codable {
    case friend
    case following
    case follower
    case none
    
    var displayName: String {
        switch self {
        case .friend: return "好友"
        case .following: return "关注"
        case .follower: return "粉丝"
        case .none: return "无关系"
        }
    }
}

struct RelationInfoResponse: Codable {
    let follower: Int
    let followed: Int
    let friends: Int
}

struct UserDTO: Codable {
    var user_id: String                 // 服务器端的唯一标识符
    var nickname: String                // 昵称
    var phone_number: String            // 手机号
    var avatar_image_url: String        // 头像url
    var background_image_url: String    // 封面url
    
    var introduction: String?           // 简介
    var gender: String?                 // 性别
    var birthday: String?               // 生日
    var location: String?               // 地理位置
    var identity_auth_name: String?     // 身份名称
    
    var is_realname_auth: Bool      // 是否已实名认证
    var is_identity_auth: Bool      // 是否已身份认证
    
    var is_display_gender: Bool       // 是否展示性别
    var is_display_age: Bool          // 是否真实年龄
    var is_display_location: Bool     // 是否展示地理位置
    var enable_auto_location: Bool    // 是否使用最新定位的地理位置
    var is_display_identity: Bool     // 是否展示身份名称
}

struct User: Identifiable, Codable, Hashable {
    let id: UUID
    var userID: String              // 服务器端的唯一标识符
    var nickname: String            // 昵称
    var phoneNumber: String         // 手机号
    var avatarImageURL: String      // 头像url
    var backgroundImageURL: String  // 封面url
    
    var introduction: String?        // 简介
    var gender: String?             // 性别
    var birthday: String?           // 生日
    var location: String?           // 地理位置
    var identityAuthName: String?   // 身份名称
    
    var isRealnameAuth: Bool    // 是否已实名认证
    var isIdentityAuth: Bool    // 是否已身份认证
    
    var isDisplayGender: Bool       // 是否展示性别
    var isDisplayAge: Bool          // 是否真实年龄
    var isDisplayLocation: Bool     // 是否展示地理位置
    var enableAutoLocation: Bool    // 是否使用最新定位的地理位置
    var isDisplayIdentity: Bool     // 是否展示身份名称
    
    init(
        userID: String = "未知",
        nickname: String = "未知",
        phoneNumber: String = "未知",
        avatarImageURL: String = "",
        backgroundImageURL: String = "",
        introduction: String? = nil,
        gender: String? = nil,
        birthday: String? = nil,
        location: String? = nil,
        identityAuthName: String? = nil,
        isRealnameAuth: Bool = false,
        isIdentityAuth: Bool = false,
        isDisplayGender: Bool = false,
        isDisplayAge: Bool = false,
        isDisplayLocation: Bool = false,
        enableAutoLocation: Bool = false,
        isDisplayIdentity: Bool = false
    ) {
        self.id = UUID()
        self.userID = userID
        self.nickname = nickname
        self.phoneNumber = phoneNumber
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
    }

    init(from dto: UserDTO) {
        self.id = UUID()
        self.userID = dto.user_id
        self.nickname = dto.nickname
        self.phoneNumber = dto.phone_number
        self.avatarImageURL = dto.avatar_image_url
        self.backgroundImageURL = dto.background_image_url
        self.introduction = dto.introduction
        self.gender = dto.gender
        self.birthday = dto.birthday
        self.location = dto.location
        self.identityAuthName = dto.identity_auth_name
        self.isRealnameAuth = dto.is_realname_auth
        self.isIdentityAuth = dto.is_identity_auth
        self.isDisplayGender = dto.is_display_gender
        self.isDisplayAge = dto.is_display_age
        self.isDisplayLocation = dto.is_display_location
        self.enableAutoLocation = dto.enable_auto_location
        self.isDisplayIdentity = dto.is_display_identity
    }
}
