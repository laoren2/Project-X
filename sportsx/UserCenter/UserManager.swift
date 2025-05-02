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
    
    let config = GlobalConfig.shared
    @Published var user: User? // 存储用户信息
    @Published var avatarImage: UIImage?        // 用户头像
    @Published var backgroundImage: UIImage?    // 用户封面
    @Published var backgroundColor: Color = .defaultBackground  // 用户封面背景色
    
    @Published var isLoggedIn: Bool = false
    @Published var showingLogin: Bool = false
        
    private init() {}
        
    func loginUser(phoneNumber: String) {
        print("Login!!!")
        self.user = User(
            userID: "user_555",
            nickname: "Newuser_10358",
            phoneNumber: phoneNumber,
            avatarImageURL: "https://example.com/avatar.jpg",
            introduction: "xxxxxxxxxx",
            gender: "男",
            birthday: "1998-08-21",
            location: nil,
            identityAuthName: "越野大师",
            isRealnameAuth: true,
            isIdentityAuth: true,
            isDisplayGender: true,
            isDisplayAge: false,
            isDisplayLocation: false,
            enableAutoLocation: false,
            isDisplayIdentity: false
        )
        
        isLoggedIn = true
        // 补全剩下的信息
        // if 用户已存在
        //   请求userID/nickname/pic
        // else
        //   创建userID/nickname/pic
        //user?.userID = "user_555"//generateUserID()
        //user?.nickname = "Newuser_10358"
        //user?.avatarImageURL = "https://example.com/avatar.jpg"
        
        if let loggedUser = user {
            if loggedUser.enableAutoLocation {
                user?.location = config.location
            }
        }
        
        Task {
            MagicCardManager.shared.fetchUserCards() // 获取MagicCard
            await ModelManager.shared.updateModels() // 更新本地MLModel
        }
    }
        
    func logoutUser() {
        self.user = nil
        self.avatarImage = nil
        self.backgroundImage = nil
        self.backgroundColor = .defaultBackground
        isLoggedIn = false
    }
        
    func updateUser(nickname: String? = nil, phoneNumber: String? = nil, avatarImageURL: String? = nil) {
        guard var currentUser = self.user else { return }
        
        if let nickname = nickname {
            currentUser.nickname = nickname
        }
        if let phoneNumber = phoneNumber {
            currentUser.phoneNumber = phoneNumber
        }
        if let avatarImageURL = avatarImageURL {
            currentUser.avatarImageURL = avatarImageURL
        }
        
        self.user = currentUser
    }
    
    private func generateUserID() -> String {
        // 生成一个唯一的 userID，例如使用递增的数字序列，或其他生成策略
        // 这里假设使用随机生成的字符串作为示例
        return String(Int.random(in: 100000...999999))
    }
}

struct User: Identifiable, Codable, Hashable {
    let id: UUID
    var userID: String // 服务器端的唯一标识符
    var nickname: String
    var phoneNumber: String
    var avatarImageURL: String
    var backgroundImageURL: String
    
    var introduction: String
    var gender: String?
    var birthday: String?
    var location: String?
    var identityAuthName: String?
    
    var isRealnameAuth: Bool    // 是否已实名认证
    var isIdentityAuth: Bool    // 是否已身份认证
    
    var isDisplayGender: Bool
    var isDisplayAge: Bool
    var isDisplayLocation: Bool
    var enableAutoLocation: Bool
    var isDisplayIdentity: Bool
    
    init(
        id: UUID = UUID(),
        userID: String = "未知",
        nickname: String = "未知",
        phoneNumber: String = "未知",
        avatarImageURL: String = "未知",
        backgroundImageURL: String = "未知",
        introduction: String = "未知",
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
        self.id = id
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
}
