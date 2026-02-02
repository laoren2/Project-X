//
//  LoginView.swift
//  sportsx
//
//  Created by 任杰 on 2024/8/8.
//

import SwiftUI
import UIKit
import AuthenticationServices


struct SmsLoginView: View {
    @ObservedObject private var navigationManager = NavigationManager.shared
    @ObservedObject private var userManager = UserManager.shared
    
    @State private var phoneNumber: String = ""
    @State private var smsCode: String = ""
    @State private var showingWebView = false
    @State private var webPage: WebPage?
    @State private var agreed = false
    @State private var countdown: Int = 60
    @State private var alreadySendSMSCode = false
    
    @State private var timer: Timer?
    

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                CommonIconButton(icon: "chevron.left") {
                    navigationManager.removeLast()
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                Spacer()
            }
            
            HStack {
                Text("login.title")
                    .font(.title)
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding(.top, 40)
            
            HStack {
                Text("login.subtitle")
                    .foregroundStyle(Color.thirdText)
                    .font(.headline)
                Spacer()
            }
            VStack(spacing: 20) {
                Text("login.sms.title")
                    .foregroundStyle(Color.white)
                    .font(.title2)
                HStack {
                    Text("+852")
                        .padding()
                        .foregroundStyle(Color.black)
                        .background(Color.white)
                        .cornerRadius(10)
                    
                    TextField(text: $phoneNumber) {
                        Text("login.sms.phone.placeholder")
                            .foregroundStyle(Color.gray)
                    }
                    .padding()
                    .foregroundStyle(Color.black)
                    .scrollContentBackground(.hidden)
                    .keyboardType(.numberPad)
                    .background(Color.white)
                    .cornerRadius(10)
                }
                
                if alreadySendSMSCode {
                    Text(countdown == 0 ? "login.sms.send_result.2" : "login.sms.send_result.1 \(countdown)")
                        .foregroundStyle(Color.secondText)
                    HStack {
                        TextField(text: $smsCode) {
                            Text("login.sms.code.placeholder")
                                .foregroundStyle(Color.gray)
                        }
                        .padding()
                        .foregroundStyle(Color.black)
                        .textContentType(.oneTimeCode)
                        .scrollContentBackground(.hidden)
                        .keyboardType(.numberPad)
                        .background(Color.white)
                        .cornerRadius(10)
                        
                        Button(action: {
                            if countdown == 0 {
                                sendSmsCode()
                            }
                        }) {
                            Text("login.sms.action.send_again")
                                .foregroundStyle(Color.white)
                                .padding()
                                .background(countdown == 0 ? Color.green : Color.gray)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .disabled(countdown != 0)
                    }
                }
                
                Button(action: {
                    if alreadySendSMSCode {
                        loginWithSMS()
                    } else {
                        sendSmsCode()
                    }
                }) {
                    Text(alreadySendSMSCode ? "action.login" : "login.sms.action.verify_and_login")
                        .font(.headline)
                        .foregroundStyle(agreed ? Color.white : Color.thirdText)
                        .padding(.vertical)
                        .frame(maxWidth: .infinity)
                        .background(agreed ? Color.orange : Color.orange.opacity(0.2))
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
                Text("action.read_and_agree")
                Text("user.setup.user_agreement")
                    .underline()
                    .foregroundStyle(Color.orange.opacity(0.6))
                    .onTapGesture {
                        AgreementHelper.open("https://www.valbara.top/user_agreement", binding: $webPage)
                    }
                Text("common.and")
                Text("user.setup.privacy")
                    .underline()
                    .foregroundStyle(Color.orange.opacity(0.6))
                    .onTapGesture {
                        AgreementHelper.open("https://www.valbara.top/privacy", binding: $webPage)
                    }
            }
            .font(.system(size: 13))
            .foregroundStyle(Color.thirdText)
            .sheet(item: $webPage) { item in
                SafariView(url: item.url)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .background(Color.defaultBackground)
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBackGesture()
        .ignoresSafeArea(.keyboard)
        .hideKeyboardOnTap()
    }
    
    func loginWithSMS() {
        guard agreed else {
            ToastManager.shared.show(toast: Toast(message: "login.toast.privacy_and_user_agreement"))
            return
        }
        guard phoneNumber.count == 8 else {
            ToastManager.shared.show(toast: Toast(message: "login.toast.error_number"))
            return
        }
        guard smsCode.count == 6 else {
            ToastManager.shared.show(toast: Toast(message: "login.toast.error_code"))
            return
        }
        
        let body = ["phone_number": phoneNumber, "code": smsCode]
        guard let encodedBody = try? JSONEncoder().encode(body) else {
            return
        }
        
        var headers: [String: String] = [:]
        headers["Content-Type"] = "application/json"
        
        let request = APIRequest(path: "/user/login/sms", method: .post, headers: headers, body: encodedBody, requiresAuth: false)
        
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
                        navigationManager.removeLast()
                        if unwrappedData.isRegister {
                            PopupWindowManager.shared.presentPopup(
                                title: "login.reigster.popup.welcome",
                                message: "login.reigster.popup.content",
                                bottomButtons: [
                                    .cancel("login.reigster.popup.action.cancel"),
                                    .confirm("login.reigster.popup.action.confirm") {
                                        navigationManager.append(.userIntroEditView)
                                    }
                                ]
                            )
                        }
                    }
                    
                    userManager.downloadImages(avatar_url: user.avatar_image_url, background_url: user.background_image_url)
                    
                    Task {
                        await AssetManager.shared.queryCCAssets()
                        await AssetManager.shared.queryCPAssets(withLoadingToast: false)
                        await AssetManager.shared.queryMagicCards(withLoadingToast: false)
                    }
                }
            default:
                break
            }
        }
    }
    
    func sendSmsCode() {
        guard agreed else {
            ToastManager.shared.show(toast: Toast(message: "login.toast.privacy_and_user_agreement"))
            return
        }
        guard phoneNumber.count == 8 else {
            ToastManager.shared.show(toast: Toast(message: "login.toast.error_number"))
            return
        }
        var headers: [String: String] = [:]
        headers["Content-Type"] = "application/json"
        
        let body = ["phone_number": phoneNumber]
        guard let encodedBody = try? JSONEncoder().encode(body) else {
            return
        }
        
        let request = APIRequest(path: "/user/send_sms_code", method: .post, headers: headers, body: encodedBody, requiresAuth: false)
        
        NetworkService.sendRequest(with: request, decodingType: SmsCodeResponse.self, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        alreadySendSMSCode = true
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
}

struct LoginView: View {
    @ObservedObject private var navigationManager = NavigationManager.shared
    @ObservedObject private var userManager = UserManager.shared

    @State private var emailAddress: String = ""
    @State private var emailCode: String = ""
#if DEBUG
    @State private var emailPass: String = ""
#endif
    @State private var showingWebView = false
    @State private var webPage: WebPage?
    @State private var agreed = false
    @State private var countdown: Int = 60
    @State private var alreadySendEmailCode = false
    
    @State private var timer: Timer?
    
    var body: some View {
        ZStack {
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
                    Text("login.title")
                        .font(.title)
                        .foregroundStyle(.white)
                    Spacer()
                }
                .padding(.top, 40)
                
                HStack {
                    Text("login.subtitle")
                        .foregroundStyle(Color.thirdText)
                        .font(.headline)
                    Spacer()
                }
                VStack(spacing: 20) {
                    Text("login.email.title")
                        .foregroundStyle(Color.white)
                        .font(.title2)
                    TextField(text: $emailAddress) {
                        Text("login.email.placeholder")
                            .foregroundStyle(Color.gray)
                    }
                    .padding()
                    .foregroundStyle(Color.black)
                    .scrollContentBackground(.hidden)
                    .keyboardType(.emailAddress)
                    .background(Color.white)
                    .cornerRadius(10)
                    
                    if alreadySendEmailCode {
                        Text(countdown == 0 ? "login.email.send_result.2" : "login.email.send_result.1 \(countdown)")
                            .foregroundStyle(Color.secondText)
                        HStack {
                            TextField(text: $emailCode) {
                                Text("login.sms.code.placeholder")
                                    .foregroundStyle(Color.gray)
                            }
                            .padding()
                            .foregroundStyle(Color.black)
                            .textContentType(.oneTimeCode)
                            .scrollContentBackground(.hidden)
                            .keyboardType(.numberPad)
                            .background(Color.white)
                            .cornerRadius(10)
                            
                            Button(action: {
                                if countdown == 0 {
                                    sendEmailCode()
                                }
                            }) {
                                Text("login.sms.action.send_again")
                                    .padding()
                                    .foregroundStyle(Color.white)
                                    .background(countdown == 0 ? Color.green : Color.gray)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .disabled(countdown != 0)
                        }
                    }
                    
                    Button(action: {
                        if alreadySendEmailCode {
                            loginWithEmail()
                        } else {
                            sendEmailCode()
                        }
                    }) {
                        Text(alreadySendEmailCode ? "action.login" : "login.sms.action.verify_and_login")
                            .font(.headline)
                            .foregroundStyle(agreed ? Color.white : Color.thirdText)
                            .padding(.vertical)
                            .frame(maxWidth: .infinity)
                            .background(agreed ? Color.orange : Color.orange.opacity(0.2))
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
                    Text("action.read_and_agree")
                    Text("user.setup.user_agreement")
                        .underline()
                        .foregroundStyle(Color.orange.opacity(0.6))
                        .onTapGesture {
                            AgreementHelper.open("https://www.valbara.top/user_agreement", binding: $webPage)
                        }
                    Text("common.and")
                    Text("user.setup.privacy")
                        .underline()
                        .foregroundStyle(Color.orange.opacity(0.6))
                        .onTapGesture {
                            AgreementHelper.open("https://www.valbara.top/privacy", binding: $webPage)
                        }
                }
                .font(.system(size: 13))
                .foregroundStyle(Color.thirdText)
                .sheet(item: $webPage) { item in
                    SafariView(url: item.url)
                }
#if DEBUG
                HStack(spacing: 20) {
                    TextField(text: $emailPass) {
                        Text("请输入测试账号密码")
                            .foregroundStyle(Color.thirdText)
                    }
                    .padding(10)
                    .foregroundStyle(Color.white)
                    .scrollContentBackground(.hidden)
                    .keyboardType(.emailAddress)
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
                    
                    Button("测试登录") {
                        loginTestAccount()
                    }
                }
#endif
                Spacer()
            }
            .padding(.horizontal, 20)
            
            // 使用ZStack布局可以暂时解决键盘弹出挤压问题
            VStack {
                Spacer()
                HStack(spacing: 6) {
                    Spacer()
                    VStack {
                        Image("appleid_button")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 55)
                        Text("login.apple.action")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.secondText)
                    }
                    .onTapGesture {
                        loginWithAppleID()
                    }
                    Spacer()
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(Color.secondText)
                                .frame(width: 55, height: 55)
                            Image("sms_login")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 28)
                                .foregroundStyle(Color.black)
                        }
                            
                        Text("login.sms.action")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.secondText)
                    }
                    .onTapGesture {
                        navigationManager.append(.smsLoginView)
                        userManager.showingLogin = false
                    }
                    Spacer()
                }
                .padding(.bottom, 50)
            }
        }
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
    
#if DEBUG
    func loginTestAccount() {
        let body = ["email_address": emailAddress, "code": emailPass]
        guard let encodedBody = try? JSONEncoder().encode(body) else { return }
        
        var headers: [String: String] = [:]
        headers["Content-Type"] = "application/json"
        
        let request = APIRequest(path: "/user/login/test_account", method: .post, headers: headers, body: encodedBody)
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
                        userManager.isLoggedIn = true
                        userManager.showingLogin = false
                        if unwrappedData.isRegister {
                            PopupWindowManager.shared.presentPopup(
                                title: "login.reigster.popup.welcome",
                                message: "login.reigster.popup.content",
                                bottomButtons: [
                                    .cancel("login.reigster.popup.action.cancel"),
                                    .confirm("login.reigster.popup.action.confirm") {
                                        navigationManager.append(.userIntroEditView)
                                    }
                                ]
                            )
                        }
                    }
                    
                    userManager.downloadImages(avatar_url: user.avatar_image_url, background_url: user.background_image_url)
                    
                    Task {
                        await AssetManager.shared.queryCCAssets()
                        await AssetManager.shared.queryCPAssets(withLoadingToast: false)
                        await AssetManager.shared.queryMagicCards(withLoadingToast: false)
                    }
                }
            default:
                break
            }
        }
    }
#endif
    
    func sendEmailCode() {
        guard agreed else {
            ToastManager.shared.show(toast: Toast(message: "login.toast.privacy_and_user_agreement"))
            return
        }
        guard emailAddress.contains("@") else {
            ToastManager.shared.show(toast: Toast(message: "login.toast.error_email"))
            return
        }
        var headers: [String: String] = [:]
        headers["Content-Type"] = "application/json"
        
        let body = ["email_address": emailAddress]
        guard let encodedBody = try? JSONEncoder().encode(body) else {
            return
        }
        
        let request = APIRequest(path: "/user/send_email_code", method: .post, headers: headers, body: encodedBody)
        
        NetworkService.sendRequest(with: request, decodingType: EmptyResponse.self, showLoadingToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                DispatchQueue.main.async {
                    alreadySendEmailCode = true
                    // 开始倒计时60s，60s后可重新发送验证码
                    startCodeTimer()
                }
            default:
                break
            }
        }
    }
    
    func loginWithEmail() {
        guard agreed else {
            ToastManager.shared.show(toast: Toast(message: "login.toast.privacy_and_user_agreement"))
            return
        }
        guard emailAddress.contains("@") else {
            ToastManager.shared.show(toast: Toast(message: "login.toast.error_email"))
            return
        }
        guard emailCode.count == 6 else {
            ToastManager.shared.show(toast: Toast(message: "login.toast.error_code"))
            return
        }
        
        let body = ["email_address": emailAddress, "code": emailCode]
        guard let encodedBody = try? JSONEncoder().encode(body) else {
            return
        }
        
        var headers: [String: String] = [:]
        headers["Content-Type"] = "application/json"
        
        let request = APIRequest(path: "/user/login/email", method: .post, headers: headers, body: encodedBody)
        
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
                        if unwrappedData.isRegister {
                            PopupWindowManager.shared.presentPopup(
                                title: "login.reigster.popup.welcome",
                                message: "login.reigster.popup.content",
                                bottomButtons: [
                                    .cancel("login.reigster.popup.action.cancel"),
                                    .confirm("login.reigster.popup.action.confirm") {
                                        navigationManager.append(.userIntroEditView)
                                    }
                                ]
                            )
                        }
                    }
                    
                    userManager.downloadImages(avatar_url: user.avatar_image_url, background_url: user.background_image_url)
                    
                    Task {
                        await AssetManager.shared.queryCCAssets()
                        await AssetManager.shared.queryCPAssets(withLoadingToast: false)
                        await AssetManager.shared.queryMagicCards(withLoadingToast: false)
                    }
                }
            default:
                break
            }
        }
    }
    
    func loginWithAppleID() {
        guard agreed else {
            ToastManager.shared.show(toast: Toast(message: "login.toast.privacy_and_user_agreement"))
            return
        }
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = AppleSignInCoordinator.shared
        controller.presentationContextProvider = AppleSignInCoordinator.shared
        controller.performRequests()
    }
    
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
        emailAddress = ""
        emailCode = ""
        alreadySendEmailCode = false
        countdown = 0
        agreed = false
        
        timer?.invalidate()
        timer = nil
#if DEBUG
        emailPass = ""
#endif
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
        var headers: [String: String] = [:]
        headers["Content-Type"] = "application/json"
        
        let body: [String: String] = [
            "jws": token
        ]
        guard let encodedBody = try? JSONEncoder().encode(body) else { return }
        
        let request = APIRequest(path: "/user/login/apple", method: .post, headers: headers, body: encodedBody)
        
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
                        //GlobalConfig.shared.refreshAll()
                        userManager.isLoggedIn = true
                        userManager.showingLogin = false
                        if unwrappedData.isRegister {
                            PopupWindowManager.shared.presentPopup(
                                title: "login.reigster.popup.welcome",
                                message: "login.reigster.popup.content",
                                bottomButtons: [
                                    .cancel("login.reigster.popup.action.cancel"),
                                    .confirm("login.reigster.popup.action.confirm") {
                                        NavigationManager.shared.append(.userIntroEditView)
                                    }
                                ]
                            )
                        }
                    }
                    
                    userManager.downloadImages(avatar_url: user.avatar_image_url, background_url: user.background_image_url)
                    
                    Task {
                        await AssetManager.shared.queryCCAssets()
                        await AssetManager.shared.queryCPAssets(withLoadingToast: false)
                        await AssetManager.shared.queryMagicCards(withLoadingToast: false)
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
