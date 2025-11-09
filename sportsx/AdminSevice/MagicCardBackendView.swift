//
//  MagicCardBackendView.swift
//  sportsx
//
//  Created by 任杰 on 2025/8/24.
//

import SwiftUI
import PhotosUI


struct MagicCardBackendView: View {
    @EnvironmentObject var appState: AppState
    @StateObject var viewModel = MagicCardBackendViewModel()
    
    @State private var name: String = ""
    @State private var sportType: String = "all"
    @State private var rarity: String = ""
    
    @State var isLoading: Bool = false
    let sportTypes = ["bike", "running", "all"]
    
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
                
                Text("装备卡定义管理")
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
                    Menu {
                        ForEach(sportTypes, id: \.self) { type in
                            Button(type) {
                                sportType = type
                            }
                        }
                    } label: {
                        HStack {
                            Text(sportType)
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
                        MagicCardDefView(viewModel: viewModel, card: card)
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
            MagicCardCreateView(viewModel: viewModel)
        }
        //.sheet(isPresented: $viewModel.showUpdateSheet) {
        //    CPAssetUpdateView(viewModel: viewModel)
        //}
    }
    
    func queryMagicCards() {
        isLoading = true
        guard var components = URLComponents(string: "/asset/query_equip_card_def") else { return }
        components.queryItems = [
            URLQueryItem(name: "name", value: name),
            URLQueryItem(name: "page", value: "\(viewModel.currentPage)")
        ]
        if sportType != "all" {
            components.queryItems?.append(URLQueryItem(name: "sport_type", value: sportType))
        }
        guard let urlPath = components.string else { return }
        
        let request = APIRequest(path: urlPath, method: .get, isInternal: true)
        
        NetworkService.sendRequest(with: request, decodingType: MagicCardInternalResponse.self, showSuccessToast: true, showErrorToast: true) { result in
            isLoading = false
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        for card in unwrappedData.defs {
                            viewModel.cards.append(MagicCardEntry(from: card))
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

struct MagicCardCreateView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: MagicCardBackendViewModel
    
    @State var name: String = ""
    @State var sportType: String = SportName.Bike.rawValue
    @State var description: String = ""
    @State var description1: String = ""
    @State var description2: String = ""
    @State var description3: String = ""
    @State var rarity: String = ""
    @State var typeName: String = ""
    @State var version: String = ""
    @State private var tags: String = ""
    //["team_mode", "rain_day"]
    
    @State private var effectConfig: String = ""
    /*{
      "effect_type": "pedal_boost",
      "value": 1.2,
      "condition": {"min_rpm": 50, "max_rpm": 120}
    }*/
    
    
    @State var coverImage: UIImage? = nil
    @State var showImagePicker: Bool = false
    @State var selectedImageItem: PhotosPickerItem?
    
    let sportTypes = [SportName.Bike, SportName.Running]
    
    
    var body: some View {
        VStack {
            Form {
                Section(header: Text("基本信息")) {
                    TextField("卡牌名称", text: $name)
                    Menu {
                        ForEach(sportTypes, id: \.self) { type in
                            Button(type.rawValue) {
                                sportType = type.rawValue
                            }
                        }
                    } label: {
                        HStack {
                            Text(sportType)
                                .font(.subheadline)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .cornerRadius(8)
                    }
                    TextField("卡牌描述", text: $description)
                    TextField("卡牌描述1(选填)", text: $description1)
                    TextField("卡牌描述2(选填)", text: $description2)
                    TextField("卡牌描述3(选填)", text: $description3)
                    TextField("稀有度", text: $rarity)
                    TextField("卡牌effect名称", text: $typeName)
                    TextField("version", text: $version)
                }
                Section(header: Text("过滤标签(选填)")) {
                    TextEditor(text: $tags)
                }
                Section(header: Text("effect信息")) {
                    TextEditor(text: $effectConfig)
                }
                Section(header: Text("卡牌图片")) {
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
                    Button("创建卡牌") {
                        viewModel.showCreateSheet = false
                        createMagicCard()
                    }
                    .disabled(name.isEmpty || sportType.isEmpty || description.isEmpty || typeName.isEmpty || version.isEmpty || effectConfig.isEmpty)
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
    
    func createMagicCard() {
        let boundary = "Boundary-\(UUID().uuidString)"
        
        var headers: [String: String] = [:]
        headers["Content-Type"] = "multipart/form-data; boundary=\(boundary)"
        
        var body = Data()
        
        // 文字字段
        var textFields: [String : String] = [
            "name": name,
            "sport_type": sportType,
            "rarity": rarity,
            "description": description,
            "version": version,
            "type_name": typeName,
            "effect_config": effectConfig
        ]
        if !description1.isEmpty {
            textFields["skill1_description"] = description1
        }
        if !description2.isEmpty {
            textFields["skill2_description"] = description2
        }
        if !description3.isEmpty {
            textFields["skill3_description"] = description3
        }
        if !tags.isEmpty {
            textFields["tags"] = tags
        }
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
            if let unwrappedImage = image, let imageData = ImageTool.compressImage(unwrappedImage, maxSizeKB: 200) {
                body.append("--\(boundary)\r\n")
                body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
                body.append("Content-Type: image/jpeg\r\n\r\n")
                body.append(imageData)
                body.append("\r\n")
            }
        }
        
        body.append("--\(boundary)--\r\n")
        
        let request = APIRequest(path: "/asset/create_equip_card_def", method: .post, headers: headers, body: body, isInternal: true)
        
        NetworkService.sendRequest(with: request, decodingType: EmptyResponse.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true) { _ in }
    }
}

struct MagicCardDefView: View {
    @ObservedObject var viewModel: MagicCardBackendViewModel
    let card: MagicCardEntry
    
    
    var body: some View {
        HStack(spacing: 15) {
            Text(card.name)
            Text(card.sport_type.rawValue)
            Text(card.rarity)
            Text("id")
            Image(systemName: "doc.on.doc")
                .font(.system(size: 15))
                .foregroundColor(.gray)
                .onTapGesture {
                    UIPasteboard.general.string = card.def_id
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
