//
//  RealNameAuthView.swift
//  sportsx
//
//  Created by 任杰 on 2025/4/29.
//

import SwiftUI
import PhotosUI


struct RealNameAuthView: View {
    @EnvironmentObject var appState: AppState
    @State var cardImage: UIImage? = nil
    @State var showImagePicker: Bool = false
    @State var selectedImageItem: PhotosPickerItem?
    let userManager = UserManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                CommonIconButton(icon: "chevron.left") {
                    appState.navigationManager.removeLast()
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.secondText)
                
                Spacer()
                
                Text("user.setup.realname_auth")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.secondText)
                
                Spacer()
                
                // 平衡布局的空按钮
                Button(action: {}) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.clear)
                }
            }
            
            HStack {
                if userManager.user.isRealnameAuth {
                    Text("user.setup.realname_auth.done")
                        .font(.title3)
                        .foregroundStyle(Color.green)
                } else {
                    Text("user.setup.realname_auth.undone")
                        .font(.title3)
                        .foregroundStyle(Color.gray)
                }
                Image(systemName: "info.circle")
                    .foregroundStyle(Color.secondText)
                    .exclusiveTouchTapGesture {
                        PopupWindowManager.shared.presentPopup(
                            title: "user.setup.realname_auth",
                            bottomButtons: [
                                .confirm("action.confirm")
                            ]
                        ) {
                            JustifiedText("user.setup.realname_auth.popup", font: .systemFont(ofSize: 15), textColor: UIColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1))
                        }
                    }
                Spacer()
            }
            Text("user.setup.realname_auth.content")
                .font(.caption)
                .foregroundStyle(Color.thirdText)
                .padding(.bottom, 100)
            if let image = cardImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 150)
                    .onTapGesture {
                        showImagePicker = true
                    }
            } else {
                EmptyCardSlot(text: "user.setup.realname_auth.upload", ratio: 7/5)
                    .frame(height: 150)
                    .onTapGesture {
                        showImagePicker = true
                    }
            }
            Text("user.setup.realname_auth.content.2")
                .font(.caption)
                .foregroundStyle(Color.thirdText)
            Text(userManager.user.isRealnameAuth ? "user.setup.realname_auth.action.reauth" : "user.setup.realname_auth.action.auth")
                .padding(.vertical, 10)
                .padding(.horizontal, 25)
                .foregroundStyle(Color.secondText)
                .background(cardImage == nil ? Color.gray : Color.orange)
                .cornerRadius(10)
                .onTapGesture {
                    appliedOCR()
                }
                .disabled(cardImage == nil)
            Spacer()
        }
        .padding(.horizontal)
        .background(Color.defaultBackground)
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBackGesture()
        .photosPicker(isPresented: $showImagePicker, selection: $selectedImageItem, matching: .images)
        .onValueChange(of: selectedImageItem) {
            Task {
                if let data = try? await selectedImageItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    cardImage = uiImage
                } else {
                    cardImage = nil
                }
            }
        }
    }
    
    func appliedOCR() {
        guard cardImage != nil else { return }
        
        let boundary = "Boundary-\(UUID().uuidString)"
        var headers: [String: String] = [:]
        headers["Content-Type"] = "multipart/form-data; boundary=\(boundary)"
        var body = Data()
        // 图片字段
        let images: [(name: String, image: UIImage?, filename: String)] = [
            ("front_image", cardImage, "hk_id_card.jpg")
        ]
        for (name, image, filename) in images {
            if let unwrappedImage = image, let imageData = ImageTool.compressImage(unwrappedImage, maxSizeKB: 300) {
                body.append("--\(boundary)\r\n")
                body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
                body.append("Content-Type: image/jpeg\r\n\r\n")
                body.append(imageData)
                body.append("\r\n")
            }
        }
        
        body.append("--\(boundary)--\r\n")
        
        let request = APIRequest(path: "/user/realname_hk", method: .post, headers: headers, body: body, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: EmptyResponse.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true) { result in
            switch result {
            case .success:
                Task {
                    await UserManager.shared.fetchMeInfo()
                }
            default: break
            }
        }
    }
}
