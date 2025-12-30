//
//  CPAssetPriceBackendView.swift
//  sportsx
//
//  Created by 任杰 on 2025/7/7.
//

import SwiftUI
import PhotosUI


struct CPAssetPriceBackendView: View {
    @EnvironmentObject var appState: AppState
    @StateObject var viewModel = CPAssetPriceBackendViewModel()
    
    @State private var name: String = ""
    @State private var assetID: String = ""
    @State private var is_on_shelves: String = "all"
    
    @State var isLoading: Bool = false
    let selectInShelves: [String] = ["all", "true", "false"]
    
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
                
                Text("通用道具资产商店管理")
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
                    TextField("道具id", text: $assetID)
                        .background(.gray.opacity(0.1))
                    Menu {
                        ForEach(selectInShelves, id: \.self) { item in
                            Button(item) {
                                is_on_shelves = item
                            }
                        }
                    } label: {
                        HStack {
                            Text(is_on_shelves)
                                .font(.subheadline)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .cornerRadius(8)
                    }
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
                        CPAssetPriceView(viewModel: viewModel, asset: asset)
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
            CPAssetPriceCreateView(viewModel: viewModel)
        }
        //.sheet(isPresented: $viewModel.showUpdateSheet) {
        //    CPAssetPriceUpdateView(viewModel: viewModel)
        //}
    }
    
    func queryCPAssets() {
        isLoading = true
        guard var components = URLComponents(string: "/asset/query_cpassets_in_shop") else { return }
        components.queryItems = [
            URLQueryItem(name: "name", value: name),
            URLQueryItem(name: "asset_id", value: assetID),
            URLQueryItem(name: "page", value: "\(viewModel.currentPage)")
        ]
        if is_on_shelves != "all" {
            components.queryItems?.append(URLQueryItem(name: "is_on_shelves", value: is_on_shelves))
        }
        guard let urlPath = components.string else { return }
        
        let request = APIRequest(path: urlPath, method: .get, isInternal: true)
        
        NetworkService.sendRequest(with: request, decodingType: CPAssetPriceInternalResponse.self, showSuccessToast: true, showErrorToast: true) { result in
            isLoading = false
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        for asset in unwrappedData.assets {
                            viewModel.assets.append(CPAssetPriceCardEntry(from: asset))
                        }
                    }
                    if unwrappedData.assets.count < 10 {
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

struct CPAssetPriceCreateView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: CPAssetPriceBackendViewModel
    
    @State var asset_id: String = ""
    @State var ccasset_type: String = CCAssetType.coin.rawValue
    @State var price: String = ""
    @State var is_on_shelves: Bool = false
    
    let types = [CCAssetType.coin, CCAssetType.coupon, CCAssetType.voucher]
    
    var body: some View {
        VStack {
            Form {
                Section(header: Text("基本信息")) {
                    TextField("道具id", text: $asset_id)
                    Menu {
                        ForEach(types, id: \.self) { type in
                            Button(type.rawValue) {
                                ccasset_type = type.rawValue
                            }
                        }
                    } label: {
                        HStack {
                            Text(ccasset_type)
                                .font(.subheadline)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .cornerRadius(8)
                    }
                    TextField("价格", text: $price)
                        .keyboardType(.numberPad)
                    Toggle("是否上架", isOn: $is_on_shelves)
                        .font(.system(size: 16))
                }
                Section {
                    Button("添加道具") {
                        viewModel.showCreateSheet = false
                        addCPAsset()
                    }
                    .disabled(asset_id.isEmpty || ccasset_type.isEmpty)
                }
            }
        }
    }
    
    func addCPAsset() {
        var headers: [String: String] = [:]
        headers["Content-Type"] = "application/json"
        
        let body: [String: String] = [
            "asset_id": asset_id,
            "ccasset_type": ccasset_type,
            "price": price,
            "is_on_shelves": is_on_shelves.description
        ]
        guard let encodedBody = try? JSONEncoder().encode(body) else {
            return
        }
        
        let request = APIRequest(path: "/asset/add_cpasset_to_shop", method: .post, headers: headers, body: encodedBody, isInternal: true)
        
        NetworkService.sendRequest(with: request, decodingType: EmptyResponse.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true) { _ in }
    }
}

/*struct CPAssetPriceUpdateView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: CPAssetPriceBackendViewModel
    
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
}*/

struct CPAssetPriceView: View {
    @ObservedObject var viewModel: CPAssetPriceBackendViewModel
    let asset: CPAssetPriceCardEntry
    
    
    var body: some View {
        HStack {
            Text(asset.name)
            Image(asset.ccasset_type.iconName)
                .resizable()
                .scaledToFit()
                .frame(width: 15)
            Text("\(asset.price)")
            Text("上架状态:\(asset.is_on_shelves)")
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
