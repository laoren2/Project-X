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
    
    @State var name_en: String = ""
    @State var name_hans: String = ""
    @State var name_hant: String = ""
    @State var type: String = ""
    @State var description_en: String = ""
    @State var description_hans: String = ""
    @State var description_hant: String = ""
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
                    TextField("道具名称hans", text: $name_hans)
                    TextField("道具名称hant", text: $name_hant)
                    TextField("道具名称en", text: $name_en)
                    TextField("道具类型", text: $type)
                    TextField("道具描述hans", text: $description_hans)
                    TextField("道具描述hant", text: $description_hant)
                    TextField("道具描述en", text: $description_en)
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
                    .disabled(name_hant.isEmpty || type.isEmpty || description_hant.isEmpty)
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
        
        var name_i18n: [String: String] = [:]
        if !name_hans.isEmpty { name_i18n["zh-Hans"] = name_hans }
        if !name_hant.isEmpty { name_i18n["zh-Hant"] = name_hant }
        if !name_en.isEmpty { name_i18n["en"] = name_en }

        var des_i18n: [String: String] = [:]
        if !description_hans.isEmpty { des_i18n["zh-Hans"] = description_hans }
        if !description_hant.isEmpty { des_i18n["zh-Hant"] = description_hant }
        if !description_en.isEmpty { des_i18n["en"] = description_en }
        
        // 文字字段
        var textFields: [String : String] = [
            "prop_type": type,
            "extra_fields": extraFields
        ]
        
        if let nameJSON = JSONHelper.toJSONString(name_i18n) {
            textFields["name"] = nameJSON
        }
        if let desJSON = JSONHelper.toJSONString(des_i18n) {
            textFields["description"] = desJSON
        }
        
        for (key, value) in textFields {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.append("\(value)\r\n")
        }
        
        // 图片字段
        let images: [(name: String, image: UIImage?, filename: String)] = [
            ("image", coverImage, "cover.png")
        ]
        for (name, image, filename) in images {
            if let unwrappedImage = image, let imageData = ImageTool.compressPNGImage(unwrappedImage) {
                body.append("--\(boundary)\r\n")
                body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
                body.append("Content-Type: image/png\r\n\r\n")
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
    
    @State var assetImage: UIImage? = nil
    @State var showImagePicker: Bool = false
    @State var selectedImageItem: PhotosPickerItem?
    
    
    var body: some View {
        VStack {
            Form {
                Section(header: Text("道具基本信息")) {
                    HStack {
                        Text("道具名称hans")
                        TextField("赛事名称hans", text: $viewModel.name_hans)
                    }
                    HStack {
                        Text("道具名称hant")
                        TextField("赛事名称hant", text: $viewModel.name_hant)
                    }
                    HStack {
                        Text("道具名称en")
                        TextField("赛事名称en", text: $viewModel.name_en)
                    }
                    HStack {
                        Text("道具描述hans")
                        TextField("描述hans", text: $viewModel.description_hans)
                    }
                    HStack {
                        Text("道具描述hant")
                        TextField("描述hant", text: $viewModel.description_hant)
                    }
                    HStack {
                        Text("道具描述en")
                        TextField("描述en", text: $viewModel.description_en)
                    }
                }
                Section(header: Text("封面图片")) {
                    if let image = assetImage {
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
                    Button("修改道具") {
                        viewModel.showUpdateSheet = false
                        updateCPAsset()
                    }
                }
            }
        }
        .photosPicker(isPresented: $showImagePicker, selection: $selectedImageItem, matching: .images)
        .onValueChange(of: selectedImageItem) {
            Task {
                if let data = try? await selectedImageItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    assetImage = uiImage
                } else {
                    assetImage = nil
                }
            }
        }
        .onAppear {
            NetworkService.downloadImage(from: viewModel.image_url) { image in
                DispatchQueue.main.async {
                    if let image = image {
                        assetImage = image
                    } else {
                        assetImage = UIImage(systemName: "photo.badge.exclamationmark")
                    }
                }
            }
        }
    }
    
    func updateCPAsset() {
        let boundary = "Boundary-\(UUID().uuidString)"
        
        var headers: [String: String] = [:]
        headers["Content-Type"] = "multipart/form-data; boundary=\(boundary)"
        
        var body = Data()
        
        var name_i18n: [String: String] = [:]
        if !viewModel.name_hans.isEmpty { name_i18n["zh-Hans"] = viewModel.name_hans }
        if !viewModel.name_hant.isEmpty { name_i18n["zh-Hant"] = viewModel.name_hant }
        if !viewModel.name_en.isEmpty { name_i18n["en"] = viewModel.name_en }

        var des_i18n: [String: String] = [:]
        if !viewModel.description_hans.isEmpty { des_i18n["zh-Hans"] = viewModel.description_hans }
        if !viewModel.description_hant.isEmpty { des_i18n["zh-Hant"] = viewModel.description_hant }
        if !viewModel.description_en.isEmpty { des_i18n["en"] = viewModel.description_en }
        
        // 文字字段
        var textFields: [String : String] = [
            "asset_id": viewModel.selectedAssetID
        ]
        
        if let nameJSON = JSONHelper.toJSONString(name_i18n) {
            textFields["name"] = nameJSON
        }
        if let desJSON = JSONHelper.toJSONString(des_i18n) {
            textFields["description"] = desJSON
        }
        
        for (key, value) in textFields {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.append("\(value)\r\n")
        }
        
        // 图片字段
        let images: [(name: String, image: UIImage?, filename: String)] = [
            ("image", assetImage, "cover.png")
        ]
        for (name, image, filename) in images {
            if let unwrappedImage = image, let imageData = ImageTool.compressPNGImage(unwrappedImage) {
                body.append("--\(boundary)\r\n")
                body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
                body.append("Content-Type: image/png\r\n\r\n")
                body.append(imageData)
                body.append("\r\n")
            }
        }
        
        body.append("--\(boundary)--\r\n")
        
        let request = APIRequest(path: "/asset/update_cpasset_def", method: .post, headers: headers, body: body, isInternal: true)
        
        NetworkService.sendRequest(with: request, decodingType: EmptyResponse.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true) { _ in }
    }
}

struct CPAssetDefView: View {
    @ObservedObject var viewModel: CPAssetBackendViewModel
    let asset: CPAssetCardEntry
    
    
    var body: some View {
        HStack(spacing: 0) {
            Text(asset.name_hans)
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
                loadSelectedEventInfo()
                viewModel.showUpdateSheet = true
            }
        }
    }
    
    func loadSelectedEventInfo() {
        viewModel.selectedAssetID = asset.asset_id
        viewModel.name_en = asset.name_en
        viewModel.name_hans = asset.name_hans
        viewModel.name_hant = asset.name_hant
        viewModel.description_en = asset.description_en
        viewModel.description_hans = asset.description_hans
        viewModel.description_hant = asset.description_hant
        viewModel.image_url = asset.image_url
    }
}
