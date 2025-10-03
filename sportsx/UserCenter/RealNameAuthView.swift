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
    @State var trackImage: UIImage? = nil
    @State var showImagePicker: Bool = false
    @State var selectedImageItem: PhotosPickerItem?
    
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                CommonIconButton(icon: "chevron.left") {
                    appState.navigationManager.removeLast()
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.secondText)
                
                Spacer()
                
                Text("实名认证")
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
            .padding(.horizontal)
            
            Spacer()
            if let image = trackImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 150)
                    .onTapGesture {
                        showImagePicker = true
                    }
            } else {
                Text("选择图片")
                    .foregroundStyle(.white)
                    .onTapGesture {
                        showImagePicker = true
                    }
            }
            Text("OCR")
                .foregroundStyle(.white)
                .onTapGesture {
                    appliedOCR()
                }
            Spacer()
        }
        .background(Color.defaultBackground)
        .toolbar(.hidden, for: .navigationBar)
        .enableBackGesture(true)
        .photosPicker(isPresented: $showImagePicker, selection: $selectedImageItem, matching: .images)
        .onValueChange(of: selectedImageItem) {
            Task {
                if let data = try? await selectedImageItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    trackImage = uiImage
                } else {
                    trackImage = nil
                }
            }
        }
    }
    
    func appliedOCR() {
        let boundary = "Boundary-\(UUID().uuidString)"
        
        var headers: [String: String] = [:]
        headers["Content-Type"] = "multipart/form-data; boundary=\(boundary)"
        
        var body = Data()
        
        // 图片字段
        let images: [(name: String, image: UIImage?, filename: String)] = [
            ("front_image", trackImage, "hk_id_card.jpg")
        ]
        for (name, image, filename) in images {
            if let unwrappedImage = image, let imageData = ImageTool.compressImage(unwrappedImage, maxSizeKB: 500) {
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
