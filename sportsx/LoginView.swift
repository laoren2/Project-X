//
//  LoginView.swift
//  sportsx
//
//  Created by 任杰 on 2024/8/8.
//

import SwiftUI
import UIKit
import AuthenticationServices
import SafariServices


struct WebPage: Identifiable {
    let id = UUID()
    let url: URL
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

struct LoginView: View {
    @ObservedObject private var userManager = UserManager.shared
    @State private var phoneNumber: String = ""
    @State private var verificationCode: String = ""
    //@State private var enableRetryCodeSend: Bool = false
    @State private var testCode: String = ""

    @State private var showingWebView = false
    @State private var webPage: WebPage?
    @State private var agreed = false
    @State private var countdown: Int = 60
    @State private var alreadySendCode = false
    
    @State private var timer: Timer?
    
    let config = GlobalConfig.shared

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 20) {
                HStack {
                    Button(action: {
                        userManager.showingLogin = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20))
                        //.padding()
                            .foregroundStyle(.white)
                    }
                    Spacer()
                }
                .padding(.top, 10)
                
                HStack {
                    Text("欢迎来到 Sporreer")
                        .font(.title)
                        .foregroundStyle(.white)
                    Spacer()
                }
                .padding(.top, 40)
                
                HStack {
                    Text("未注册的号码验证登录后将自动注册账号")
                        .foregroundStyle(Color.thirdText)
                    Spacer()
                }
                
                VStack(spacing: 20) {
                    Text("短信验证码登录")
                        .foregroundStyle(Color.white)
                    
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
                    
                    if alreadySendCode {
                        Text(countdown == 0 ? "\(testCode) 没收到验证码？点击重新发送" : "验证码\(testCode)已发送，\(countdown)秒后可重新发送")
                            .foregroundStyle(Color.secondText)
                        HStack {
                            TextField("请输入验证码", text: $verificationCode)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.numberPad)
                            
                            Button(action: {
                                if countdown == 0 {
                                    sendSmsCode()
                                }
                            }) {
                                Text("重新发送")
                                    .foregroundStyle(.white)
                                    .font(.system(size: 15))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(countdown == 0 ? Color.green : Color.gray)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                            .disabled(countdown != 0)
                        }
                    }
                    
                    Button(action: {
                        if alreadySendCode {
                            loginWithSMS()
                        } else {
                            sendSmsCode()
                        }
                    }) {
                        Text(alreadySendCode ? "登陆" : "验证并登陆")
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(agreed ? Color.orange : Color.orange.opacity(0.2))
                            .foregroundStyle(agreed ? Color.white : Color.thirdText)
                            .cornerRadius(10)
                            .padding(.top, 10)
                    }
                }
                .padding(.top, 50)
                
                HStack(spacing: 5) {
                    Image(systemName: agreed ? "checkmark.circle" : "circle")
                        .frame(width: 15, height: 15)
                        .foregroundStyle(agreed ? Color.orange : Color.secondText)
                        .onTapGesture {
                            agreed.toggle()
                        }
                    Text("已阅读并同意")
                    Text("用户协议")
                        .underline()
                        .foregroundStyle(Color.orange.opacity(0.6))
                        .onTapGesture {
                            webPage = WebPage(url: URL(string: "https://www.valbara.top/user-agreement")!)
                        }
                    Text("和")
                    Text("隐私政策")
                        .underline()
                        .foregroundStyle(Color.orange.opacity(0.6))
                        .onTapGesture {
                            webPage = WebPage(url: URL(string: "https://www.valbara.top/privacy")!)
                        }
                }
                .font(.system(size: 13))
                .foregroundStyle(Color.thirdText)
                .sheet(item: $webPage) { item in
                    SafariView(url: item.url)
                        .ignoresSafeArea()
                }
                
                Spacer()
            }
            
            // 使用ZStack布局可以暂时解决键盘弹出挤压问题
            VStack {
                Image("appleid_button")
                Text("通过 Apple 登录")
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
            }
            .padding(.bottom, 50)
            .onTapGesture {
                loginWithAppleID()
            }
        }
        .padding(.horizontal, 20)
        .background(Color.defaultBackground)
        .onValueChange(of: userManager.showingLogin) {
            if userManager.showingLogin {
                clearAll()
            } else {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
        .ignoresSafeArea(.keyboard)
        .hideKeyboardOnTap()
    }
    
    func loginWithAppleID() {
        guard agreed else {
            ToastManager.shared.show(toast: Toast(message: "请同意用户协议和隐私政策"))
            return
        }
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = AppleSignInCoordinator.shared
        controller.presentationContextProvider = AppleSignInCoordinator.shared
        controller.performRequests()
    }
    
    func loginWithSMS() {
        guard agreed else {
            ToastManager.shared.show(toast: Toast(message: "请同意用户协议和隐私政策"))
            return
        }
        guard phoneNumber.count == 11 else {
            ToastManager.shared.show(toast: Toast(message: "请输入正确的号码"))
            return
        }
        guard verificationCode.count == 6 else {
            ToastManager.shared.show(toast: Toast(message: "请输入正确的验证码"))
            return
        }
        
        let body = ["phone_number": phoneNumber, "code": verificationCode]
        guard let encodedBody = try? JSONEncoder().encode(body) else {
            return
        }
        
        var headers: [String: String] = [:]
        headers["Content-Type"] = "application/json"
        
        let request = APIRequest(path: "/user/login", method: .post, headers: headers, body: encodedBody, requiresAuth: false)
        
        NetworkService.sendRequest(with: request, decodingType: LoginResponse.self, showLoadingToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    let user = unwrappedData.user
                    let relation = unwrappedData.relation
                    DispatchQueue.main.async {
                        userManager.friendCount = relation.friends
                        userManager.followerCount = relation.follower
                        userManager.followedCount = relation.followed
                        userManager.user = User(from: user)
                        userManager.role = unwrappedData.role
                        userManager.saveUserInfoToCache()
                        //config.refreshAll()
                        userManager.isLoggedIn = true
                        userManager.showingLogin = false
                    }
                    
                    userManager.downloadImages(avatar_url: user.avatar_image_url, background_url: user.background_image_url)
                    AssetManager.shared.queryCCAssets()
                    Task {
                        await AssetManager.shared.queryCPAssets(withLoadingToast: false)
                        await AssetManager.shared.queryMagicCards(withLoadingToast: false)
                    }
                    
                    if unwrappedData.isRegister {
                        print("注册成功，进入编辑资料页")
                    } else {
                        print("登录成功")
                    }
                }
            default:
                break
            }
        }
    }
    
    func sendSmsCode() {
        guard agreed else {
            ToastManager.shared.show(toast: Toast(message: "请同意用户协议和隐私政策"))
            return
        }
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
        
        let request = APIRequest(path: "/user/send_code", method: .post, headers: headers, body: encodedBody, requiresAuth: false)
        
        NetworkService.sendRequest(with: request, decodingType: SmsCodeResponse.self, showSuccessToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        testCode = unwrappedData.code
                        alreadySendCode = true
                        // 开始倒计时60s，60s后可重新发送验证码
                        startCodeTimer()
                    }
                }
            default:
                break
            }
        }
    }
    
    // 开始倒计时60s并更新remainingSeconds，结束后更新enableRetryCodeSend
    func startCodeTimer() {
        timer?.invalidate()
        countdown = 60
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if countdown > 0 {
                countdown -= 1
            } else {
                timer?.invalidate()
                timer = nil
            }
        }
    }
    
    func clearAll() {
        phoneNumber = ""
        verificationCode = ""
        testCode = ""
        alreadySendCode = false
        countdown = 0
        agreed = false
        
        timer?.invalidate()
        timer = nil
    }
}

class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    static let shared = AppleSignInCoordinator()

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
            //let userIdentifier = credential.user
            let identityToken = credential.identityToken
            //let authCode = credential.authorizationCode

            if let token = identityToken, let tokenString = String(data: token, encoding: .utf8) {
                //print("Apple Token: \(tokenString)")
                login(with: tokenString)
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        //print("Apple 登录失败: \(error.localizedDescription)")
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
    
    func login(with token: String) {
        guard var components = URLComponents(string: "/user/login/apple") else { return }
        components.queryItems = [
            URLQueryItem(name: "token", value: token)
        ]
        guard let urlPath = components.string else { return }
        let request = APIRequest(path: urlPath, method: .post)
        
        NetworkService.sendRequest(with: request, decodingType: LoginResponse.self, showLoadingToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    let user = unwrappedData.user
                    let relation = unwrappedData.relation
                    let userManager = UserManager.shared
                    DispatchQueue.main.async {
                        userManager.friendCount = relation.friends
                        userManager.followerCount = relation.follower
                        userManager.followedCount = relation.followed
                        userManager.user = User(from: user)
                        userManager.role = unwrappedData.role
                        userManager.saveUserInfoToCache()
                        GlobalConfig.shared.refreshAll()
                        userManager.isLoggedIn = true
                        userManager.showingLogin = false
                    }
                    
                    userManager.downloadImages(avatar_url: user.avatar_image_url, background_url: user.background_image_url)
                    AssetManager.shared.queryCCAssets()
                    Task {
                        await AssetManager.shared.queryCPAssets(withLoadingToast: false)
                        await AssetManager.shared.queryMagicCards(withLoadingToast: false)
                    }
                    
                    if unwrappedData.isRegister {
                        print("Apple注册成功，进入编辑资料页")
                    } else {
                        print("Apple登录成功")
                    }
                }
            default: break
            }
        }
    }
}

struct SmsCodeResponse: Codable {
    let code: String
}

struct LoginResponse: Codable {
    let user: UserDTO
    let relation: RelationInfoResponse
    let role: UserRole
    let isRegister: Bool
}

#Preview {
    LoginView()
}
