//
//  RunningEventBackendView.swift
//  sportsx
//
//  Created by 任杰 on 2025/6/4.
//

import SwiftUI
import PhotosUI


struct RunningEventBackendView: View {
    @EnvironmentObject var appState: AppState
    @StateObject var viewModel = RunningEventBackendViewModel()
    
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
                
                Text("跑步赛事管理")
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
                        RunningEventCardView(viewModel: viewModel, event: event)
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
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBackGesture()
        .sheet(isPresented: $viewModel.showCreateSheet) {
            RunningEventCreateView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showUpdateSheet) {
            RunningEventUpdateView(viewModel: viewModel)
        }
    }
    
    func queryEvents() {
        isLoading = true
        guard var components = URLComponents(string: "/competition/running/query_events") else { return }
        components.queryItems = [
            URLQueryItem(name: "season_name", value: seasonName),
            URLQueryItem(name: "region_name", value: regionName),
            URLQueryItem(name: "event_name", value: name),
            URLQueryItem(name: "page", value: "\(viewModel.currentPage)")
        ]
        guard let urlPath = components.string else { return }
        
        let request = APIRequest(path: urlPath, method: .get, isInternal: true)
        
        NetworkService.sendRequest(with: request, decodingType: RunningEventsInternalResponse.self, showSuccessToast: true, showErrorToast: true) { result in
            DispatchQueue.main.async {
                isLoading = false
            }
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        for event in unwrappedData.events {
                            viewModel.events.append(RunningEventCardEntry(from: event))
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

struct RunningEventCreateView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: RunningEventBackendViewModel
    
    @State var name_en: String = ""
    @State var name_hans: String = ""
    @State var name_hant: String = ""
    @State var description_en: String = ""
    @State var description_hans: String = ""
    @State var description_hant: String = ""
    @State var seasonID: String = ""
    @State var regionID: String = ""
    @State var startDate: Date = Date()
    @State var endDate: Date = Date().addingTimeInterval(3600*24)
    
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
                    TextField("描述hans", text: $description_hans)
                    TextField("描述hant", text: $description_hant)
                    TextField("描述en", text: $description_en)
                    TextField("赛季ID", text: $seasonID)
                    TextField("区域ID", text: $regionID)
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

        var des_i18n: [String: String] = [:]
        if !description_hans.isEmpty { des_i18n["zh-Hans"] = description_hans }
        if !description_hant.isEmpty { des_i18n["zh-Hant"] = description_hant }
        if !description_en.isEmpty { des_i18n["en"] = description_en }
        
        // 文字字段
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
            if let unwrappedImage = image, let imageData = ImageTool.compressImage(unwrappedImage, maxSizeKB: 300) {
                body.append("--\(boundary)\r\n")
                body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
                body.append("Content-Type: image/jpeg\r\n\r\n")
                body.append(imageData)
                body.append("\r\n")
            }
        }
        
        body.append("--\(boundary)--\r\n")
        
        let request = APIRequest(path: "/competition/running/create_event", method: .post, headers: headers, body: body, isInternal: true)
        
        NetworkService.sendRequest(with: request, decodingType: EmptyResponse.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true) { _ in }
    }
}

struct RunningEventUpdateView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: RunningEventBackendViewModel
    
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

        var des_i18n: [String: String] = [:]
        if !viewModel.description_hans.isEmpty { des_i18n["zh-Hans"] = viewModel.description_hans }
        if !viewModel.description_hant.isEmpty { des_i18n["zh-Hant"] = viewModel.description_hant }
        if !viewModel.description_en.isEmpty { des_i18n["en"] = viewModel.description_en }
        
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
            ("event_image", eventImage, "background.jpg")
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
        
        let request = APIRequest(path: "/competition/running/update_event", method: .post, headers: headers, body: body, isInternal: true)
        
        NetworkService.sendRequest(with: request, decodingType: EmptyResponse.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true) { _ in }
    }
}

struct RunningEventCardView: View {
    @ObservedObject var viewModel: RunningEventBackendViewModel
    let event: RunningEventCardEntry
    
    
    var body: some View {
        HStack {
            Text(event.season_name)
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
        viewModel.description_en = event.description_en
        viewModel.description_hans = event.description_hans
        viewModel.description_hant = event.description_hant
        viewModel.startDate = ISO8601DateFormatter().date(from: event.start_date) ?? Date()
        viewModel.endDate = ISO8601DateFormatter().date(from: event.end_date) ?? Date()
        viewModel.image_url = event.image_url
    }
}

#Preview {
    RunningEventBackendView()
}
