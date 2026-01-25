//
//  MagicCardPriceBackendView.swift
//  sportsx
//
//  Created by 任杰 on 2025/8/24.
//

import SwiftUI
import PhotosUI


struct MagicCardPriceBackendView: View {
    @EnvironmentObject var appState: AppState
    @StateObject var viewModel = MagicCardPriceBackendViewModel()
    
    @State private var name: String = ""
    @State private var cardID: String = ""
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
                
                Text("卡牌商店管理")
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
                    TextField("卡牌名称", text: $name)
                        .background(.gray.opacity(0.1))
                    TextField("卡牌id", text: $cardID)
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
                    viewModel.cards.removeAll()
                    viewModel.currentPage = 1
                    queryMagicCards()
                }
                .padding()
            }
            
            // 搜索结果展示，每条记录末尾添加一个"修改"按钮
            ScrollView {
                LazyVStack(spacing: 15) {
                    ForEach(viewModel.cards) { card in
                        MagicCardPriceView(viewModel: viewModel, card: card)
                            .onAppear {
                                if card == viewModel.cards.last && viewModel.hasMoreEvents {
                                    queryMagicCards()
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
            MagicCardPriceCreateView(viewModel: viewModel)
        }
        //.sheet(isPresented: $viewModel.showUpdateSheet) {
        //    MagicCardPriceUpdateView(viewModel: viewModel)
        //}
    }
    
    func queryMagicCards() {
        isLoading = true
        guard var components = URLComponents(string: "/asset/query_equip_cards_in_shop") else { return }
        components.queryItems = [
            URLQueryItem(name: "name", value: name),
            URLQueryItem(name: "card_def_id", value: cardID),
            URLQueryItem(name: "page", value: "\(viewModel.currentPage)")
        ]
        if is_on_shelves != "all" {
            components.queryItems?.append(URLQueryItem(name: "is_on_shelves", value: is_on_shelves))
        }
        guard let urlPath = components.string else { return }
        
        let request = APIRequest(path: urlPath, method: .get, isInternal: true)
        
        NetworkService.sendRequest(with: request, decodingType: MagicCardPriceInternalResponse.self, showSuccessToast: true, showErrorToast: true) { result in
            isLoading = false
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        for card in unwrappedData.cards {
                            viewModel.cards.append(MagicCardPriceCardEntry(from: card))
                        }
                    }
                    if unwrappedData.cards.count < 10 {
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

struct MagicCardPriceCreateView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: MagicCardPriceBackendViewModel
    
    @State var card_id: String = ""
    @State var ccasset_type: String = CCAssetType.coin.rawValue
    @State var price: String = ""
    @State var is_on_shelves: Bool = false
    
    let types = [CCAssetType.coin, CCAssetType.coupon, CCAssetType.voucher]
    
    var body: some View {
        VStack {
            Form {
                Section(header: Text("基本信息")) {
                    TextField("道具id", text: $card_id)
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
                        addMagicCard()
                    }
                    .disabled(card_id.isEmpty || ccasset_type.isEmpty)
                }
            }
        }
    }
    
    func addMagicCard() {
        var headers: [String: String] = [:]
        headers["Content-Type"] = "application/json"
        
        let body: [String: String] = [
            "card_def_id": card_id,
            "ccasset_type": ccasset_type,
            "price": price,
            "is_on_shelves": is_on_shelves.description
        ]
        guard let encodedBody = try? JSONEncoder().encode(body) else {
            return
        }
        
        let request = APIRequest(path: "/asset/add_equip_card_to_shop", method: .post, headers: headers, body: encodedBody, isInternal: true)
        
        NetworkService.sendRequest(with: request, decodingType: EmptyResponse.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true) { _ in }
    }
}

/*struct MagicCardPriceUpdateView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: MagicCardPriceBackendViewModel
    
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
        .onChange(of: selectedImageItem) {
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

struct MagicCardPriceView: View {
    @ObservedObject var viewModel: MagicCardPriceBackendViewModel
    let card: MagicCardPriceCardEntry
    
    
    var body: some View {
        HStack {
            Text(card.name_hans)
            Image(card.ccasset_type.iconName)
                .resizable()
                .scaledToFit()
                .frame(width: 20)
            Text("\(card.price)")
            Text("上架状态:\(card.is_on_shelves)")
            Spacer()
            Button("修改") {
                //loadSelectedEventInfo()
                //viewModel.showUpdateSheet = true
            }
        }
    }
}
