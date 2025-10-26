//
//  UserIntroEditViewModel.swift
//  sportsx
//
//  Created by 任杰 on 2025/4/25.
//

import Foundation
import SwiftUI


class UserIntroEditViewModel: ObservableObject {
    let navigationManager = NavigationManager.shared
    let userManager = UserManager.shared
    @Published var currentUser = User()
    @Published var avatarImage: UIImage?        // 用户头像
    @Published var backgroundImage: UIImage?    // 用户封面
    
    @Published var backgroundColor: Color = .defaultBackground  // 背景色
    
    init() {
        currentUser = userManager.user
        avatarImage = userManager.avatarImage
        backgroundImage = userManager.backgroundImage
        backgroundColor = userManager.backgroundColor
    }
    
    func saveMeInfo() {
        updateMe_request()
    }
    
    func updateMe_request() {
        let boundary = "Boundary-\(UUID().uuidString)"
        
        var headers: [String: String] = [:]
        headers["Content-Type"] = "multipart/form-data; boundary=\(boundary)"
        
        var body = Data()
        
        // 文字字段
        let textFields: [String: String?] = [
            "nickname": currentUser.nickname,
            "introduction": currentUser.introduction,
            "location": currentUser.location,
            "is_display_gender": currentUser.isDisplayGender.description,
            "is_display_age": currentUser.isDisplayAge.description,
            "is_display_location": currentUser.isDisplayLocation.description,
            "enable_auto_location": currentUser.enableAutoLocation.description,
            "is_display_identity": currentUser.isDisplayIdentity.description
        ]
        for (key, value) in textFields {
            if let unwrapped = value {
                body.append("--\(boundary)\r\n")
                body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
                body.append("\(unwrapped)\r\n")
            }
        }
        
        // 图片字段
        let images: [(name: String, image: UIImage?, filename: String, maxSize: Int)] = [
            ("avatar_image", avatarImage, "avatar.jpg", 100),
            ("background_image", backgroundImage, "background.jpg", 200)
        ]
        for (name, image, filename, size) in images {
            if let unwrappedImage = image, let imageData = ImageTool.compressImage(unwrappedImage, maxSizeKB: size) {
                body.append("--\(boundary)\r\n")
                body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
                body.append("Content-Type: image/jpeg\r\n\r\n")
                body.append(imageData)
                body.append("\r\n")
            }
        }
        
        body.append("--\(boundary)--\r\n")
        
        let request = APIRequest(path: "/user/update", method: .post, headers: headers, body: body, requiresAuth: true)
        
        NetworkService.sendRequest(
            with: request,
            decodingType: FetchBaseUserResponse.self,
            showLoadingToast: true,
            showErrorToast: true,
            customErrorToast: { error in
                switch error {
                case .decodeError, .noData, .unknown:
                    return Toast(message: "保存失败", duration: 2)
                default:
                    return nil
                }
            }
        ) { result in
            switch result {
            case .success(let data):
                DispatchQueue.main.async {
                    let successToast = Toast(message: "保存成功", duration: 2)
                    ToastManager.shared.show(toast: successToast)
                }
                
                if let unwrappedData = data {
                    let user = unwrappedData.user
                    DispatchQueue.main.async {
                        self.userManager.user.nickname = user.nickname
                        self.userManager.user.avatarImageURL = user.avatar_image_url
                        self.userManager.user.backgroundImageURL = user.background_image_url
                        self.userManager.user.introduction = user.introduction
                        self.userManager.user.gender = user.gender
                        self.userManager.user.birthday = user.birthday
                        self.userManager.user.location = user.location
                        self.userManager.user.identityAuthName = user.identity_auth_name
                        self.userManager.user.isRealnameAuth = (user.gender != nil && user.birthday != nil)
                        self.userManager.user.isIdentityAuth = (user.identity_auth_name != nil)
                        self.userManager.user.isDisplayGender = user.is_display_gender
                        self.userManager.user.isDisplayAge = user.is_display_age
                        self.userManager.user.isDisplayLocation = user.is_display_location
                        self.userManager.user.enableAutoLocation = user.enable_auto_location
                        self.userManager.user.isDisplayIdentity = user.is_display_identity
                        
                        self.userManager.saveUserInfoToCache()
                        
                        if self.navigationManager.path.last == .userIntroEditView {
                            self.navigationManager.removeLast()
                        }
                    }
                    self.userManager.downloadImages(avatar_url: user.avatar_image_url, background_url: user.background_image_url)
                }
            default:
                break
            }
        }
    }
}




