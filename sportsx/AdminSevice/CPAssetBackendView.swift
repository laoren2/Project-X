//
//  CPAssetBackendView.swift
//  sportsx
//
//  Created by 任杰 on 2025/7/3.
//

import SwiftUI
import PhotosUI


struct CPAssetBackendView: View {
    @EnvironmentObject var appState: AppState
    @StateObject var viewModel = CPAssetBackendViewModel()
    
    @State private var name: String = ""
    @State private var type: String = ""
    
    @State var isLoading: Bool = false
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Button(action: {
                    appState.navigationManager.removeLast()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.black)
                }
                
                Spacer()
                
                Text("通用道具资产定义管理")
                    .font(.system(size: 18, weight: .bold))
                
                Spacer()
                
                // 平衡布局的空按钮
                Button(action: {}) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.clear)
                }
            }
            
            Spacer()
            
            // 搜索结构，支持筛选运动类型、赛季名、地理区域名以及赛事名
            HStack {
                VStack {
                    TextField("道具名称", text: $name)
                        .background(.gray.opacity(0.1))
                    TextField("道具类型", text: $type)
                        .background(.gray.opacity(0.1))
                }
                
                Button("查询") {
                    viewModel.assets.removeAll()
                    viewModel.currentPage = 1
                    queryCPAssets()
                }
                .padding()
            }
            
            // 搜索结果展示，每条记录末尾添加一个"修改"按钮
            ScrollView {
                LazyVStack(spacing: 15) {
                    ForEach(viewModel.assets) { asset in
                        CPAssetDefView(viewModel: viewModel, asset: asset)
                            .onAppear {
                                if asset == viewModel.assets.last && viewModel.hasMoreEvents {
                                    queryCPAssets()
                                }
                            }
                    }
                    if isLoading {
                        ProgressView()
                            .padding()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top)
            }
            .background(.gray.opacity(0.1))
            .cornerRadius(10)
            
            HStack {
                Spacer()
                Button("新建道具") {
                    viewModel.showCreateSheet = true
                }
                Spacer()
            }
            .padding()
        }
        .padding(.horizontal)
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBackGesture()
        .sheet(isPresented: $viewModel.showCreateSheet) {
            CPAssetCreateView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showUpdateSheet) {
            CPAssetUpdateView(viewModel: viewModel)
        }
    }
    
    func queryCPAssets() {
        isLoading = true
        guard var components = URLComponents(string: "/asset/query_cpasset_def") else { return }
        components.queryItems = [
            URLQueryItem(name: "name", value: name),
            URLQueryItem(name: "type", value: type),
            URLQueryItem(name: "page", value: "\(viewModel.currentPage)")
        ]
        guard let urlPath = components.string else { return }
        
        let request = APIRequest(path: urlPath, method: .get, isInternal: true)
        
        NetworkService.sendRequest(with: request, decodingType: CPAssetInternalResponse.self, showSuccessToast: true, showErrorToast: true) { result in
            isLoading = false
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        for asset in unwrappedData.defs {
                            viewModel.assets.append(CPAssetCardEntry(from: asset))
                        }
                    }
                    if unwrappedData.defs.count < 10 {
                        viewModel.hasMoreEvents = false
                    } else {
                        viewModel.hasMoreEvents = true
                        viewModel.currentPage += 1
                    }
                }
            default: break
            }
        }
    }
}

struct CPAssetCreateView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: CPAssetBackendViewModel
    
    @State var name: String = ""
    @State var type: String = ""
    @State var description: String = ""
    @State var key1: String = ""
    @State var value1: String = ""
    @State var key2: String = ""
    @State var value2: String = ""
    
    @State var coverImage: UIImage? = nil
    @State var showImagePicker: Bool = false
    @State var selectedImageItem: PhotosPickerItem?
    
    
    var body: some View {
        VStack {
            Form {
                Section(header: Text("基本信息")) {
                    TextField("道具名称", text: $name)
                    TextField("道具类型", text: $type)
                    TextField("道具描述", text: $description)
                }
                Section(header: Text("道具特有属性字段")) {
                    TextField("字段1", text: $key1)
                    TextField("值1", text: $value1)
                    TextField("字段2", text: $key2)
                    TextField("值2", text: $value2)
                }
                Section(header: Text("封面图片")) {
                    if let image = coverImage {
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
                }
                Section {
                    Button("创建道具") {
                        viewModel.showCreateSheet = false
                        createCPAsset()
                    }
                    .disabled(name.isEmpty || type.isEmpty || description.isEmpty)
                }
            }
        }
        .photosPicker(isPresented: $showImagePicker, selection: $selectedImageItem, matching: .images)
        .onValueChange(of: selectedImageItem) {
            Task {
                if let data = try? await selectedImageItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    coverImage = uiImage
                } else {
                    coverImage = nil
                }
            }
        }
    }
    
    func createCPAsset() {
        let boundary = "Boundary-\(UUID().uuidString)"
        
        var headers: [String: String] = [:]
        headers["Content-Type"] = "multipart/form-data; boundary=\(boundary)"
        
        var body = Data()
        
        let extraFields = """
        {
          "\(key1)": "\(value1)",
          "\(key2)": "\(value2)"
        }
        """
        // 文字字段
        let textFields: [String : String] = [
            "prop_type": type,
            "name": name,
            "description": description,
            "extra_fields": extraFields
        ]
        for (key, value) in textFields {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.append("\(value)\r\n")
        }
        
        // 图片字段
        let images: [(name: String, image: UIImage?, filename: String)] = [
            ("image", coverImage, "cover.jpg")
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
        
        let request = APIRequest(path: "/asset/create_cpasset_def", method: .post, headers: headers, body: body, isInternal: true)
        
        NetworkService.sendRequest(with: request, decodingType: EmptyResponse.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true) { _ in }
    }
}

struct CPAssetUpdateView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: CPAssetBackendViewModel
    
    @State var eventImage: UIImage? = nil
    @State var showImagePicker: Bool = false
    @State var selectedImageItem: PhotosPickerItem?
    
    
    var body: some View {
        VStack {
            Form {
                Section(header: Text("基本信息")) {
                    TextField("赛事名称", text: $viewModel.name)
                    TextField("描述", text: $viewModel.description)
                }
                Section(header: Text("时间")) {
                    DatePicker("开始时间", selection: $viewModel.startDate, displayedComponents: [.date])
                    DatePicker("结束时间", selection: $viewModel.endDate, displayedComponents: [.date])
                }
                Section(header: Text("封面图片")) {
                    if let image = eventImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 150)
                            .onTapGesture {
                                showImagePicker = true
                            }
                    } else {
                        ProgressView()
                    }
                }
                Section {
                    Button("修改赛事") {
                        viewModel.showUpdateSheet = false
                        updateEvent()
                    }
                }
            }
        }
        .photosPicker(isPresented: $showImagePicker, selection: $selectedImageItem, matching: .images)
        .onValueChange(of: selectedImageItem) {
            Task {
                if let data = try? await selectedImageItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    eventImage = uiImage
                } else {
                    eventImage = nil
                }
            }
        }
        .onAppear {
            NetworkService.downloadImage(from: viewModel.image_url) { image in
                DispatchQueue.main.async {
                    if let image = image {
                        eventImage = image
                    } else {
                        eventImage = UIImage(systemName: "photo.badge.exclamationmark")
                    }
                }
            }
        }
    }
    
    func updateEvent() {
        let boundary = "Boundary-\(UUID().uuidString)"
        
        var headers: [String: String] = [:]
        headers["Content-Type"] = "multipart/form-data; boundary=\(boundary)"
        
        var body = Data()
        
        // 文字字段
        let textFields: [String : String] = [
            "event_id": viewModel.selectedAssetID,
            "name": viewModel.name,
            "description": viewModel.description,
            "start_date": ISO8601DateFormatter().string(from: viewModel.startDate),
            "end_date": ISO8601DateFormatter().string(from: viewModel.endDate)
        ]
        for (key, value) in textFields {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.append("\(value)\r\n")
        }
        
        // 图片字段
        let images: [(name: String, image: UIImage?, filename: String)] = [
            ("event_image", eventImage, "background.jpg")
        ]
        for (name, image, filename) in images {
            if let unwrappedImage = image, let imageData = ImageTool.compressImage(unwrappedImage, maxSizeKB: 1000) {
                body.append("--\(boundary)\r\n")
                body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
                body.append("Content-Type: image/jpeg\r\n\r\n")
                body.append(imageData)
                body.append("\r\n")
            }
        }
        
        body.append("--\(boundary)--\r\n")
        
        let request = APIRequest(path: "/competition/bike/update_event", method: .post, headers: headers, body: body, isInternal: true)
        
        NetworkService.sendRequest(with: request, decodingType: EmptyResponse.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true) { _ in }
    }
}

struct CPAssetDefView: View {
    @ObservedObject var viewModel: CPAssetBackendViewModel
    let asset: CPAssetCardEntry
    
    
    var body: some View {
        HStack(spacing: 0) {
            Text(asset.name)
            Spacer()
            Text(asset.cpasset_type)
            Spacer()
            Text("id")
            Image(systemName: "doc.on.doc")
                .font(.system(size: 15))
                .foregroundColor(.gray)
                .onTapGesture {
                    UIPasteboard.general.string = asset.asset_id
                    let toast = Toast(message: "id已复制", duration: 2)
                    ToastManager.shared.show(toast: toast)
                }
            Spacer()
            Button("修改") {
                //loadSelectedEventInfo()
                //viewModel.showUpdateSheet = true
            }
        }
    }
    
    /*func loadSelectedEventInfo() {
        viewModel.selectedEventID = event.event_id
        viewModel.name = event.name
        viewModel.description = event.description
        viewModel.startDate = ISO8601DateFormatter().date(from: event.start_date) ?? Date()
        viewModel.endDate = ISO8601DateFormatter().date(from: event.end_date) ?? Date()
        viewModel.image_url = event.image_url
    }*/
}
