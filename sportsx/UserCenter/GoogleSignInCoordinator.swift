import Foundation
import SwiftUI
import UIKit
import GoogleSignIn
import GoogleSignInSwift

private struct GoogleIDTokenPayload: Codable {
    let id_token: String
    let timezone: String
}

enum GoogleSignInPurpose: Equatable {
    case login
    case bind
}

/// 保留官方 Google 图标与边界，仅将图标按钮适配为登录入口一致的圆形尺寸。
struct GoogleRoundSignInButton: View {
    let action: () -> Void

    var body: some View {
        GoogleSignInButton(scheme: .light, style: .icon, state: .normal, action: action)
            .scaleEffect(1.2) // 官方图标按钮原始尺寸为 40pt，缩放后正好填满 48pt 圆形入口。
            .frame(width: 48, height: 48)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color(red: 0.46, green: 0.47, blue: 0.47), lineWidth: 1))
            .contentShape(Circle())
    }
}

/// Google 授权回调集中在此处，避免登录页和账号绑定页出现两套 Token 提交流程。
final class GoogleSignInCoordinator {
    static let shared = GoogleSignInCoordinator()

    private var purpose: GoogleSignInPurpose = .login

    private init() {}

    func startLogin() {
        start(for: .login)
    }

    func startBinding() {
        start(for: .bind)
    }

    private func start(for purpose: GoogleSignInPurpose) {
        guard hasGoogleConfiguration else {
            ToastManager.shared.show(toast: Toast(message: "login.google.not_configured"))
            return
        }
        guard let presentingViewController = topViewController() else { return }

        self.purpose = purpose
        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { [weak self] result, error in
            // 用户主动取消授权不应显示错误提示。
            guard error == nil, let user = result?.user else { return }
            user.refreshTokensIfNeeded { refreshedUser, refreshError in
                guard refreshError == nil,
                      let token = refreshedUser?.idToken?.tokenString else { return }
                self?.submit(token: token)
            }
        }
    }

    private func submit(token: String) {
        let payload = GoogleIDTokenPayload(id_token: token, timezone: TimeZone.current.identifier)
        guard let body = try? JSONEncoder().encode(payload) else { return }
        let headers = ["Content-Type": "application/json"]
        let path = purpose == .login ? "/user/login/google" : "/user/account/bind_google"
        let request = APIRequest(path: path, method: .post, headers: headers, body: body, requiresAuth: purpose == .bind)

        if purpose == .login {
            NetworkService.sendRequest(with: request, decodingType: LoginResponse.self, showLoadingToast: true, showErrorToast: true) { result in
                guard case .success(let data) = result, let data else { return }
                self.finishLogin(data)
            }
        } else {
            NetworkService.sendRequest(with: request, decodingType: String.self, showLoadingToast: true, showErrorToast: true) { result in
                guard case .success(let email) = result else { return }
                DispatchQueue.main.async {
                    UserManager.shared.user.google_email = email
                    UserManager.shared.saveUserInfoToCache()
                    ToastManager.shared.show(toast: Toast(message: "user.page.bind_device.result.success"))
                }
            }
        }
    }

    private func finishLogin(_ data: LoginResponse) {
        let user = data.user
        let relation = data.relation
        let userManager = UserManager.shared
        DispatchQueue.main.async {
            userManager.friendCount = relation.friends
            userManager.followerCount = relation.follower
            userManager.followedCount = relation.followed
            userManager.user = User(from: user)
            userManager.role = data.role
            userManager.saveUserInfoToCache()
            userManager.isLoggedIn = true
            userManager.showingLogin = false
            if data.isRegister {
                userManager.showingGuide = true
            }
        }
        userManager.downloadImages(avatar_url: user.avatar_image_url, background_url: user.background_image_url)
        Task {
            await AssetManager.shared.queryCCAssets()
            await AssetManager.shared.queryCPAssets(withLoadingToast: false)
            await AssetManager.shared.queryMagicCards(withLoadingToast: false)
        }
    }

    private var hasGoogleConfiguration: Bool {
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String,
              let serverClientID = Bundle.main.object(forInfoDictionaryKey: "GIDServerClientID") as? String else {
            return false
        }
        return !clientID.isEmpty && !serverClientID.isEmpty && !clientID.contains("$(") && !serverClientID.contains("$(")
    }

    private func topViewController(from root: UIViewController? = nil) -> UIViewController? {
        let root = root ?? UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.rootViewController
        if let navigation = root as? UINavigationController {
            return topViewController(from: navigation.visibleViewController)
        }
        if let tab = root as? UITabBarController {
            return topViewController(from: tab.selectedViewController)
        }
        if let presented = root?.presentedViewController {
            return topViewController(from: presented)
        }
        return root
    }
}
