//
//  BikeEventBackendView.swift
//  sportsx
//
//  Created by 任杰 on 2025/6/16.
//
#if DEBUG
import SwiftUI
import PhotosUI


struct BikeEventBackendView: View {
    @EnvironmentObject var appState: AppState
    @StateObject var viewModel = BikeEventBackendViewModel()
    
    @State private var name: String = ""
    @State private var seasonName: String = ""
    @State private var regionName: String = ""
    
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
                
                Text("自行车赛事管理")
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
                    TextField("赛事名称", text: $name)
                        .background(.gray.opacity(0.1))
                    TextField("赛季名称", text: $seasonName)
                        .background(.gray.opacity(0.1))
                    TextField("区域名称", text: $regionName)
                        .background(.gray.opacity(0.1))
                }
                
                Button("查询") {
                    viewModel.events.removeAll()
                    viewModel.currentPage = 1
                    queryEvents()
                }
                .padding()
            }
            
            // 搜索结果展示，每条记录末尾添加一个"修改"按钮
            ScrollView {
                LazyVStack(spacing: 15) {
                    ForEach(viewModel.events) { event in
                        BikeEventCardView(viewModel: viewModel, event: event)
                            .onAppear {
                                if event == viewModel.events.last && viewModel.hasMoreEvents {
                                    queryEvents()
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
                Button("新建赛事") {
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
            BikeEventCreateView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showUpdateSheet) {
            BikeEventUpdateView(viewModel: viewModel)
        }
    }
    
    func queryEvents() {
        isLoading = true
        guard var components = URLComponents(string: "/competition/bike/query_events") else { return }
        components.queryItems = [
            URLQueryItem(name: "season_name", value: seasonName),
            URLQueryItem(name: "region_name", value: regionName),
            URLQueryItem(name: "event_name", value: name),
            URLQueryItem(name: "page", value: "\(viewModel.currentPage)")
        ]
        guard let urlPath = components.string else { return }
        
        let request = APIRequest(path: urlPath, method: .get, isInternal: true)
        
        NetworkService.sendRequest(with: request, decodingType: BikeEventsInternalResponse.self, showSuccessToast: true, showErrorToast: true) { result in
            DispatchQueue.main.async {
                isLoading = false
            }
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        for event in unwrappedData.events {
                            viewModel.events.append(BikeEventCardEntry(from: event))
                        }
                    }
                    if unwrappedData.events.count < 10 {
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

struct BikeEventCreateView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: BikeEventBackendViewModel
    
    @State var name_en: String = "City Tour"
    @State var name_hans: String = "城市巡回赛"
    @State var name_hant: String = "城市巡迴賽"
    @State var name_ko: String = "시티 투어"
    @State var description_en: String = "The City Tour is an official city-wide bicycle series launched by Sporreer, each district has its own independent track and leaderboard.\nThe City Tour is a long-term, open, city-level points race. Each track is a popular competitive route, and every successful completion will earn you entry into the leaderboard for that district. You can repeatedly challenge your personal best on your home track or cross districts to prove your overall ability in different terrains and environments.\nFrom flat beaches to undulating mountain trails, different regions and terrains offer different rhythms and tactical options. Based on your understanding of the track, use the appropriate gear cards to showcase your speed, endurance, and skill.\nWe look forward to your participation and have fun!"
    @State var description_hans: String = "城市巡回赛 是 Sporreer 官方推出的城市区域系列骑行竞技赛事，每个区域均设有独立的赛道与成绩排行榜。\n城市巡回赛是长期巡回开放的城市级积分赛，每一条赛道都是较热门的竞技线路，每一次成功完赛，都会进入对应区域赛道的排行榜。你可以在主场赛道反复冲击个人最佳，也可以跨区挑战，在不同地形与环境中证明自己的综合实力。\n从平坦海滨到起伏山道，不同区域不同地形带来不同的节奏与战术选择。根据你对赛道的理解，搭配合适的装备卡牌，尽情展现速度、耐力和技巧。\n期待你的参与，玩的开心！"
    @State var description_hant: String = "城市巡迴賽 是 Sporreer 官方推出的城市區域系列騎行競技賽事，每個區域均設有獨立的賽道與成績排行榜。\n城市巡迴賽是長期巡迴開放的城市級積分賽，每一條賽道都是較熱門的競技線路，每一次成功完賽，都會進入對應區域賽道的排行榜。你可以在主場賽道反覆衝擊個人最佳，也可以跨區挑戰，在不同地形與環境中證明自己的綜合實力。\n從平坦海濱到起伏山道，不同區域不同地形帶來不同的節奏與戰術選擇。根據你對賽道的理解，搭配合適的裝備卡牌，盡情展現速度、耐力和技巧。\n期待你的參與，玩的開心！"
    @State var description_ko: String = "시티 투어 시합‌는 Sporreer가 공식 출시한 도시 지역 시리즈 라이딩 경기로 각 지역마다 독립된 코스와 성적 순위가 있다.\n도시 순회전은 장기간 개최되는 도시급 포인트 대회로, 각 트랙은 인기 있는 경쟁 코스이며, 성공적으로 완주할 경우 해당 지역 트랙의 랭킹에 진입합니다. 홈 트랙에서 개인 최고 기록을 반복적으로 도전하거나 다른 지역을 넘어서 다양한 지형과 환경에서 종합 실력을 입증할 수 있습니다.\n평탄한 해변에서 기복이 심한 산길까지 서로 다른 지역의 서로 다른 지형은 서로 다른 리듬과 전술 선택을 가져온다.코스에 대한 이해에 따라 적합한 장비 카드와 함께 속도, 지구력, 기교를 마음껏 뽐내세요.\n당신의 참여를 기대하며 즐겁게 놀아요!"
    @State var seasonID: String = "season_8274c6ae"
    @State var regionID: String = ""
    @State var startDate: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 29
        components.hour = 8
        components.minute = 0
        components.second = 0
        return Calendar.current.date(from: components) ?? Date()
    }()
    @State var endDate: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 7
        components.day = 31
        components.hour = 23
        components.minute = 59
        components.second = 59
        return Calendar.current.date(from: components) ?? Date()
    }()
    
    @State var imageURL: String = "/resources/competition/official_event/city_tour/bike_cover_kr.png"
    @State var eventImage: UIImage? = nil
    @State var showImagePicker: Bool = false
    @State var selectedImageItem: PhotosPickerItem?
    
    
    var body: some View {
        VStack {
            Form {
                Section(header: Text("基本信息")) {
                    TextField("赛事名称hans", text: $name_hans)
                    TextField("赛事名称hant", text: $name_hant)
                    TextField("赛事名称en", text: $name_en)
                    TextField("赛事名称ko", text: $name_ko)
                    TextEditor(text: $description_hans)
                        .frame(minHeight: 100)
                        .padding()
                        .overlay(
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3))
                                Text("描述hans")
                            }
                        )
                    TextEditor(text: $description_hant)
                        .frame(minHeight: 100)
                        .padding()
                        .overlay(
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3))
                                Text("描述hant")
                            }
                        )
                    TextEditor(text: $description_en)
                        .frame(minHeight: 100)
                        .padding()
                        .overlay(
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3))
                                Text("描述en")
                            }
                        )
                    TextEditor(text: $description_ko)
                        .frame(minHeight: 100)
                        .padding()
                        .overlay(
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3))
                                Text("描述ko")
                            }
                        )
                    //TextField("描述hans", text: $description_hans)
                    //TextField("描述hant", text: $description_hant)
                    //TextField("描述en", text: $description_en)
                    TextField("赛季ID", text: $seasonID)
                    TextField("区域ID", text: $regionID)
                    TextField("image_url", text: $imageURL)
                }
                Section(header: Text("时间")) {
                    DatePicker("开始时间", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("结束时间", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
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
                        Button("选择图片") {
                            showImagePicker = true
                        }
                    }
                }
                Section {
                    Button("创建赛事") {
                        viewModel.showCreateSheet = false
                        createEvent()
                    }
                    .disabled(name_hant.isEmpty || description_hant.isEmpty || seasonID.isEmpty || regionID.isEmpty)
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
    }
    
    func createEvent() {
        let boundary = "Boundary-\(UUID().uuidString)"
        
        var headers: [String: String] = [:]
        headers["Content-Type"] = "multipart/form-data; boundary=\(boundary)"
        
        var body = Data()
        
        var name_i18n: [String: String] = [:]
        if !name_hans.isEmpty { name_i18n["zh-Hans"] = name_hans }
        if !name_hant.isEmpty { name_i18n["zh-Hant"] = name_hant }
        if !name_en.isEmpty { name_i18n["en"] = name_en }
        if !name_ko.isEmpty { name_i18n["ko"] = name_ko }

        var des_i18n: [String: String] = [:]
        if !description_hans.isEmpty { des_i18n["zh-Hans"] = description_hans }
        if !description_hant.isEmpty { des_i18n["zh-Hant"] = description_hant }
        if !description_en.isEmpty { des_i18n["en"] = description_en }
        if !description_ko.isEmpty { des_i18n["ko"] = description_ko }
        
        var textFields: [String : String] = [
            "start_date": ISO8601DateFormatter().string(from: startDate),
            "end_date": ISO8601DateFormatter().string(from: endDate),
            "season_id": seasonID,
            "region_id": regionID
        ]
        
        if let nameJSON = JSONHelper.toJSONString(name_i18n) {
            textFields["name"] = nameJSON
        }
        if let desJSON = JSONHelper.toJSONString(des_i18n) {
            textFields["description"] = desJSON
        }
        if !imageURL.isEmpty {
            textFields["image_url"] = imageURL
        }
        
        for (key, value) in textFields {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.append("\(value)\r\n")
        }
        
        // 图片字段
        let images: [(name: String, image: UIImage?, filename: String)] = [
            ("event_image", eventImage, "background.png")
        ]
        for (name, image, filename) in images {
            if let unwrappedImage = image, let imageData = ImageTool.compressPNGImage(unwrappedImage, maxSizeKB: 300) {
                body.append("--\(boundary)\r\n")
                body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
                body.append("Content-Type: image/png\r\n\r\n")
                body.append(imageData)
                body.append("\r\n")
            }
        }
        
        body.append("--\(boundary)--\r\n")
        
        let request = APIRequest(path: "/competition/bike/create_event", method: .post, headers: headers, body: body, isInternal: true)
        
        NetworkService.sendRequest(with: request, decodingType: EmptyResponse.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true) { _ in }
    }
}

struct BikeEventUpdateView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: BikeEventBackendViewModel
    
    @State var eventImage: UIImage? = nil
    @State var showImagePicker: Bool = false
    @State var selectedImageItem: PhotosPickerItem?
    
    
    var body: some View {
        VStack {
            Form {
                Section(header: Text("基本信息")) {
                    HStack {
                        Text("赛事名称hans")
                        TextField("赛事名称hans", text: $viewModel.name_hans)
                    }
                    HStack {
                        Text("赛事名称hant")
                        TextField("赛事名称hant", text: $viewModel.name_hant)
                    }
                    HStack {
                        Text("赛事名称en")
                        TextField("赛事名称en", text: $viewModel.name_en)
                    }
                    HStack {
                        Text("赛事名称ko")
                        TextField("赛事名称ko", text: $viewModel.name_ko)
                    }
                    HStack {
                        Text("描述hans")
                        TextField("描述hans", text: $viewModel.description_hans)
                    }
                    HStack {
                        Text("描述hant")
                        TextField("描述hant", text: $viewModel.description_hant)
                    }
                    HStack {
                        Text("描述en")
                        TextField("描述en", text: $viewModel.description_en)
                    }
                    HStack {
                        Text("描述ko")
                        TextField("描述ko", text: $viewModel.description_ko)
                    }
                }
                Section(header: Text("时间")) {
                    DatePicker("开始时间", selection: $viewModel.startDate, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("结束时间", selection: $viewModel.endDate, displayedComponents: [.date, .hourAndMinute])
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
        
        var name_i18n: [String: String] = [:]
        if !viewModel.name_hans.isEmpty { name_i18n["zh-Hans"] = viewModel.name_hans }
        if !viewModel.name_hant.isEmpty { name_i18n["zh-Hant"] = viewModel.name_hant }
        if !viewModel.name_en.isEmpty { name_i18n["en"] = viewModel.name_en }
        if !viewModel.name_ko.isEmpty { name_i18n["ko"] = viewModel.name_ko }

        var des_i18n: [String: String] = [:]
        if !viewModel.description_hans.isEmpty { des_i18n["zh-Hans"] = viewModel.description_hans }
        if !viewModel.description_hant.isEmpty { des_i18n["zh-Hant"] = viewModel.description_hant }
        if !viewModel.description_en.isEmpty { des_i18n["en"] = viewModel.description_en }
        if !viewModel.description_ko.isEmpty { des_i18n["ko"] = viewModel.description_ko }
        
        // 文字字段
        var textFields: [String : String] = [
            "event_id": viewModel.selectedEventID,
            "start_date": ISO8601DateFormatter().string(from: viewModel.startDate),
            "end_date": ISO8601DateFormatter().string(from: viewModel.endDate)
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
            ("event_image", eventImage, "background.png")
        ]
        for (name, image, filename) in images {
            if let unwrappedImage = image, let imageData = ImageTool.compressPNGImage(unwrappedImage, maxSizeKB: 300) {
                body.append("--\(boundary)\r\n")
                body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
                body.append("Content-Type: image/png\r\n\r\n")
                body.append(imageData)
                body.append("\r\n")
            }
        }
        
        body.append("--\(boundary)--\r\n")
        
        let request = APIRequest(path: "/competition/bike/update_event", method: .post, headers: headers, body: body, isInternal: true)
        
        NetworkService.sendRequest(with: request, decodingType: EmptyResponse.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true) { _ in }
    }
}

struct BikeEventCardView: View {
    @ObservedObject var viewModel: BikeEventBackendViewModel
    let event: BikeEventCardEntry
    
    
    var body: some View {
        HStack {
            Text(event.season_name)
            Button("id") {
                UIPasteboard.general.string = event.event_id
                ToastManager.shared.show(toast: Toast(message: "toast.copied", duration: 2))
            }
            Text(event.region_name)
            Text(event.name_hans)
            Spacer()
            Button("修改") {
                loadSelectedEventInfo()
                viewModel.showUpdateSheet = true
            }
        }
    }
    
    func loadSelectedEventInfo() {
        viewModel.selectedEventID = event.event_id
        viewModel.name_en = event.name_en
        viewModel.name_hans = event.name_hans
        viewModel.name_hant = event.name_hant
        viewModel.name_ko = event.name_ko
        viewModel.description_en = event.description_en
        viewModel.description_hans = event.description_hans
        viewModel.description_hant = event.description_hant
        viewModel.description_ko = event.description_ko
        viewModel.startDate = ISO8601DateFormatter().date(from: event.start_date) ?? Date()
        viewModel.endDate = ISO8601DateFormatter().date(from: event.end_date) ?? Date()
        viewModel.image_url = event.image_url
    }
}
#endif
