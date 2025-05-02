//
//  UserIntroEditViewModel.swift
//  sportsx
//
//  Created by 任杰 on 2025/4/25.
//

import Foundation
import SwiftUI


class UserIntroEditViewModel: ObservableObject {
    let navigationManager = NavigationManager.shared
    let userManager = UserManager.shared
    @Published var currentUser = User()
    @Published var avatarImage: UIImage?        // 用户头像
    @Published var backgroundImage: UIImage?    // 用户封面
    
    @Published var backgroundColor: Color = .defaultBackground  // 背景色
    
    init() {
        if let user = userManager.user {
            currentUser = user
            avatarImage = userManager.avatarImage
            backgroundImage = userManager.backgroundImage
            backgroundColor = userManager.backgroundColor
        }
    }
    
    func saveUserIntro() {
        // 同步到服务端，并更新本地userManager
        userManager.user = currentUser
        userManager.avatarImage = avatarImage
        userManager.backgroundImage = backgroundImage
        userManager.backgroundColor = backgroundColor
        
        navigationManager.removeLast()
    }
}
