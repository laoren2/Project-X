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
    @State private var announcement: String = ""
    @State private var image_url: String = ""
    @State private var web_url: String = ""
    @State private var is_displayed: Bool = false
    @State var isLoading: Bool = false
    
    @State var adImage: UIImage? = nil
    @State var showImagePicker: Bool = false
    @State var selectedImageItem: PhotosPickerItem?
    
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
                        Text("更新公告")
                        TextEditor(text: $announcement)
                            .padding()
                            .foregroundColor(.white)
                            .scrollContentBackground(.hidden)
                            .background(Color.gray)
                        Button("更新") {
                            updateAnnouncement()
                        }
                        .foregroundStyle(announcement.isEmpty ? Color.gray : Color.green)
                        .disabled(announcement.isEmpty)
                    }
                    VStack(spacing: 20) {
                        Text("管理轮播广告页")
                        if let image = adImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 150)
                                .onTapGesture {
                                    showImagePicker = true
                                }
                        } else {
                            Button("选择图片") {
                                showImagePicker = true
                            }
                        }
                        TextField("web_url", text: $web_url)
                            .background(.gray.opacity(0.1))
                        Toggle("是否显示", isOn: $is_displayed)
                        Button("添加Ad") {
                            createBannerAds()
                        }
                        Button("查询") {
                            queryBannerAds()
                        }
                        ScrollView {
                            LazyVStack(spacing: 15) {
                                ForEach(viewModel.ads) { ad in
                                    AdInfoView(ad: ad)
                                        .onAppear {
                                            if ad == viewModel.ads.last && viewModel.hasMoreAds {
                                                queryBannerAds()
                                            }
                                        }
                                }
                                if isLoading {
                                    ProgressView()
                                        .padding()
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical)
                        }
                        .background(.gray.opacity(0.1))
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBackGesture()
        .photosPicker(isPresented: $showImagePicker, selection: $selectedImageItem, matching: .images)
        .onValueChange(of: selectedImageItem) {
            Task {
                if let data = try? await selectedImageItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    adImage = uiImage
                } else {
                    adImage = nil
                }
            }
        }
    }
    
    func updateAnnouncement() {
        guard !announcement.isEmpty else { return }
        
        var headers: [String: String] = [:]
        headers["Content-Type"] = "application/json"
        
        let body: [String: String] = [
            "content": announcement
        ]
        
        guard let encodedBody = try? JSONEncoder().encode(body) else {
            return
        }
        
        let request = APIRequest(path: "/homepage/update_announcements", method: .post, headers: headers, body: encodedBody, isInternal: true)
        
        NetworkService.sendRequest(with: request, decodingType: EmptyResponse.self, showSuccessToast: true, showErrorToast: true) { _ in }
    }
    
    func createBannerAds() {
        guard adImage != nil else { return }
        
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
            ("image", adImage, "ad.jpg")
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
                urlString: ad.image_url,
                placeholder: Image("Ads"),
                errorImage: Image(systemName: "photo.badge.exclamationmark")
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
