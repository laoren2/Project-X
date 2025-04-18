//
//  UserViewModel.swift
//  sportsx
//
//  Created by 任杰 on 2025/4/18.
//

import Foundation

class UserViewModel: ObservableObject {
    let userManager = UserManager.shared
    
    @Published var isUserSelf: Bool = false
    @Published var user = User()
    
    var userID: String
    var isNeedBack: Bool
    
    
    
    init(id: String, needBack: Bool) {
        userID = id
        isNeedBack = needBack
        user.userID = id
    }
    
    func updateUserInfo() {
        if let tempUser = userManager.user {
            // 总tabview的“我的”页，防止未登录成功时id未设置成功
            if !isNeedBack {
                userID = tempUser.userID
                user.userID = tempUser.userID
            }
            
            if userID != tempUser.userID {
                isUserSelf = false
                fetchUserInfo()
            } else {
                isUserSelf = true
                user.nickname = tempUser.nickname
                user.phoneNumber = tempUser.phoneNumber
                user.avatarImageURL = tempUser.avatarImageURL
                user.backgroundImageURL = tempUser.backgroundImageURL
            }
        } else {
            isUserSelf = false
            fetchUserInfo()
        }
    }
    
    func fetchUserInfo() {
        print("fetch user : \(userID)")
    }
}
