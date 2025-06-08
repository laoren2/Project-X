//
//  LoginView.swift
//  sportsx
//
//  Created by 任杰 on 2024/8/8.
//

import SwiftUI

struct LoginView: View {
    @ObservedObject private var userManager = UserManager.shared
    @State private var phoneNumber: String = ""
    @State private var verificationCode: String = ""
    @State private var sendButtonText: String = "发送验证码"
    @State private var sendButtonColor: Color = .green

    
    let config = GlobalConfig.shared

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            HStack {
                Button(action: {
                    userManager.showingLogin = false
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20))
                        .padding()
                        .foregroundStyle(.white)
                }
                Spacer()
            }
            .padding(.top, 10)
            
            Text("验证码登录")
                .foregroundStyle(.white)
            
            HStack {
                TextField("请输入手机号", text: $phoneNumber)
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
                
            TextField("请输入验证码", text: $verificationCode)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.numberPad)
            
            Button("登录") {
                login()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .padding(.top, 10)
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .background(Color.defaultBackground)
        .onChange(of: userManager.showingLogin) {
            if userManager.showingLogin {
                clearAll()
            } else {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
        .ignoresSafeArea(.keyboard)
        .hideKeyboardOnTap()
    }
    
    func login() {
        guard phoneNumber.count == 11 else {
            print("请输入正确的号码")
            return
        }
        guard verificationCode.count == 6 else {
            print("请输入正确的验证码")
            return
        }
        
        login_request()
    }
    
    func login_request() {
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
                print("success compeletion")
                if let unwrappedData = data {
                    let user = unwrappedData.user
                    let relation = unwrappedData.relation
                    DispatchQueue.main.async {
                        userManager.friendCount = relation.friends
                        userManager.followerCount = relation.follower
                        userManager.followedCount = relation.followed
                        userManager.user = User(
                            userID: user.user_id,
                            nickname: user.nickname,
                            phoneNumber: user.phone_number,
                            avatarImageURL: user.avatar_image_url,
                            backgroundImageURL: user.background_image_url,
                            introduction: user.introduction,
                            gender: user.gender,
                            birthday: user.birthday,
                            location: user.location,
                            identityAuthName: user.identity_auth_name,
                            isRealnameAuth: user.is_realname_auth,
                            isIdentityAuth: user.is_identity_auth,
                            isDisplayGender: user.is_display_gender,
                            isDisplayAge: user.is_display_age,
                            isDisplayLocation: user.is_display_location,
                            enableAutoLocation: user.enable_auto_location,
                            isDisplayIdentity: user.is_display_identity
                        )
                        userManager.role = unwrappedData.role
                        userManager.saveUserInfoToCache()
                        if userManager.user.enableAutoLocation {
                            userManager.user.location = config.location
                        }
                        userManager.isLoggedIn = true
                        userManager.showingLogin = false
                    }
                    
                    userManager.downloadImages(avatar_url: user.avatar_image_url, background_url: user.background_image_url)
                    
                    if unwrappedData.isRegister {
                        print("注册成功，进入编辑资料页")
                    } else {
                        print("登录成功")
                    }
                    loginAfterSuccess()
                }
            default:
                break
            }
        }
    }
    
    func loginAfterSuccess() {
        Task {
            MagicCardManager.shared.fetchUserCards() // 获取MagicCard
            await ModelManager.shared.updateModels() // 更新本地MLModel
        }
    }
    
    func sendSmsCode() {
        guard phoneNumber.count == 11 else {
            print("请输入正确的号码")
            return
        }
        sendSmsCode_request(phoneNumber: phoneNumber)
    }
    
    func sendSmsCode_request(phoneNumber: String) {
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
