//
//  FriendListViewModel.swift
//  sportsx
//
//  Created by 任杰 on 2025/4/22.
//

import Foundation

struct PersonInfoCard: Identifiable {
    let id = UUID()
    let userID: String      // server userid
    let avatarUrl: String   // 头像
    let name: String        // 用户昵称
    
    init(userID: String, avatarUrl: String, name: String) {
        self.userID = userID
        self.avatarUrl = avatarUrl
        self.name = name
    }
}

class FriendListViewModel: ObservableObject {
    // 朋友列表
    @Published var myFriends: [PersonInfoCard] = []
    // 关注列表
    @Published var myIdols: [PersonInfoCard] = []
    // 粉丝列表
    @Published var myFans: [PersonInfoCard] = []
    
    
    init() {
        let person1 = PersonInfoCard(userID: "12345", avatarUrl: "lalala", name: "我就是我")
        let person2 = PersonInfoCard(userID: "56789", avatarUrl: "lalala", name: "我就是sportsxMan")
        let person3 = PersonInfoCard(userID: "12321", avatarUrl: "lalala", name: "sportsxMan就是我")
        
        myFriends.append(person1)
        myIdols.append(person2)
        myIdols.append(person3)
        myFans.append(person1)
        myFans.append(person2)
        myFans.append(person3)
    }
}
