//
//  UserSetUpView.swift
//  sportsx
//
//  Created by 任杰 on 2025/4/16.
//

import SwiftUI
import AuthenticationServices


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
                    
                    SetUpItemView(icon: "person.text.rectangle", title: "实名认证") {
                        NavigationManager.shared.append(.realNameAuthView)
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
                        Text("version: \(AppVersionManager.shared.currentVersion.toString())")
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
    @State var showAlert: Bool = false
    
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
                    SetUpItemView(icon: "phone", title: "手机号") {
                        appState.navigationManager.append(.phoneBindView)
                    } trailingView: {
                        if userManager.user.phoneNumber != nil {
                            Text("已绑定")
                                .foregroundStyle(Color.secondText)
                        } else {
                            HStack(alignment: .bottom, spacing: 2) {
                                Image(systemName: "exclamationmark.circle")
                                    .foregroundStyle(Color.pink)
                                Text("未绑定")
                                    .foregroundStyle(Color.secondText)
                            }
                        }
                    }
                    SetUpItemView(icon: "apple.logo", title: "apple账号", showDivider: false) {
                        appState.navigationManager.append(.appleBindView)
                    } trailingView: {
                        if userManager.user.apple_email != nil {
                            Text("已绑定")
                                .foregroundStyle(Color.secondText)
                        } else {
                            HStack(alignment: .bottom, spacing: 2) {
                                Image(systemName: "exclamationmark.circle")
                                    .foregroundStyle(Color.pink)
                                Text("未绑定")
                                    .foregroundStyle(Color.secondText)
                            }
                        }
                    }
                }
                .cornerRadius(20)
                .padding()
                
                VStack {
                    SetUpItemView(icon: "person", title: "注销账号", showChevron: false, showDivider: false) {
                        showAlert = true
                    }
                }
                .cornerRadius(20)
                .padding()
            }
        }
        .background(Color.defaultBackground)
        .toolbar(.hidden, for: .navigationBar)
        .enableBackGesture()
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("注销账号"),
                message: Text("注销后账号所有信息将被销毁，操作无法撤回，确定要注销吗？"),
                primaryButton: .default(Text("取消")),
                secondaryButton: .default(Text("注销")) {
                    userManager.cancelUser()
                }
            )
        }
    }
}

struct PhoneBindView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var userManager = UserManager.shared
    @State private var phoneNumber: String = ""
    @State private var verificationCode: String = ""
    @State private var sendButtonText: String = "发送验证码"
    @State private var sendButtonColor: Color = .green
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                CommonIconButton(icon: "chevron.left") {
                    appState.navigationManager.removeLast()
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                
                Spacer()
                
                Text("手机号绑定")
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
            
            if let number = userManager.user.phoneNumber {
                Text("已绑定手机号: \(number)")
                    .foregroundStyle(.white)
                Button("解除绑定") {
                    unbindPhone()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.top, 10)
            } else {
                HStack {
                    Text("+852")
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .foregroundStyle(.white)
                        .background(Color.gray)
                        .cornerRadius(5)
                    
                    TextField("请输入手机号", text: $phoneNumber)
                        .padding(.leading, 10)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                }
                
                HStack {
                    TextField("请输入验证码", text: $verificationCode)
                        .padding(.trailing, 10)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                    Button(action: {
                        sendSmsCode()
                    }) {
                        Text(sendButtonText)
                            .foregroundStyle(.white)
                            .font(.system(size: 15))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                
                Button("绑定") {
                    bindPhone()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.top, 10)
            }
            Spacer()
        }
        .padding(.horizontal)
        .background(Color.defaultBackground)
        .toolbar(.hidden, for: .navigationBar)
        .enableBackGesture()
    }
    
    func sendSmsCode() {
        guard phoneNumber.count == 11 else {
            ToastManager.shared.show(toast: Toast(message: "请输入正确的号码"))
            return
        }
        var headers: [String: String] = [:]
        headers["Content-Type"] = "application/json"
        
        let body = ["phone_number": phoneNumber]
        guard let encodedBody = try? JSONEncoder().encode(body) else {
            return
        }
        
        let request = APIRequest(path: "/user/send_code", method: .post, headers: headers, body: encodedBody)
        
        NetworkService.sendRequest(with: request, decodingType: SmsCodeResponse.self, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    sendButtonText = "已发送:\(unwrappedData.code)"
                    sendButtonColor = .gray
                }
            default:
                break
            }
        }
    }
    
    func bindPhone() {
        guard phoneNumber.count == 11 else {
            ToastManager.shared.show(toast: Toast(message: "请输入正确的号码"))
            return
        }
        guard verificationCode.count == 6 else {
            ToastManager.shared.show(toast: Toast(message: "请输入正确的验证码"))
            return
        }
        guard var components = URLComponents(string: "/user/account/bind_phone") else { return }
        components.queryItems = [
            URLQueryItem(name: "phone", value: phoneNumber),
            URLQueryItem(name: "code", value: verificationCode)
        ]
        guard let urlPath = components.string else { return }
        let request = APIRequest(path: urlPath, method: .post, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: EmptyResponse.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true) { result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    UserManager.shared.user.phoneNumber = phoneNumber
                    UserDefaults.standard.set(phoneNumber, forKey: "user.phoneNumber")
                }
            default: break
            }
        }
    }
    
    func unbindPhone() {
        let request = APIRequest(path: "/user/account/unbind_phone", method: .post, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: EmptyResponse.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true) { result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    UserManager.shared.user.phoneNumber = nil
                    UserDefaults.standard.removeObject(forKey: "user.phoneNumber")
                }
            default: break
            }
        }
    }
}

struct AppleBindView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var userManager = UserManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                CommonIconButton(icon: "chevron.left") {
                    appState.navigationManager.removeLast()
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                
                Spacer()
                
                Text("Apple账号绑定")
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
            
            if let email = userManager.user.apple_email {
                Text("已绑定apple账号: \(email)")
                    .foregroundStyle(.white)
                Button("解除绑定") {
                    unbindApple()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.top, 10)
            } else {
                VStack {
                    Image("appleid_button")
                    Text("绑定 Apple 账号")
                        .font(.system(size: 15))
                        .foregroundStyle(.white)
                }
                .padding(.bottom, 50)
                .onTapGesture {
                    bindWithApple()
                }
            }
            Spacer()
        }
        .background(Color.defaultBackground)
        .toolbar(.hidden, for: .navigationBar)
        .enableBackGesture()
    }
    
    func bindWithApple() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = AppleBindCoordinator.shared
        controller.presentationContextProvider = AppleBindCoordinator.shared
        controller.performRequests()
    }
    
    func unbindApple() {
        let request = APIRequest(path: "/user/account/unbind_apple_id", method: .post, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: EmptyResponse.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true) { result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    UserManager.shared.user.apple_email = nil
                    UserDefaults.standard.removeObject(forKey: "user.appleEmail")
                }
            default: break
            }
        }
    }
}

class AppleBindCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    static let shared = AppleBindCoordinator()

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
            //let userIdentifier = credential.user
            let identityToken = credential.identityToken
            //let authCode = credential.authorizationCode

            if let token = identityToken, let tokenString = String(data: token, encoding: .utf8) {
                // 绑定apple账号
                bind(with: tokenString)
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        //print("Apple 绑定失败: \(error.localizedDescription)")
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // 获取当前正在 active 的 windowScene
        if let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
            return window
        }
        // 兜底（极少数情况返回一个新建 window）
        return ASPresentationAnchor()
    }
    
    func bind(with token: String) {
        guard var components = URLComponents(string: "/user/account/bind_apple_id") else { return }
        components.queryItems = [
            URLQueryItem(name: "token", value: token)
        ]
        guard let urlPath = components.string else { return }
        let request = APIRequest(path: urlPath, method: .post, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: String.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let email = data {
                    DispatchQueue.main.async {
                        UserManager.shared.user.apple_email = email
                        UserDefaults.standard.set(email, forKey: "user.appleEmail")
                    }
                }
            default: break
            }
        }
    }
}

#Preview {
    let appState = AppState.shared
    UserSetUpAccountView()
        .environmentObject(appState)
}
