//
//  UserSetUpView.swift
//  sportsx
//
//  Created by 任杰 on 2025/4/16.
//

import SwiftUI
import AuthenticationServices
import PhotosUI


struct UserSetUpView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var userManager = UserManager.shared
    @State var cacheSizeMB: Double = 0
    @State var isComputingCacheSize: Bool = false
    @State var isCleaning: Bool = false
    
    @State var tapCnt: Int = 0
    @State private var webPage: WebPage?
    
    @Environment(\.openURL) var openURL
    
    var body: some View {
        VStack {
            HStack {
                CommonIconButton(icon: "chevron.left") {
                    appState.navigationManager.removeLast()
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                
                Spacer()
                
                Text("action.setup")
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
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 40) {
                    VStack(spacing: 0) {
                        SetUpItemView(icon: "person", title: "user.setup.account_and_security") {
                            NavigationManager.shared.append(.userSetUpAccountView)
                        }
                        
                        SetUpItemView(icon: "person.text.rectangle", title: "user.setup.realname_auth") {
                            NavigationManager.shared.append(.realNameAuthView)
                        }
                        
                        SetUpItemView(icon: "pencil.and.list.clipboard", title: "user.setup.vip_center") {
                            NavigationManager.shared.append(.subscriptionDetailView)
                        }
                        
                        SetUpItemView(icon: "trash", title: "user.setup.clean_cache", showChevron: false) {
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
                        
                        SetUpItemView(icon: "person.fill.questionmark", title: "user.setup.aboutus") {
                            NavigationManager.shared.append(.aboutUsView)
                        }
                        
                        SetUpItemView(icon: "pencil.and.list.clipboard", title: "user.setup.feedback") {
                            NavigationManager.shared.append(.feedbackView(mailType: .bug))
                        }
                        
                        SetUpItemView(icon: "pencil.and.list.clipboard", title: "user.setup.rate") {
                            if let url = URL(string: "https://apps.apple.com/app/idYOUR_APP_ID?action=write-review") {
                                openURL(url)
                            }
                        }
                        
                        SetUpItemView(icon: "lock", title: "user.setup.user_agreement", showChevron: false) {
                            webPage = WebPage(url: URL(string: "https://www.valbara.top/privacy")!)
                        }
                        
                        SetUpItemView(icon: "lock", title: "user.setup.privacy", showChevron: false, showDivider: false) {
                            webPage = WebPage(url: URL(string: "https://www.valbara.top/privacy")!)
                        }
                    }
                    .cornerRadius(20)
#if DEBUG
                    if userManager.role == .admin {
                        VStack(spacing: 0) {
                            SetUpItemView(icon: "pc", title: "后台管理", showDivider: false, isDarkScheme: false) {
                                NavigationManager.shared.append(.adminPanelView)
                            }
                        }
                        .cornerRadius(20)
                    }
                    VStack(spacing: 0) {
                        SetUpItemView(icon: "pc", title: "本地bike调试", showDivider: false, isDarkScheme: false) {
                            NavigationManager.shared.append(.bikeMatchDebugView)
                        }
                        .cornerRadius(20)
                    }
#endif
                    SetUpItemView(icon: "iphone.and.arrow.forward.outward", title: "user.setup.logout", showChevron: false, showDivider: false) {
                        PopupWindowManager.shared.presentPopup(
                            title: "user.setup.logout",
                            message: "user.setup.popup.logout.content",
                            bottomButtons: [
                                .cancel("action.cancel"),
                                .confirm("user.setup.logout") {
                                    guard !appState.competitionManager.isRecording else {
                                        let toast = Toast(message: "user.setup.toast.logout_failed")
                                        ToastManager.shared.show(toast: toast)
                                        return
                                    }
                                    logoutUser()
                                }
                            ]
                        )
                    }
                    .cornerRadius(20)
                    
                    VStack {
                        HStack(spacing: 6) {
                            Spacer()
                            Image("single_app_icon")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 15)
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
                                    ToastManager.shared.show(toast: Toast(message: "toast.copied"))
                                }
                            if let did = KeychainHelper.standard.deviceID {
                                Text("did: \(did)")
                                    .onTapGesture {
                                        UIPasteboard.general.string = did
                                        ToastManager.shared.show(toast: Toast(message: "toast.copied"))
                                    }
                            }
                        }
                    }
                    .foregroundStyle(Color.secondText)
                    .font(.system(size: 15))
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
                .padding()
            }
        }
        .background(Color.defaultBackground)
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBackGesture()
        .onStableAppear {
            updateCacheSize()
#if DEBUG
            userManager.fetchMeRole()
#endif
        }
        .sheet(item: $webPage) { item in
            SafariView(url: item.url)
                .ignoresSafeArea()
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
                let toast = Toast(message: success ? "user.setup.toast.clean_cache.success" : "user.setup.toast.clean_cache.failed")
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
                
                Text("user.setup.account_and_security")
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
                    SetUpItemView(icon: "phone", title: "user.setup.phone_number") {
                        appState.navigationManager.append(.phoneBindView)
                    } trailingView: {
                        if userManager.user.phoneNumber != nil {
                            Text("user.setup.phone.status.has_bind")
                                .foregroundStyle(Color.secondText)
                        } else {
                            HStack(alignment: .bottom, spacing: 2) {
                                Image(systemName: "exclamationmark.circle")
                                    .foregroundStyle(Color.pink)
                                Text("user.setup.phone.status.no_bind")
                                    .foregroundStyle(Color.secondText)
                            }
                        }
                    }
                    SetUpItemView(icon: "apple.logo", title: "user.setup.apple_account") {
                        appState.navigationManager.append(.appleBindView)
                    } trailingView: {
                        if userManager.user.apple_email != nil {
                            Text("user.setup.phone.status.has_bind")
                                .foregroundStyle(Color.secondText)
                        } else {
                            HStack(alignment: .bottom, spacing: 2) {
                                Image(systemName: "exclamationmark.circle")
                                    .foregroundStyle(Color.pink)
                                Text("user.setup.phone.status.no_bind")
                                    .foregroundStyle(Color.secondText)
                            }
                        }
                    }
                    SetUpItemView(icon: "envelope.fill", title: "user.page.features.email_box", showDivider: false) {
                        appState.navigationManager.append(.emailBindView)
                    } trailingView: {
                        if userManager.user.email != nil {
                            Text("user.setup.phone.status.has_bind")
                                .foregroundStyle(Color.secondText)
                        } else {
                            HStack(alignment: .bottom, spacing: 2) {
                                Image(systemName: "exclamationmark.circle")
                                    .foregroundStyle(Color.pink)
                                Text("user.setup.phone.status.no_bind")
                                    .foregroundStyle(Color.secondText)
                            }
                        }
                    }
                }
                .cornerRadius(20)
                .padding()
                
                VStack {
                    SetUpItemView(icon: "person.slash", title: "user.setup.account_delete", showChevron: false, showDivider: false) {
                        PopupWindowManager.shared.presentPopup(
                            title: "user.setup.account_delete",
                            message: "user.setup.toast.account_delete.content",
                            bottomButtons: [
                                .confirm("user.setup.action.keep_account"),
                                PopupButton {
                                    userManager.cancelUser()
                                } content: {
                                    Text("user.setup.action.account_delete")
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 20)
                                        .background(Color.red)
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                }
                            ]
                        )
                    }
                }
                .cornerRadius(20)
                .padding()
            }
        }
        .background(Color.defaultBackground)
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBackGesture()
    }
}

struct PhoneBindView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var userManager = UserManager.shared
    @State private var phoneNumber: String = ""
    @State private var verificationCode: String = ""
    
    @State private var countdown: Int = 60
    @State private var alreadySendCode = false
    
    @State private var timer: Timer?
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                CommonIconButton(icon: "chevron.left") {
                    appState.navigationManager.removeLast()
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                
                Spacer()
                
                Text("user.setup.phone_number")
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
            Spacer()
            if let number = userManager.user.phoneNumber {
                Text("user.setup.phone.bind_info \(number.maskedPhone())")
                    .foregroundStyle(.white)
                Button("user.setup.action.phone.unbind") {
                    unbindPhone()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.red)
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
                    
                    TextField("login.sms.phone.placeholder", text: $phoneNumber)
                        .padding(.leading, 10)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                }
                
                if alreadySendCode {
                    Text(countdown == 0 ? "login.sms.send_result.2" : "login.sms.send_result.1 \(countdown)")
                        .foregroundStyle(Color.secondText)
                    HStack {
                        TextField("login.sms.code.placeholder", text: $verificationCode)
                            .textContentType(.oneTimeCode)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                        
                        Button(action: {
                            if countdown == 0 {
                                sendSmsCode()
                            }
                        }) {
                            Text("login.sms.action.send_again")
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
                        bindPhone()
                    } else {
                        sendSmsCode()
                    }
                }) {
                    Text(alreadySendCode ? "user.setup.action.phone.bind" : "user.setup.action.phone.verify_and_bind")
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.top, 10)
                }
            }
            Spacer()
        }
        .padding(.horizontal)
        .background(Color.defaultBackground)
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBackGesture()
        .hideKeyboardOnTap()
    }
    
    func sendSmsCode() {
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
        
        let request = APIRequest(path: "/user/send_sms_code", method: .post, headers: headers, body: encodedBody)
        
        NetworkService.sendRequest(with: request, decodingType: SmsCodeResponse.self, showLoadingToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                DispatchQueue.main.async {
                    alreadySendCode = true
                    // 开始倒计时60s，60s后可重新发送验证码
                    startCodeTimer()
                }
            default:
                break
            }
        }
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
    
    func bindPhone() {
        guard phoneNumber.count == 8 else {
            ToastManager.shared.show(toast: Toast(message: "login.toast.error_number"))
            return
        }
        guard verificationCode.count == 6 else {
            ToastManager.shared.show(toast: Toast(message: "login.toast.error_code"))
            return
        }
        
        var headers: [String: String] = [:]
        headers["Content-Type"] = "application/json"
        
        let body = ["phone_number": phoneNumber, "code": verificationCode]
        guard let encodedBody = try? JSONEncoder().encode(body) else { return }
        
        let request = APIRequest(path: "/user/account/bind_phone", method: .post, headers: headers, body: encodedBody, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: EmptyResponse.self, showLoadingToast: true, showErrorToast: true) { result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    UserManager.shared.user.phoneNumber = phoneNumber
                    UserDefaults.standard.set(phoneNumber, forKey: "user.phoneNumber")
                    ToastManager.shared.show(toast: Toast(message: "user.page.bind_device.result.success"))
                }
            default: break
            }
        }
    }
    
    func unbindPhone() {
        let request = APIRequest(path: "/user/account/unbind_phone", method: .post, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: EmptyResponse.self, showLoadingToast: true, showErrorToast: true) { result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    UserManager.shared.user.phoneNumber = nil
                    UserDefaults.standard.removeObject(forKey: "user.phoneNumber")
                    ToastManager.shared.show(toast: Toast(message: "user.page.unbind_device.result.success"))
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
                
                Text("user.setup.apple_account")
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
            Spacer()
            if let email = userManager.user.apple_email {
                Text("user.setup.apple.bind_info \(email.maskedEmail())")
                    .foregroundStyle(.white)
                    .padding(.horizontal)
                Button("user.setup.action.phone.unbind") {
                    unbindApple()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.top, 10)
            } else {
                VStack {
                    Image("appleid_button")
                    Text("user.setup.action.apple.bind")
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
        .enableSwipeBackGesture()
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
        
        NetworkService.sendRequest(with: request, decodingType: EmptyResponse.self, showLoadingToast: true, showErrorToast: true) { result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    UserManager.shared.user.apple_email = nil
                    UserDefaults.standard.removeObject(forKey: "user.appleEmail")
                    ToastManager.shared.show(toast: Toast(message: "user.page.unbind_device.result.success"))
                }
            default: break
            }
        }
    }
}

struct EmailBindView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var userManager = UserManager.shared
    @State private var emailAddress: String = ""
    @State private var verificationCode: String = ""
    
    @State private var countdown: Int = 60
    @State private var alreadySendCode = false
    
    @State private var timer: Timer?
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                CommonIconButton(icon: "chevron.left") {
                    appState.navigationManager.removeLast()
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                
                Spacer()
                
                Text("user.page.features.email_box")
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
            Spacer()
            if let email = userManager.user.email {
                Text("user.setup.email.bind_info \(email.maskedEmail())")
                    .foregroundStyle(.white)
                Button("user.setup.action.phone.unbind") {
                    unbindEmail()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.top, 10)
            } else {
                TextField("login.email.placeholder", text: $emailAddress)
                    .padding(.leading, 10)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.emailAddress)
                
                if alreadySendCode {
                    Text(countdown == 0 ? "login.email.send_result.2" : "login.email.send_result.1 \(countdown)")
                        .foregroundStyle(Color.secondText)
                    HStack {
                        TextField("login.sms.code.placeholder", text: $verificationCode)
                            .textContentType(.oneTimeCode)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                        
                        Button(action: {
                            if countdown == 0 {
                                sendSmsCode()
                            }
                        }) {
                            Text("login.sms.action.send_again")
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
                        bindEmail()
                    } else {
                        sendSmsCode()
                    }
                }) {
                    Text(alreadySendCode ? "user.setup.action.phone.bind" : "user.setup.action.phone.verify_and_bind")
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.top, 10)
                }
            }
            Spacer()
        }
        .padding(.horizontal)
        .background(Color.defaultBackground)
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBackGesture()
        .hideKeyboardOnTap()
    }
    
    func sendSmsCode() {
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
            case .success:
                DispatchQueue.main.async {
                    alreadySendCode = true
                    // 开始倒计时60s，60s后可重新发送验证码
                    startCodeTimer()
                }
            default:
                break
            }
        }
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
    
    func bindEmail() {
        guard emailAddress.contains("@") else {
            ToastManager.shared.show(toast: Toast(message: "login.toast.error_email"))
            return
        }
        guard verificationCode.count == 6 else {
            ToastManager.shared.show(toast: Toast(message: "login.toast.error_code"))
            return
        }
        
        var headers: [String: String] = [:]
        headers["Content-Type"] = "application/json"
        
        let body = ["email_address": emailAddress, "code": verificationCode]
        guard let encodedBody = try? JSONEncoder().encode(body) else { return }
        
        let request = APIRequest(path: "/user/account/bind_email", method: .post, headers: headers, body: encodedBody, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: EmptyResponse.self, showLoadingToast: true, showErrorToast: true) { result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    UserManager.shared.user.email = emailAddress
                    UserDefaults.standard.set(emailAddress, forKey: "user.email")
                    ToastManager.shared.show(toast: Toast(message: "user.page.bind_device.result.success"))
                }
            default: break
            }
        }
    }
    
    func unbindEmail() {
        let request = APIRequest(path: "/user/account/unbind_email", method: .post, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: EmptyResponse.self, showLoadingToast: true, showErrorToast: true) { result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    UserManager.shared.user.email = nil
                    UserDefaults.standard.removeObject(forKey: "user.email")
                    ToastManager.shared.show(toast: Toast(message: "user.page.unbind_device.result.success"))
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
        var headers: [String: String] = [:]
        headers["Content-Type"] = "application/json"
        
        let body: [String: String] = [
            "jws": token
        ]
        guard let encodedBody = try? JSONEncoder().encode(body) else { return }
        
        let request = APIRequest(path: "/user/account/bind_apple_id", method: .post, headers: headers, body: encodedBody, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: String.self, showLoadingToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let email = data {
                    DispatchQueue.main.async {
                        UserManager.shared.user.apple_email = email
                        UserDefaults.standard.set(email, forKey: "user.appleEmail")
                        ToastManager.shared.show(toast: Toast(message: "user.page.bind_device.result.success"))
                    }
                }
            default: break
            }
        }
    }
}

struct FeedbackView: View {
    @ObservedObject var navigationManager = NavigationManager.shared
    @State var mailType: FeedbackMailType
    @State var connectInfo: String = ""
    @State var description: String = ""
    @State var iapImage1: UIImage? = nil
    @State var iapImage2: UIImage? = nil
    @State var showImagePicker: Bool = false
    @State var showMailTypeSelector: Bool = false
    @State var selectedImageItem: PhotosPickerItem?
    var imageCount: Int { return (iapImage1 == nil ? 0 : 1) + (iapImage2 == nil ? 0 : 1) }
    
    let reportUserID: String?
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                CommonIconButton(icon: "chevron.left") {
                    navigationManager.removeLast()
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                Spacer()
                Text(reportUserID == nil ? "action.feedback" : "user.setup.feedback.report_user")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: {}) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.clear)
                }
            }
            .padding(.horizontal)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    if reportUserID == nil {
                        HStack {
                            Text("user.setup.feedback.question_type")
                                .font(.title2)
                                .foregroundStyle(Color.white)
                            Spacer()
                            HStack(spacing: 5) {
                                Text(LocalizedStringKey(mailType.displayName))
                                Image(systemName: "chevron.forward")
                            }
                            .font(.title3)
                            .foregroundStyle(Color.secondText)
                            .exclusiveTouchTapGesture {
                                showMailTypeSelector = true
                            }
                        }
                    }
                    
                    HStack {
                        Text("user.setup.feedback.contact") + Text(" (") + Text(mailType == .iap ? "user.setup.feedback.required" : "user.setup.feedback.optional") + Text(" )")
                        Spacer()
                    }
                    .font(.title2)
                    .foregroundStyle(Color.white)
                    TextField(text: $connectInfo) {
                        Text("user.setup.feedback.contact.placeholder")
                            .foregroundColor(.thirdText)
                    }
                    .padding()
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden) // 隐藏系统默认的背景
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    HStack {
                        Text("user.setup.feedback.description")
                            .font(.title2)
                            .foregroundStyle(Color.white)
                        Spacer()
                    }
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $description)
                            .padding()
                            .frame(maxHeight: 120)
                            .foregroundColor(.white)
                            .scrollContentBackground(.hidden) // 隐藏系统默认的背景
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                            .onValueChange(of: description) {
                                DispatchQueue.main.async {
                                    if description.count > 100 {
                                        description = String(description.prefix(100))
                                    }
                                }
                            }
                        if description.isEmpty {
                            Text("user.setup.feedback.description.placeholder")
                                .foregroundStyle(Color.thirdText)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 24)
                        }
                    }
                    HStack {
                        Spacer()
                        Text("user.intro.words_entered \(description.count) \(100)")
                            .font(.caption)
                            .foregroundStyle(Color.thirdText)
                    }
                    HStack {
                        Text("user.setup.feedback.screenshot") + Text(" (") + Text("user.setup.feedback.optional") + Text(" \(imageCount)/2 )")
                        Spacer()
                    }
                    .font(.title2)
                    .foregroundStyle(Color.white)
                    HStack {
                        if let image = iapImage1 {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 150, height: 150)
                                .onTapGesture {
                                    showImagePicker = true
                                }
                        }
                        if let image = iapImage2 {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 150, height: 150)
                                .onTapGesture {
                                    showImagePicker = true
                                }
                        }
                        if iapImage1 == nil || iapImage2 == nil {
                            EmptyCardSlot(text: "user.setup.feedback.screenshot.placeholder", ratio: 1)
                                .frame(height: 150)
                                .onTapGesture {
                                    showImagePicker = true
                                }
                        }
                    }
                    Button(action:{
                        commitFeedback()
                        navigationManager.removeLast()
                    }) {
                        Text("action.submit")
                            .padding(.vertical)
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity)
                            .background((description.isEmpty || (mailType == .iap && connectInfo.isEmpty)) ? Color.gray : Color.orange)
                            .cornerRadius(10)
                    }
                    .disabled((description.isEmpty || (mailType == .iap && connectInfo.isEmpty)))
                    .padding(.top, 50)
                    .padding(.bottom, 50)
                }
                .padding()
            }
        }
        .background(Color.defaultBackground)
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBackGesture()
        .hideKeyboardOnScroll()
        .ignoresSafeArea(.keyboard)
        .photosPicker(isPresented: $showImagePicker, selection: $selectedImageItem, matching: .images)
        .onValueChange(of: selectedImageItem) {
            Task {
                if let data = try? await selectedImageItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    if iapImage1 == nil {
                        iapImage1 = uiImage
                    } else {
                        iapImage2 = uiImage
                    }
                } else {
                    iapImage1 = nil
                    iapImage2 = nil
                }
            }
        }
        .confirmationDialog("user.setup.feedback.question_type", isPresented: $showMailTypeSelector, titleVisibility: .visible) {
            ForEach(FeedbackMailType.allCases, id: \.self) { type in
                Button(action: {
                    mailType = type
                }) {
                    Text(LocalizedStringKey(type.displayName))
                }
            }
        }
    }
    
    func commitFeedback() {
        let boundary = "Boundary-\(UUID().uuidString)"
        
        var headers: [String: String] = [:]
        headers["Content-Type"] = "multipart/form-data; boundary=\(boundary)"
        
        var body = Data()
        
        var content: String = ""
        if let reportUserID = reportUserID {
            content = "举报用户：\(reportUserID)\n\(description)"
        } else {
            content = description
        }
        
        // 文字字段
        var textFields: [String : String] = [
            "type": mailType.rawValue,
            "content": content
        ]
        if !connectInfo.isEmpty {
            textFields["user_contact_info"] = connectInfo
        }
        for (key, value) in textFields {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.append("\(value)\r\n")
        }
        
        // 图片字段
        let images: [(name: String, image: UIImage?, filename: String)] = [
            ("image1", iapImage1, "image1.jpg"),
            ("image2", iapImage2, "image2.jpg")
        ]
        for (name, image, filename) in images {
            if let unwrappedImage = image, let imageData = ImageTool.compressImage(unwrappedImage, maxSizeKB: 100) {
                body.append("--\(boundary)\r\n")
                body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
                body.append("Content-Type: image/jpeg\r\n\r\n")
                body.append(imageData)
                body.append("\r\n")
            }
        }
        
        body.append("--\(boundary)--\r\n")
        
        let request = APIRequest(path: "/mailbox/commit_feedback", method: .post, headers: headers, body: body, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: EmptyResponse.self, showLoadingToast: true, showErrorToast: true) { result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    ToastManager.shared.show(toast: Toast(message: "user.setup.feedback.toast.success"))
                }
            default: break
            }
        }
    }
}

struct AboutUsView: View {
    @ObservedObject var navigationManager = NavigationManager.shared
    
    let emailAdress: String = "contact@valbara.top"
    let vxAccount: String = "97784765"
    
    var body: some View {
        VStack {
            HStack {
                CommonIconButton(icon: "chevron.left") {
                    navigationManager.removeLast()
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                
                Spacer()
                
                Text("user.setup.aboutus")
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
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    VStack(spacing: 0) {
                        Image("app_logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100)
                            .clipShape(Circle())
                        Text("Sporreer")
                            .foregroundStyle(Color.white)
                            .font(.headline)
                            .padding(.top, 20)
                        Text("·version: \(AppVersionManager.shared.currentVersion.toString())·")
                            .foregroundStyle(Color.thirdText)
                            .font(.subheadline)
                            .padding(.top, 6)
                    }
                    VStack {
                        HStack {
                            Text("user.setup.contact_us")
                                .foregroundStyle(Color.thirdText)
                                .font(.subheadline)
                                .padding(.leading, 10)
                            Spacer()
                        }
                        VStack(spacing: 0) {
                            SetUpItemView(icon: "envelope", title: "user.setup.contact_us.email", showChevron: false) {
                                UIPasteboard.general.string = emailAdress
                                let toast = Toast(message: "toast.copied", duration: 2)
                                ToastManager.shared.show(toast: toast)
                            } trailingView: {
                                HStack(spacing: 4) {
                                    Text(emailAdress)
                                    Image(systemName: "doc.on.doc")
                                }
                                .foregroundStyle(Color.thirdText)
                                .font(.subheadline)
                            }
                            
                            SetUpItemView(icon: "envelope", title: "user.setup.contact_us.wx", showChevron: false, showDivider: false) {
                                UIPasteboard.general.string = vxAccount
                                let toast = Toast(message: "toast.copied", duration: 2)
                                ToastManager.shared.show(toast: toast)
                            } trailingView: {
                                HStack(spacing: 4) {
                                    Text(vxAccount)
                                    Image(systemName: "doc.on.doc")
                                }
                                .foregroundStyle(Color.thirdText)
                                .font(.subheadline)
                            }
                        }
                        .cornerRadius(20)
                    }
                }
                .padding(.vertical, 50)
                .padding(.horizontal)
            }
        }
        .background(Color.defaultBackground)
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBackGesture()
    }
}

#Preview {
    let appState = AppState.shared
    UserSetUpAccountView()
        .environmentObject(appState)
}
