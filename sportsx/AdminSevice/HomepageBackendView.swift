//
//  HomepageBackendView.swift
//  sportsx
//
//  Created by 任杰 on 2025/12/15.
//

import SwiftUI
import PhotosUI


struct HomepageBackendView: View {
    @ObservedObject var navigationManager = NavigationManager.shared
    @StateObject var viewModel = HomepageBackendViewModel()
    @State private var announcement_en: String = ""
    @State private var announcement_hans: String = ""
    @State private var announcement_hant: String = ""
    @State private var image_url: String = ""
    @State private var web_url: String = ""
    @State private var is_displayed: Bool = false
    @State var isLoading: Bool = false
    
    @State var adImage_hans: UIImage? = nil
    @State var showImagePicker_hans: Bool = false
    @State var selectedImageItem_hans: PhotosPickerItem?
    @State var adImage_hant: UIImage? = nil
    @State var showImagePicker_hant: Bool = false
    @State var selectedImageItem_hant: PhotosPickerItem?
    @State var adImage_en: UIImage? = nil
    @State var showImagePicker_en: Bool = false
    @State var selectedImageItem_en: PhotosPickerItem?
    
    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    navigationManager.removeLast()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.black)
                }
                
                Spacer()
                
                Text("首页管理")
                    .font(.system(size: 18, weight: .bold))
                
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
                VStack(spacing: 50) {
                    VStack {
                        Text("更新公告hans")
                        TextEditor(text: $announcement_hans)
                            .frame(minHeight: 100)
                            .padding()
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3))
                            )
                        Text("更新公告hant")
                        TextEditor(text: $announcement_hant)
                            .frame(minHeight: 100)
                            .padding()
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3))
                            )
                        Text("更新公告en")
                        TextEditor(text: $announcement_en)
                            .frame(minHeight: 100)
                            .padding()
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3))
                            )
                        Button("更新") {
                            updateAnnouncement()
                        }
                        .foregroundStyle((announcement_hans.isEmpty || announcement_hant.isEmpty || announcement_en.isEmpty) ? Color.gray : Color.green)
                        .disabled(announcement_hans.isEmpty || announcement_hant.isEmpty || announcement_en.isEmpty)
                    }
                    VStack(spacing: 20) {
                        Text("管理轮播广告页")
                        GroupBox("图片 hans") {
                            imagePickerView(image: adImage_hans) {
                                showImagePicker_hans = true
                            }
                        }
                        
                        GroupBox("图片 hant") {
                            imagePickerView(image: adImage_hant) {
                                showImagePicker_hant = true
                            }
                        }
                        
                        GroupBox("图片 en") {
                            imagePickerView(image: adImage_en) {
                                showImagePicker_en = true
                            }
                        }
                        Section {
                            TextField("web_url", text: $web_url)
                                .background(.gray.opacity(0.1))
                        }
                        Section {
                            Toggle("是否显示", isOn: $is_displayed)
                        }
                        Section {
                            Button("添加Ad") {
                                createBannerAds()
                            }
                            .disabled(adImage_en == nil || adImage_hans == nil || adImage_hant == nil)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBackGesture()
        .photosPicker(isPresented: $showImagePicker_hans, selection: $selectedImageItem_hans, matching: .images)
        .photosPicker(isPresented: $showImagePicker_hant, selection: $selectedImageItem_hant, matching: .images)
        .photosPicker(isPresented: $showImagePicker_en, selection: $selectedImageItem_en, matching: .images)
        .onValueChange(of: selectedImageItem_hans) {
            Task {
                if let data = try? await selectedImageItem_hans?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    adImage_hans = uiImage
                } else {
                    adImage_hans = nil
                }
            }
        }
        .onValueChange(of: selectedImageItem_hant) {
            Task {
                if let data = try? await selectedImageItem_hant?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    adImage_hant = uiImage
                } else {
                    adImage_hant = nil
                }
            }
        }
        .onValueChange(of: selectedImageItem_en) {
            Task {
                if let data = try? await selectedImageItem_en?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    adImage_en = uiImage
                } else {
                    adImage_en = nil
                }
            }
        }
    }
    
    @ViewBuilder
    func imagePickerView(
        image: UIImage?,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                    .background(Color.gray.opacity(0.05))
                    .frame(height: 140)

                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 120)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 28))
                            .foregroundColor(.gray)
                        Text("点击选择图片")
                            .foregroundColor(.gray)
                            .font(.system(size: 14))
                    }
                }
            }
        }
    }
    
    func updateAnnouncement() {
        var headers: [String: String] = [:]
        headers["Content-Type"] = "application/json"
        
        var announcement_i18n: [String: String] = [:]
        if !announcement_hans.isEmpty { announcement_i18n["zh-Hans"] = announcement_hans }
        if !announcement_hant.isEmpty { announcement_i18n["zh-Hant"] = announcement_hant }
        if !announcement_en.isEmpty { announcement_i18n["en"] = announcement_en }
        
        let body: [String: Any] = [
            "content": announcement_i18n
        ]
        guard JSONSerialization.isValidJSONObject(body), let encodedBody = try? JSONSerialization.data(withJSONObject: body) else { return }
        
        let request = APIRequest(path: "/homepage/update_announcements", method: .post, headers: headers, body: encodedBody, isInternal: true)
        
        NetworkService.sendRequest(with: request, decodingType: EmptyResponse.self, showSuccessToast: true, showErrorToast: true) { _ in }
    }
    
    func createBannerAds() {
        let boundary = "Boundary-\(UUID().uuidString)"
        
        var headers: [String: String] = [:]
        headers["Content-Type"] = "multipart/form-data; boundary=\(boundary)"
        
        var body = Data()
        
        // 文字字段
        var textFields: [String : String] = [
            "is_displayed": "\(is_displayed)"
        ]
        
        if !web_url.isEmpty {
            textFields["web_url"] = web_url
        }
        
        for (key, value) in textFields {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.append("\(value)\r\n")
        }
        
        // 图片字段
        let images: [(name: String, image: UIImage?, filename: String)] = [
            ("image_hans", adImage_hans, "ad_hans.jpg"),
            ("image_hant", adImage_hant, "ad_hant.jpg"),
            ("image_en", adImage_en, "ad_en.jpg")
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
        
        let request = APIRequest(path: "/homepage/create_banner_ad", method: .post, headers: headers, body: body, isInternal: true)
        
        NetworkService.sendRequest(with: request, decodingType: EmptyResponse.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true) { _ in }
    }
    
    func queryBannerAds() {
        isLoading = true
        guard var components = URLComponents(string: "/homepage/query_banner_ads") else { return }
        components.queryItems = [
            URLQueryItem(name: "page", value: "\(viewModel.currentPage)")
        ]
        guard let urlPath = components.string else { return }
        
        let request = APIRequest(path: urlPath, method: .get, isInternal: true)
        
        NetworkService.sendRequest(with: request, decodingType: AdInfoInternalResponse.self, showSuccessToast: true, showErrorToast: true) { result in
            isLoading = false
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        for ad in unwrappedData.ads {
                            viewModel.ads.append(AdCardInternalEntry(from: ad))
                        }
                    }
                    if unwrappedData.ads.count < 10 {
                        viewModel.hasMoreAds = false
                    } else {
                        viewModel.hasMoreAds = true
                        viewModel.currentPage += 1
                    }
                }
            default: break
            }
        }
    }
}

struct AdInfoView: View {
    let ad: AdCardInternalEntry
    
    var body: some View {
        HStack {
            CachedAsyncImage(
                urlString: ad.image_url
            )
            .aspectRatio(contentMode: .fit)
            .frame(height: 30)
            .clipped()
            Text("web_url:")
            Spacer()
            Text(ad.is_displayed ? "显示中" : "未显示")
                .onTapGesture {
                    updateAd()
                }
        }
    }
    
    func updateAd() {
        
    }
}
