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
    @State var cacheSizeMB: Double = 0
    @State var isComputingCacheSize: Bool = false
    @State var isCleaning: Bool = false
    
    @State var tapCnt: Int = 0
    
    var body: some View {
        VStack {
            HStack {
                CommonIconButton(icon: "chevron.left") {
                    appState.navigationManager.removeLast()
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                
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
                    
                    SetUpItemView(icon: "trash", title: "清理缓存", showChevron: false) {
                        clearCache()
                    } trailingView: {
                        if isComputingCacheSize || isCleaning {
                            ProgressView()
                                .foregroundStyle(Color.secondText)
                        } else {
                            Text(cacheSizeMB < 0.2 ? "0.0M" : String(format: "%.1fM", cacheSizeMB))
                                .foregroundStyle(Color.secondText)
                        }
                    }
                    
                    SetUpItemView(icon: "arrow.left.arrow.right", title: "切换账号") {
                        
                    }
                    
                    SetUpItemView(icon: "iphone.and.arrow.forward.outward", title: "退出登录", showChevron: false, showDivider: false) {
                        guard !appState.competitionManager.isRecording else {
                            let toast = Toast(message: "比赛进行中,无法退出")
                            ToastManager.shared.show(toast: toast)
                            return
                        }
                        logoutUser()
                    }
                }
                .cornerRadius(20)
                .padding()
                
                if userManager.role == .admin {
                    VStack(spacing: 0) {
                        SetUpItemView(icon: "pc", title: "后台管理", showDivider: false) {
                            NavigationManager.shared.append(.adminPanelView)
                        }
                    }
                    .cornerRadius(20)
                    .padding()
                }
                Spacer()
                VStack {
                    HStack(spacing: 10) {
                        Spacer()
                        Text("version: 0.0.1")
                            .onTapGesture {
                                tapCnt += 1
                            }
                        Spacer()
                    }
                    if tapCnt >= 5 {
                        Text("uid: \(userManager.user.userID)")
                            .onTapGesture {
                                UIPasteboard.general.string = userManager.user.userID
                                let toast = Toast(message: "uid已复制", duration: 2)
                                ToastManager.shared.show(toast: toast)
                            }
                    }
                }
                .foregroundStyle(Color.secondText)
                .font(.footnote)
            }
        }
        .background(Color.defaultBackground)
        .toolbar(.hidden, for: .navigationBar)
        .enableBackGesture()
        .onStableAppear {
            updateCacheSize()
#if DEBUG
            userManager.fetchMeRole()
#endif
        }
    }
    
    func logoutUser() {
        userManager.logoutUser()
        NavigationManager.shared.backToHome()
    }
    
    func updateCacheSize() {
        isComputingCacheSize = true
        CacheManager.shared.getCacheSize { size in
            DispatchQueue.main.async {
                self.cacheSizeMB = Double(size) / (1024 * 1024)
                isComputingCacheSize = false
            }
        }
    }
    
    func clearCache() {
        isCleaning = true
        CacheManager.shared.clearAllCache() { success in
            updateCacheSize()
            DispatchQueue.main.async {
                isCleaning = false
                let toast = Toast(message: success ? "清理成功" : "清理失败，请重试")
                ToastManager.shared.show(toast: toast)
            }
        }
    }
}

struct UserSetUpAccountView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var userManager = UserManager.shared
    
    var body: some View {
        VStack {
            HStack {
                CommonIconButton(icon: "chevron.left") {
                    appState.navigationManager.removeLast()
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                
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
