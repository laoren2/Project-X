//
//  AppRootView.swift
//  sportsx
//
//  Created by 任杰 on 2024/8/8.
//

import SwiftUI

struct UserView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var userManager = UserManager.shared
    @Binding var showingLogin: Bool
    
    var body: some View {
        VStack {
            AsyncImage(url: URL(string: userManager.user?.avatarImageURL ?? "https://example.com/avatar_default.jpg")) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Image("Ads") // 使用本地图片
                    .resizable()
                    .scaledToFill()
            }
            .frame(width: UIScreen.main.bounds.width, height: 200)
            .clipped()
            
            Button("设备绑定") {
                appState.navigationManager.path.append("sensorBindView")
            }
            
            Text(userManager.user?.nickname ?? "Default_nickname")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding()
            
            Text(userManager.user?.userID ?? "Default_userID")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding()
            
            Text(userManager.user?.phoneNumber ?? "Default_phoneNumber")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding()
            
            let logged = userManager.isLoggedIn ? "已登录" : "未登录"
            Text(logged)
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding()
            
            Group {
                if userManager.isLoggedIn {
                    Button("登出") {
                        logoutUser()
                    }
                } else {
                    Button("点击登录") {
                        loginUser()
                    }
                }
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .padding(.top, 10)
        }
    }
    
    func loginUser() {
        showingLogin = true
    }
    
    func logoutUser() {
        userManager.logoutUser()
        showingLogin = true
        UserDefaults.standard.removeObject(forKey: "savedPhoneNumber")
        print("delete Key: savedPhoneNumber Value: ",userManager.user?.phoneNumber ?? "nil")
        print("showingLogin: ",showingLogin)
        print("isLogin: ",userManager.isLoggedIn)
    }
}

#Preview {
    @Previewable @State var showingLogin = false
    let appState = AppState()
    UserView(showingLogin: $showingLogin)
        .environmentObject(appState)
}
