//
//  MagicCardBackendView.swift
//  sportsx
//
//  Created by 任杰 on 2025/8/24.
//
#if DEBUG
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
                .padding(.vertical)
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
        .lightPage()
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBackGesture()
        .sheet(isPresented: $viewModel.showCreateSheet) {
            MagicCardCreateView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showUpdateSheet) {
            MagicCardUpdateView(viewModel: viewModel)
        }
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
    
    @State var name_en: String = ""
    @State var name_hans: String = ""
    @State var name_hant: String = ""
    @State var name_ko: String = ""
    @State var name_ja: String = ""
    
    @State var sportType: String = SportName.Bike.rawValue
    
    @State var description_en: String = ""
    @State var description_hans: String = ""
    @State var description_hant: String = ""
    @State var description_ko: String = ""
    @State var description_ja: String = ""
    
    @State var description1_en: String = ""
    @State var description1_hans: String = ""
    @State var description1_hant: String = ""
    @State var description1_ko: String = ""
    @State var description1_ja: String = ""
    
    @State var description2_en: String = ""
    @State var description2_hans: String = ""
    @State var description2_hant: String = ""
    @State var description2_ko: String = ""
    @State var description2_ja: String = ""
    
    @State var description3_en: String = ""
    @State var description3_hans: String = ""
    @State var description3_hant: String = ""
    @State var description3_ko: String = ""
    @State var description3_ja: String = ""
    
    @State var defID: String = "equipcard_"
    @State var rarity: String = ""
    //@State var typeName: String = ""
    @State var version: String = ""
    @State private var tags: String = ""
    //["team_mode", "rain_day"]
    
    @State private var effectConfig: String = ""
    
    
    @State var coverImage: UIImage? = nil
    @State var showImagePicker: Bool = false
    @State var selectedImageItem: PhotosPickerItem?
    
    let sportTypes = [SportName.Bike, SportName.Running]
    
    
    var body: some View {
        VStack {
            Form {
                Section(header: Text("基本信息")) {
                    TextField("卡牌名称hans", text: $name_hans)
                    TextField("卡牌名称hant", text: $name_hant)
                    TextField("卡牌名称en", text: $name_en)
                    TextField("卡牌名称ko", text: $name_ko)
                    TextField("卡牌名称ja", text: $name_ja)
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
                    TextField("卡牌描述hans", text: $description_hans)
                    TextField("卡牌描述hant", text: $description_hant)
                    TextField("卡牌描述en", text: $description_en)
                    TextField("卡牌描述ko", text: $description_ko)
                    TextField("卡牌描述ja", text: $description_ja)
                    
                    TextField("技能1描述hans(选填)", text: $description1_hans)
                    TextField("技能1描述hant(选填)", text: $description1_hant)
                    TextField("技能1描述en(选填)", text: $description1_en)
                    TextField("技能1描述ko(选填)", text: $description1_ko)
                    TextField("技能1描述ja(选填)", text: $description1_ja)
                    
                    TextField("技能2描述hans(选填)", text: $description2_hans)
                    TextField("技能2描述hant(选填)", text: $description2_hant)
                    TextField("技能2描述en(选填)", text: $description2_en)
                    TextField("技能2描述ko(选填)", text: $description2_ko)
                    TextField("技能2描述ja(选填)", text: $description2_ja)
                    
                    TextField("技能3描述hans(选填)", text: $description3_hans)
                    TextField("技能3描述hant(选填)", text: $description3_hant)
                    TextField("技能3描述en(选填)", text: $description3_en)
                    TextField("技能3描述ko(选填)", text: $description3_ko)
                    TextField("技能3描述ja(选填)", text: $description3_ja)
                    
                    TextField("def_id", text: $defID)
                    TextField("稀有度", text: $rarity)
                    //TextField("卡牌effect名称", text: $typeName)
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
                    .disabled(name_hant.isEmpty || sportType.isEmpty || description_hant.isEmpty || version.isEmpty || effectConfig.isEmpty)
                }
            }
        }
        .photosPicker(isPresented: $showImagePicker, selection: $selectedImageItem, matching: .images)
        .onValueChange(of: selectedImageItem) { _, newState in
            Task {
                if let data = try? await newState?.loadTransferable(type: Data.self),
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
        
        var name_i18n: [String: String] = [:]
        if !name_hans.isEmpty { name_i18n["zh-Hans"] = name_hans }
        if !name_hant.isEmpty { name_i18n["zh-Hant"] = name_hant }
        if !name_en.isEmpty { name_i18n["en"] = name_en }
        if !name_ko.isEmpty { name_i18n["ko"] = name_ko }
        if !name_ja.isEmpty { name_i18n["ja"] = name_ja }

        var des_i18n: [String: String] = [:]
        if !description_hans.isEmpty { des_i18n["zh-Hans"] = description_hans }
        if !description_hant.isEmpty { des_i18n["zh-Hant"] = description_hant }
        if !description_en.isEmpty { des_i18n["en"] = description_en }
        if !description_ko.isEmpty { des_i18n["ko"] = description_ko }
        if !description_ja.isEmpty { des_i18n["ja"] = description_ja }
        
        var des1_i18n: [String: String] = [:]
        if !description1_hans.isEmpty { des1_i18n["zh-Hans"] = description1_hans }
        if !description1_hant.isEmpty { des1_i18n["zh-Hant"] = description1_hant }
        if !description1_en.isEmpty { des1_i18n["en"] = description1_en }
        if !description1_ko.isEmpty { des1_i18n["ko"] = description1_ko }
        if !description1_ja.isEmpty { des1_i18n["ja"] = description1_ja }
        
        var des2_i18n: [String: String] = [:]
        if !description2_hans.isEmpty { des2_i18n["zh-Hans"] = description2_hans }
        if !description2_hant.isEmpty { des2_i18n["zh-Hant"] = description2_hant }
        if !description2_en.isEmpty { des2_i18n["en"] = description2_en }
        if !description2_ko.isEmpty { des2_i18n["ko"] = description2_ko }
        if !description2_ja.isEmpty { des2_i18n["ja"] = description2_ja }
        
        var des3_i18n: [String: String] = [:]
        if !description3_hans.isEmpty { des3_i18n["zh-Hans"] = description3_hans }
        if !description3_hant.isEmpty { des3_i18n["zh-Hant"] = description3_hant }
        if !description3_en.isEmpty { des3_i18n["en"] = description3_en }
        if !description3_ko.isEmpty { des3_i18n["ko"] = description3_ko }
        if !description3_ja.isEmpty { des3_i18n["ja"] = description3_ja }
        
        // 文字字段
        var textFields: [String : String] = [
            "def_id": defID,
            "sport_type": sportType,
            "rarity": rarity,
            "version": version,
            "effect_config": effectConfig
        ]
        
        if let nameJSON = JSONHelper.toJSONString(name_i18n) {
            textFields["name"] = nameJSON
        }
        if let desJSON = JSONHelper.toJSONString(des_i18n) {
            textFields["description"] = desJSON
        }
        if let des1JSON = JSONHelper.toJSONString(des1_i18n) {
            textFields["skill1_description"] = des1JSON
        }
        if let des2JSON = JSONHelper.toJSONString(des2_i18n) {
            textFields["skill2_description"] = des2JSON
        }
        if let des3JSON = JSONHelper.toJSONString(des3_i18n) {
            textFields["skill3_description"] = des3JSON
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

struct MagicCardUpdateView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: MagicCardBackendViewModel
    
    @State var cardImage: UIImage? = nil
    @State var showImagePicker: Bool = false
    @State var selectedImageItem: PhotosPickerItem?
    
    
    var body: some View {
        VStack {
            Form {
                Section(header: Text("卡牌基本信息")) {
                    HStack {
                        Text("卡牌支持最低客户端版本")
                        TextField("version", text: $viewModel.version)
                    }
                    HStack {
                        Text("卡牌名称hans")
                        TextField("赛事名称hans", text: $viewModel.name_hans)
                    }
                    HStack {
                        Text("卡牌名称hant")
                        TextField("赛事名称hant", text: $viewModel.name_hant)
                    }
                    HStack {
                        Text("卡牌名称en")
                        TextField("赛事名称en", text: $viewModel.name_en)
                    }
                    HStack {
                        Text("卡牌名称ko")
                        TextField("赛事名称ko", text: $viewModel.name_ko)
                    }
                    HStack {
                        Text("卡牌名称ja")
                        TextField("赛事名称ja", text: $viewModel.name_ja)
                    }
                    HStack {
                        Text("卡牌描述hans")
                        TextField("描述hans", text: $viewModel.description_hans)
                    }
                    HStack {
                        Text("卡牌描述hant")
                        TextField("描述hant", text: $viewModel.description_hant)
                    }
                    HStack {
                        Text("卡牌描述en")
                        TextField("描述en", text: $viewModel.description_en)
                    }
                    HStack {
                        Text("卡牌描述ko")
                        TextField("描述ko", text: $viewModel.description_ko)
                    }
                    HStack {
                        Text("卡牌描述ja")
                        TextField("描述ja", text: $viewModel.description_ja)
                    }
                    HStack {
                        Text("卡牌技能一描述hans")
                        TextField("描述hans", text: $viewModel.skill1_description_hans)
                    }
                    HStack {
                        Text("卡牌技能一描述hant")
                        TextField("描述hant", text: $viewModel.skill1_description_hant)
                    }
                    HStack {
                        Text("卡牌技能一描述en")
                        TextField("描述en", text: $viewModel.skill1_description_en)
                    }
                    HStack {
                        Text("卡牌技能一描述ko")
                        TextField("描述ko", text: $viewModel.skill1_description_ko)
                    }
                    HStack {
                        Text("卡牌技能一描述ja")
                        TextField("描述ja", text: $viewModel.skill1_description_ja)
                    }
                    HStack {
                        Text("卡牌技能二描述hans")
                        TextField("描述hans", text: $viewModel.skill2_description_hans)
                    }
                    HStack {
                        Text("卡牌技能二描述hant")
                        TextField("描述hant", text: $viewModel.skill2_description_hant)
                    }
                    HStack {
                        Text("卡牌技能二描述en")
                        TextField("描述en", text: $viewModel.skill2_description_en)
                    }
                    HStack {
                        Text("卡牌技能二描述ko")
                        TextField("描述ko", text: $viewModel.skill2_description_ko)
                    }
                    HStack {
                        Text("卡牌技能二描述ja")
                        TextField("描述ja", text: $viewModel.skill2_description_ja)
                    }
                    HStack {
                        Text("卡牌技能三描述hans")
                        TextField("描述hans", text: $viewModel.skill3_description_hans)
                    }
                    HStack {
                        Text("卡牌技能三描述hant")
                        TextField("描述hant", text: $viewModel.skill3_description_hant)
                    }
                    HStack {
                        Text("卡牌技能三描述en")
                        TextField("描述en", text: $viewModel.skill3_description_en)
                    }
                    HStack {
                        Text("卡牌技能三描述ko")
                        TextField("描述ko", text: $viewModel.skill3_description_ko)
                    }
                    HStack {
                        Text("卡牌技能三描述ja")
                        TextField("描述ja", text: $viewModel.skill3_description_ja)
                    }
                }
                Section(header: Text("封面图片")) {
                    if let image = cardImage {
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
        .onValueChange(of: selectedImageItem) { _, newState in
            Task {
                if let data = try? await newState?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    cardImage = uiImage
                } else {
                    cardImage = nil
                }
            }
        }
        .onAppear {
            NetworkService.downloadImage(from: viewModel.image_url) { image in
                DispatchQueue.main.async {
                    if let image = image {
                        cardImage = image
                    } else {
                        cardImage = UIImage(systemName: "photo.badge.exclamationmark")
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
        if !viewModel.name_ko.isEmpty { name_i18n["ko"] = viewModel.name_ko }
        if !viewModel.name_ja.isEmpty { name_i18n["ja"] = viewModel.name_ja }

        var des_i18n: [String: String] = [:]
        if !viewModel.description_hans.isEmpty { des_i18n["zh-Hans"] = viewModel.description_hans }
        if !viewModel.description_hant.isEmpty { des_i18n["zh-Hant"] = viewModel.description_hant }
        if !viewModel.description_en.isEmpty { des_i18n["en"] = viewModel.description_en }
        if !viewModel.description_ko.isEmpty { des_i18n["ko"] = viewModel.description_ko }
        if !viewModel.description_ja.isEmpty { des_i18n["ja"] = viewModel.description_ja }
        
        var des1_i18n: [String: String] = [:]
        if !viewModel.skill1_description_hans.isEmpty { des1_i18n["zh-Hans"] = viewModel.skill1_description_hans }
        if !viewModel.skill1_description_hant.isEmpty { des1_i18n["zh-Hant"] = viewModel.skill1_description_hant }
        if !viewModel.skill1_description_en.isEmpty { des1_i18n["en"] = viewModel.skill1_description_en }
        if !viewModel.skill1_description_ko.isEmpty { des1_i18n["ko"] = viewModel.skill1_description_ko }
        if !viewModel.skill1_description_ja.isEmpty { des1_i18n["ja"] = viewModel.skill1_description_ja }
        
        var des2_i18n: [String: String] = [:]
        if !viewModel.skill2_description_hans.isEmpty { des2_i18n["zh-Hans"] = viewModel.skill2_description_hans }
        if !viewModel.skill2_description_hant.isEmpty { des2_i18n["zh-Hant"] = viewModel.skill2_description_hant }
        if !viewModel.skill2_description_en.isEmpty { des2_i18n["en"] = viewModel.skill2_description_en }
        if !viewModel.skill2_description_ko.isEmpty { des2_i18n["ko"] = viewModel.skill2_description_ko }
        if !viewModel.skill2_description_ja.isEmpty { des2_i18n["ja"] = viewModel.skill2_description_ja }
        
        var des3_i18n: [String: String] = [:]
        if !viewModel.skill3_description_hans.isEmpty { des3_i18n["zh-Hans"] = viewModel.skill3_description_hans }
        if !viewModel.skill3_description_hant.isEmpty { des3_i18n["zh-Hant"] = viewModel.skill3_description_hant }
        if !viewModel.skill3_description_en.isEmpty { des3_i18n["en"] = viewModel.skill3_description_en }
        if !viewModel.skill3_description_ko.isEmpty { des3_i18n["ko"] = viewModel.skill3_description_ko }
        if !viewModel.skill3_description_ja.isEmpty { des3_i18n["ja"] = viewModel.skill3_description_ja }
        
        // 文字字段
        var textFields: [String : String] = [
            "def_id": viewModel.selectedCardID,
            "version": viewModel.version
        ]
        
        if let nameJSON = JSONHelper.toJSONString(name_i18n) {
            textFields["name"] = nameJSON
        }
        if let desJSON = JSONHelper.toJSONString(des_i18n) {
            textFields["description"] = desJSON
        }
        if !des1_i18n.isEmpty, let des1JSON = JSONHelper.toJSONString(des1_i18n) {
            textFields["skill1_description"] = des1JSON
        }
        if !des2_i18n.isEmpty, let des2JSON = JSONHelper.toJSONString(des2_i18n) {
            textFields["skill2_description"] = des2JSON
        }
        if !des3_i18n.isEmpty, let des3JSON = JSONHelper.toJSONString(des3_i18n) {
            textFields["skill3_description"] = des3JSON
        }
        
        for (key, value) in textFields {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.append("\(value)\r\n")
        }
        
        // 图片字段
        let images: [(name: String, image: UIImage?, filename: String)] = [
            ("image", cardImage, "cover.jpg")
        ]
        for (name, image, filename) in images {
            if let unwrappedImage = image, let imageData = ImageTool.compressImage(unwrappedImage, maxSizeKB: 200) {
                body.append("--\(boundary)\r\n")
                body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
                body.append("Content-Type: image/jpg\r\n\r\n")
                body.append(imageData)
                body.append("\r\n")
            }
        }
        
        body.append("--\(boundary)--\r\n")
        
        let request = APIRequest(path: "/asset/update_equip_card_def", method: .post, headers: headers, body: body, isInternal: true)
        
        NetworkService.sendRequest(with: request, decodingType: EmptyResponse.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true) { _ in }
    }
}

struct MagicCardDefView: View {
    @ObservedObject var viewModel: MagicCardBackendViewModel
    let card: MagicCardEntry
    
    
    var body: some View {
        HStack(spacing: 15) {
            Text(card.name_hans)
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
                loadSelectedCardInfo()
                viewModel.showUpdateSheet = true
            }
        }
    }
    
    func loadSelectedCardInfo() {
        viewModel.selectedCardID = card.def_id
        viewModel.name_en = card.name_en
        viewModel.name_hans = card.name_hans
        viewModel.name_hant = card.name_hant
        viewModel.name_ko = card.name_ko
        viewModel.name_ja = card.name_ja
        viewModel.description_en = card.description_en
        viewModel.description_hans = card.description_hans
        viewModel.description_hant = card.description_hant
        viewModel.description_ko = card.description_ko
        viewModel.description_ja = card.description_ja
        viewModel.skill1_description_en = card.skill1_description_en
        viewModel.skill1_description_hans = card.skill1_description_hans
        viewModel.skill1_description_hant = card.skill1_description_hant
        viewModel.skill1_description_ko = card.skill1_description_ko
        viewModel.skill1_description_ja = card.skill1_description_ja
        viewModel.skill2_description_en = card.skill2_description_en
        viewModel.skill2_description_hans = card.skill2_description_hans
        viewModel.skill2_description_hant = card.skill2_description_hant
        viewModel.skill2_description_ko = card.skill2_description_ko
        viewModel.skill2_description_ja = card.skill2_description_ja
        viewModel.skill3_description_en = card.skill3_description_en
        viewModel.skill3_description_hans = card.skill3_description_hans
        viewModel.skill3_description_hant = card.skill3_description_hant
        viewModel.skill3_description_ko = card.skill3_description_ko
        viewModel.skill3_description_ja = card.skill3_description_ja
        viewModel.image_url = card.image_url
        viewModel.version = card.version
    }
}
#endif
