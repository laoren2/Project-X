//
//  UserSetUpView.swift
//  sportsx
//
//  Created by 任杰 on 2025/4/16.
//

import SwiftUI


struct UserSetUpView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var userManager = UserManager.shared
    
    var body: some View {
        VStack {
            // 登录状态 (放在设置中)
            Group {
                if userManager.isLoggedIn {
                    Button("退出登录") {
                        logoutUser()
                    }
                    .background(appState.competitionManager.isRecording ? .gray : .red)
                    .disabled(appState.competitionManager.isRecording)
                }
            }
            .padding()
            .foregroundColor(.white)
            .cornerRadius(10)
            .padding(.top, 10)
        }
    }
    
    func loginUser() {
        userManager.showingLogin = true
    }
    
    func logoutUser() {
        userManager.logoutUser()
        appState.navigationManager.selectedTab = .home
        appState.navigationManager.path.removeLast()
        UserDefaults.standard.removeObject(forKey: "savedPhoneNumber")
        print("delete Key: savedPhoneNumber Value: ",userManager.user?.phoneNumber ?? "nil")
        print("showingLogin: ",userManager.showingLogin)
        print("isLogin: ",userManager.isLoggedIn)
    }
}

#Preview {
    let appState = AppState()
    UserSetUpView()
        .environmentObject(appState)
}
