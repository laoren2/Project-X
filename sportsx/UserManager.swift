//
//  LoginViewModel.swift
//  sportsx
//
//  Created by 任杰 on 2024/8/8.
//

import Foundation
import Combine

class UserManager: ObservableObject {
    static let shared = UserManager() // 单例模式
        
    @Published var user: User? // 存储用户信息
    @Published var isLoggedIn: Bool = false
        
    private init() {}
        
    func loginUser(phoneNumber: String) {
        print("Login!!!")
        self.user = User(phoneNumber: phoneNumber)
        isLoggedIn = true
        // 补全剩下的信息
        // if 用户已存在
        //   请求userID/nickname/pic
        // else
        //   创建userID/nickname/pic
        user?.userID = generateUserID()
        user?.nickname = "Newuser_10358"
        user?.avatarImageURL = "https://example.com/avatar.jpg"
        
        Task {
            await MagicCardManager.shared.fetchUserCards()
            await ModelManager.shared.updateModels()
        }
    }
        
    func logoutUser() {
        self.user = nil
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

struct User: Identifiable, Codable {
    let id: UUID
    var userID: String // 服务器端的唯一标识符
    var nickname: String
    var phoneNumber: String
    var avatarImageURL: String
    
    init(id: UUID = UUID(), userID: String = "", nickname: String = "", phoneNumber: String, avatarImageURL: String = "") {
        self.id = id
        self.userID = userID
        self.nickname = nickname
        self.phoneNumber = phoneNumber
        self.avatarImageURL = avatarImageURL
    }
}
