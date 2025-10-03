//
//  LoginView.swift
//  sportsx
//
//  Created by 任杰 on 2024/8/8.
//

import SwiftUI
import UIKit
import AuthenticationServices


struct LoginView: View {
    @ObservedObject private var userManager = UserManager.shared
    @State private var phoneNumber: String = ""
    @State private var verificationCode: String = ""
    @State private var sendButtonText: String = "发送验证码"
    @State private var sendButtonColor: Color = .green

    
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
                    Text("欢迎来到 SportsX")
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
                    
                    HStack {
                        TextField("请输入验证码", text: $verificationCode)
                            .padding(.trailing, 10)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                        Button(action: {
                            sendSmsCode()
                            print("验证码已发送")
                        }) {
                            Text(sendButtonText)
                                .foregroundStyle(.white)
                                .font(.system(size: 15))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(sendButtonColor)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    
                    Button("登录") {
                        loginWithSMS()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.top, 10)
                }
                .padding(.top, 50)
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
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = AppleSignInCoordinator.shared
        controller.presentationContextProvider = AppleSignInCoordinator.shared
        controller.performRequests()
    }
    
    func loginWithSMS() {
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
                        config.refreshAll()
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
        
        NetworkService.sendRequest(with: request, decodingType: SmsCodeResponse.self, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    print("验证码: \(unwrappedData.code)")
                    sendButtonText = "已发送:\(unwrappedData.code)"
                    sendButtonColor = .gray
                }
            default:
                break
            }
        }
    }
    
    func clearAll() {
        phoneNumber = ""
        verificationCode = ""
        sendButtonText = "发送验证码"
        sendButtonColor = .green
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
