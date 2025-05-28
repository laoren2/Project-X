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
            HStack {
                Button(action: {
                    appState.navigationManager.removeLast()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Text("设置")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                // 平衡布局的空按钮
                Button(action: {}) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.clear)
                }
            }
            .padding(.horizontal)
            
            ScrollView {
                VStack(spacing: 0) {
                    SetUpItemView(icon: "person", title: "账号与安全") {
                        NavigationManager.shared.append(.userSetUpAccountView)
                    }
                    
                    SetUpItemView(icon: "arrow.left.arrow.right", title: "切换账号") {
                        
                    }
                    
                    SetUpItemView(icon: "iphone.and.arrow.forward.outward", title: "退出登录", showChevron: false) {
                        logoutUser()
                    }
                    .disabled(appState.competitionManager.isRecording)
                }
                .cornerRadius(20)
                .padding()
            }
        }
        .background(Color.defaultBackground)
        .toolbar(.hidden, for: .navigationBar)
        .enableBackGesture()
    }
    
    func logoutUser() {
        userManager.logoutUser()
        NavigationManager.shared.backToHome()
    }
}

struct UserSetUpAccountView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var userManager = UserManager.shared
    
    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    appState.navigationManager.removeLast()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Text("账号与安全")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                // 平衡布局的空按钮
                Button(action: {}) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.clear)
                }
            }
            .padding(.horizontal)
            
            ScrollView {
                VStack(spacing: 0) {
                    SetUpItemView(icon: "person", title: "注销账号") {
                        userManager.cancelUser()
                    }
                }
                .cornerRadius(20)
                .padding()
            }
        }
        .background(Color.defaultBackground)
        .toolbar(.hidden, for: .navigationBar)
        .enableBackGesture()
    }
}

#Preview {
    let appState = AppState.shared
    UserSetUpView()
        .environmentObject(appState)
}
