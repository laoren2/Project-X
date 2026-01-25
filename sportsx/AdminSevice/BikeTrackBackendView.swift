//
//  BikeTrackBackendView.swift
//  sportsx
//
//  Created by 任杰 on 2025/6/16.
//

import SwiftUI
import PhotosUI


struct BikeTrackBackendView: View {
    @EnvironmentObject var appState: AppState
    @StateObject var viewModel = BikeTrackBackendViewModel()
    
    @State private var name: String = ""
    @State private var eventName: String = ""
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
                
                Text("自行车赛道管理")
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
                    TextField("赛道名称", text: $name)
                        .background(.gray.opacity(0.1))
                    TextField("赛事名称", text: $eventName)
                        .background(.gray.opacity(0.1))
                    TextField("赛季名称", text: $seasonName)
                        .background(.gray.opacity(0.1))
                    TextField("区域名称", text: $regionName)
                        .background(.gray.opacity(0.1))
                }
                
                Button("查询") {
                    viewModel.tracks.removeAll()
                    viewModel.currentPage = 1
                    queryTracks()
                }
                .padding()
            }
            
            // 搜索结果展示，每条记录末尾添加一个"修改"按钮
            ScrollView {
                LazyVStack(spacing: 15) {
                    ForEach(viewModel.tracks) { track in
                        BikeTrackCardView(viewModel: viewModel, track: track)
                            .onAppear {
                                if track == viewModel.tracks.last && viewModel.hasMoreTracks {
                                    queryTracks()
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
                Button("新建赛道") {
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
            BikeTrackCreateView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showUpdateSheet) {
            BikeTrackUpdateView(viewModel: viewModel)
        }
    }
    
    func queryTracks() {
        isLoading = true
        guard var components = URLComponents(string: "/competition/bike/query_tracks") else { return }
        components.queryItems = [
            URLQueryItem(name: "track_name", value: name),
            URLQueryItem(name: "event_name", value: eventName),
            URLQueryItem(name: "season_name", value: seasonName),
            URLQueryItem(name: "region_name", value: regionName),
            URLQueryItem(name: "page", value: "\(viewModel.currentPage)")
        ]
        guard let urlPath = components.string else { return }
        
        let request = APIRequest(path: urlPath, method: .get, isInternal: true)
        
        NetworkService.sendRequest(with: request, decodingType: BikeTracksInternalResponse.self, showSuccessToast: true, showErrorToast: true) { result in
            DispatchQueue.main.async {
                isLoading = false
            }
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        for track in unwrappedData.tracks {
                            viewModel.tracks.append(BikeTrackCardEntry(from: track))
                        }
                    }
                    if unwrappedData.tracks.count < 10 {
                        viewModel.hasMoreTracks = false
                    } else {
                        viewModel.hasMoreTracks = true
                        viewModel.currentPage += 1
                    }
                }
            default: break
            }
        }
    }
}

struct BikeTrackCreateView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: BikeTrackBackendViewModel
    
    @State var name_en: String = ""
    @State var name_hans: String = ""
    @State var name_hant: String = ""
    @State var eventID: String = ""
    @State var startDate: Date = Date()
    @State var endDate: Date = Date().addingTimeInterval(3600*24)
    
    @State var from_la: String = ""
    @State var from_lo: String = ""
    @State var from_radius: Int = 10
    @State var to_la: String = ""
    @State var to_lo: String = ""
    @State var to_radius: Int = 10
    
    @State var singleRegisterCardID: String = ""
    @State var teamRegisterCardID: String = ""
    
    @State var elevationDifference: String = ""
    @State var subRegioName_en: String = ""
    @State var subRegioName_hans: String = ""
    @State var subRegioName_hant: String = ""
    @State var prizePool: String = ""
    @State var score: String = ""
    @State var distance: String = ""
    @State var terrainType: BikeTrackTerrainType = .other
    
    @State var trackImage: UIImage? = nil
    @State var showImagePicker: Bool = false
    @State var selectedImageItem: PhotosPickerItem?
    
    let types = [
        BikeTrackTerrainType.road,
        BikeTrackTerrainType.crossCountry,
        BikeTrackTerrainType.enduro,
        BikeTrackTerrainType.downHill,
        BikeTrackTerrainType.other
    ]
    
    var body: some View {
        VStack {
            Form {
                Section(header: Text("基本信息")) {
                    TextField("赛道名称hans", text: $name_hans)
                    TextField("赛道名称hant", text: $name_hant)
                    TextField("赛道名称en", text: $name_en)
                    TextField("赛事ID", text: $eventID)
                }
                Section(header: Text("时间")) {
                    DatePicker("开始时间", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("结束时间", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                }
                Section(header: Text("位置信息")) {
                    TextField("起点纬度", text: $from_la)
                        .keyboardType(.decimalPad)
                    TextField("起点经度", text: $from_lo)
                        .keyboardType(.decimalPad)
                    TextField("起点半径", value: $from_radius, format: .number)
                        .keyboardType(.numberPad)
                    TextField("终点纬度", text: $to_la)
                        .keyboardType(.decimalPad)
                    TextField("终点经度", text: $to_lo)
                        .keyboardType(.decimalPad)
                    TextField("终点半径", value: $to_radius, format: .number)
                        .keyboardType(.numberPad)
                }
                Section(header: Text("赛道信息")) {
                    Menu {
                        ForEach(types, id: \.self) { type in
                            Button(type.rawValue) {
                                terrainType = type
                            }
                        }
                    } label: {
                        HStack {
                            Text(terrainType.rawValue)
                                .font(.subheadline)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .cornerRadius(8)
                    }
                    TextField("海拔差", text: $elevationDifference)
                        .keyboardType(.numberPad)
                    TextField("子区域hans", text: $subRegioName_hans)
                    TextField("子区域hant", text: $subRegioName_hant)
                    TextField("子区域en", text: $subRegioName_en)
                    TextField("奖金池", text: $prizePool)
                        .keyboardType(.numberPad)
                    TextField("积分", text: $score)
                        .keyboardType(.numberPad)
                    TextField("距离", text: $distance)
                        .keyboardType(.decimalPad)
                    TextField("单人报名卡ID", text: $singleRegisterCardID)
                    TextField("组队报名卡ID", text: $teamRegisterCardID)
                }
                Section(header: Text("封面图片")) {
                    if let image = trackImage {
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
                    Button("创建赛道") {
                        viewModel.showCreateSheet = false
                        createTrack()
                    }
                    .disabled(
                        name_hant.isEmpty || eventID.isEmpty || from_la.isEmpty || from_lo.isEmpty
                        || to_la.isEmpty || to_lo.isEmpty || elevationDifference.isEmpty
                        || subRegioName_hant.isEmpty || prizePool.isEmpty || score.isEmpty || from_radius == 0 || to_radius == 0
                    )
                }
            }
        }
        .photosPicker(isPresented: $showImagePicker, selection: $selectedImageItem, matching: .images)
        .onValueChange(of: selectedImageItem) {
            Task {
                if let data = try? await selectedImageItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    trackImage = uiImage
                } else {
                    trackImage = nil
                }
            }
        }
    }
    
    func createTrack() {
        let boundary = "Boundary-\(UUID().uuidString)"
        
        var headers: [String: String] = [:]
        headers["Content-Type"] = "multipart/form-data; boundary=\(boundary)"
        
        var body = Data()
        
        var name_i18n: [String: String] = [:]
        if !name_hans.isEmpty { name_i18n["zh-Hans"] = name_hans }
        if !name_hant.isEmpty { name_i18n["zh-Hant"] = name_hant }
        if !name_en.isEmpty { name_i18n["en"] = name_en }

        var subRegionName_i18n: [String: String] = [:]
        if !subRegioName_hans.isEmpty { subRegionName_i18n["zh-Hans"] = subRegioName_hans }
        if !subRegioName_hant.isEmpty { subRegionName_i18n["zh-Hant"] = subRegioName_hant }
        if !subRegioName_en.isEmpty { subRegionName_i18n["en"] = subRegioName_en }
        
        // 文字字段
        var textFields: [String : String] = [
            "start_date": ISO8601DateFormatter().string(from: startDate),
            "end_date": ISO8601DateFormatter().string(from: endDate),
            "event_id": eventID,
            "terrain_type": terrainType.rawValue,
            "from_latitude": from_la,
            "from_longitude": from_lo,
            "from_radius": "\(from_radius)",
            "to_latitude": to_la,
            "to_longitude": to_lo,
            "to_radius": "\(to_radius)",
            "single_registercard_id": singleRegisterCardID,
            "team_registercard_id": teamRegisterCardID,
            "elevationDifference": elevationDifference,
            "prizePool": prizePool,
            "score": score,
            "distance": distance
        ]
        
        if let nameJSON = JSONHelper.toJSONString(name_i18n) {
            textFields["name"] = nameJSON
        }
        if let subRegionNameJSON = JSONHelper.toJSONString(subRegionName_i18n) {
            textFields["subRegioName"] = subRegionNameJSON
        }
        
        for (key, value) in textFields {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.append("\(value)\r\n")
        }
        
        // 图片字段
        let images: [(name: String, image: UIImage?, filename: String)] = [
            ("track_image", trackImage, "background.jpg")
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
        
        let request = APIRequest(path: "/competition/bike/create_track", method: .post, headers: headers, body: body, isInternal: true)
        
        NetworkService.sendRequest(with: request, decodingType: EmptyResponse.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true) { _ in }
    }
}

struct BikeTrackUpdateView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: BikeTrackBackendViewModel
    
    @State var trackImage: UIImage? = nil
    @State var showImagePicker: Bool = false
    @State var selectedImageItem: PhotosPickerItem?
    
    let types = [
        BikeTrackTerrainType.road,
        BikeTrackTerrainType.crossCountry,
        BikeTrackTerrainType.enduro,
        BikeTrackTerrainType.downHill,
        BikeTrackTerrainType.other
    ]
    
    var body: some View {
        VStack {
            Form {
                Section(header: Text("基本信息")) {
                    HStack {
                        Text("赛道名称hans")
                        TextField("赛道名称hans", text: $viewModel.name_hans)
                    }
                    HStack {
                        Text("赛道名称hant")
                        TextField("赛道名称hant", text: $viewModel.name_hant)
                    }
                    HStack {
                        Text("赛道名称en")
                        TextField("赛道名称en", text: $viewModel.name_en)
                    }
                }
                Section(header: Text("时间")) {
                    DatePicker("开始时间", selection: $viewModel.startDate, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("结束时间", selection: $viewModel.endDate, displayedComponents: [.date, .hourAndMinute])
                }
                Section(header: Text("位置信息")) {
                    TextField("起点纬度", text: $viewModel.from_la)
                        .keyboardType(.decimalPad)
                    TextField("起点经度", text: $viewModel.from_lo)
                        .keyboardType(.decimalPad)
                    TextField("起点半径", value: $viewModel.from_radius, format: .number)
                        .keyboardType(.numberPad)
                    TextField("终点纬度", text: $viewModel.to_la)
                        .keyboardType(.decimalPad)
                    TextField("终点经度", text: $viewModel.to_lo)
                        .keyboardType(.decimalPad)
                    TextField("终点半径", value: $viewModel.to_radius, format: .number)
                        .keyboardType(.numberPad)
                }
                Section(header: Text("赛道信息")) {
                    Menu {
                        ForEach(types, id: \.self) { type in
                            Button(type.rawValue) {
                                viewModel.terrainType = type
                            }
                        }
                    } label: {
                        HStack {
                            Text(viewModel.terrainType.rawValue)
                                .font(.subheadline)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .cornerRadius(8)
                    }
                    TextField("海拔差", text: $viewModel.elevationDifference)
                        .keyboardType(.numberPad)
                    HStack {
                        Text("子区域en")
                        TextField("子区域en", text: $viewModel.subRegioName_en)
                    }
                    HStack {
                        Text("子区域hans")
                        TextField("子区域hans", text: $viewModel.subRegioName_hans)
                    }
                    HStack {
                        Text("子区域hant")
                        TextField("子区域hant", text: $viewModel.subRegioName_hant)
                    }
                    TextField("奖金池", text: $viewModel.prizePool)
                        .keyboardType(.numberPad)
                    TextField("积分", text: $viewModel.score)
                        .keyboardType(.numberPad)
                    TextField("距离", text: $viewModel.distance)
                        .keyboardType(.decimalPad)
                }
                Section(header: Text("封面图片")) {
                    if let image = trackImage {
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
                        updateTrack()
                    }
                }
            }
        }
        .photosPicker(isPresented: $showImagePicker, selection: $selectedImageItem, matching: .images)
        .onValueChange(of: selectedImageItem) {
            Task {
                if let data = try? await selectedImageItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    trackImage = uiImage
                } else {
                    trackImage = nil
                }
            }
        }
        .onAppear {
            NetworkService.downloadImage(from: viewModel.image_url) { image in
                DispatchQueue.main.async {
                    if let image = image {
                        trackImage = image
                    } else {
                        trackImage = UIImage(systemName: "photo.badge.exclamationmark")
                    }
                }
            }
        }
    }
    
    func updateTrack() {
        let boundary = "Boundary-\(UUID().uuidString)"
        
        var headers: [String: String] = [:]
        headers["Content-Type"] = "multipart/form-data; boundary=\(boundary)"
        
        var body = Data()
        
        var name_i18n: [String: String] = [:]
        if !viewModel.name_hans.isEmpty { name_i18n["zh-Hans"] = viewModel.name_hans }
        if !viewModel.name_hant.isEmpty { name_i18n["zh-Hant"] = viewModel.name_hant }
        if !viewModel.name_en.isEmpty { name_i18n["en"] = viewModel.name_en }

        var subRegionName_i18n: [String: String] = [:]
        if !viewModel.subRegioName_hans.isEmpty { subRegionName_i18n["zh-Hans"] = viewModel.subRegioName_hans }
        if !viewModel.subRegioName_hant.isEmpty { subRegionName_i18n["zh-Hant"] = viewModel.subRegioName_hant }
        if !viewModel.subRegioName_en.isEmpty { subRegionName_i18n["en"] = viewModel.subRegioName_en }
        
        // 文字字段
        var textFields: [String : String] = [
            "track_id": viewModel.selectedTrackID,
            "start_date": ISO8601DateFormatter().string(from: viewModel.startDate),
            "end_date": ISO8601DateFormatter().string(from: viewModel.endDate),
            "from_latitude": viewModel.from_la,
            "from_longitude": viewModel.from_lo,
            "from_radius": "\(viewModel.from_radius)",
            "to_latitude": viewModel.to_la,
            "to_longitude": viewModel.to_lo,
            "to_radius": "\(viewModel.to_radius)",
            "elevationDifference": viewModel.elevationDifference,
            "prizePool": viewModel.prizePool,
            "score": viewModel.score,
            "distance": viewModel.distance,
            "terrain_type": viewModel.terrainType.rawValue
        ]
        
        if let nameJSON = JSONHelper.toJSONString(name_i18n) {
            textFields["name"] = nameJSON
        }
        if let subRegionNameJSON = JSONHelper.toJSONString(subRegionName_i18n) {
            textFields["subRegioName"] = subRegionNameJSON
        }
        
        for (key, value) in textFields {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.append("\(value)\r\n")
        }
        
        // 图片字段
        let images: [(name: String, image: UIImage?, filename: String)] = [
            ("track_image", trackImage, "background.jpg")
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
        
        let request = APIRequest(path: "/competition/bike/update_track", method: .post, headers: headers, body: body, isInternal: true)
        
        NetworkService.sendRequest(with: request, decodingType: EmptyResponse.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true) { _ in }
    }
}

struct BikeTrackCardView: View {
    @ObservedObject var viewModel: BikeTrackBackendViewModel
    let track: BikeTrackCardEntry
    var status: String {
        if let startDate = ISO8601DateFormatter().date(from: track.start_date),
           let endDate = ISO8601DateFormatter().date(from: track.end_date) {
            if startDate > Date() { return "未开始" }
            if startDate < Date() && endDate > Date() { return "进行中" }
            if endDate < Date() && (!track.is_settled) { return "待结算" }
            if endDate < Date() && track.is_settled { return "已结束" }
        }
        return "未知状态"
    }
    
    var statusColor: Color {
        if let startDate = ISO8601DateFormatter().date(from: track.start_date),
           let endDate = ISO8601DateFormatter().date(from: track.end_date) {
            if startDate > Date() { return Color.black }
            if startDate < Date() && endDate > Date() { return Color.orange }
            if endDate < Date() && (!track.is_settled) { return Color.green }
            if endDate < Date() && track.is_settled { return Color.gray }
        }
        return Color.red
    }
    
    var body: some View {
        HStack {
            Text(track.season_name)
            Text(track.region_name)
            Text(track.event_name)
            Text(track.name_hans)
            Spacer()
            Button("修改") {
                loadSelectedTrackInfo()
                viewModel.showUpdateSheet = true
            }
            Button(status) {
                if status == "待结算" {
                    settledTrackLeaderboard()
                }
            }
            .foregroundStyle(statusColor)
        }
    }
    
    func settledTrackLeaderboard() {
        guard var components = URLComponents(string: "/competition/bike/settle_leaderboard") else { return }
        components.queryItems = [
            URLQueryItem(name: "track_id", value: track.track_id)
        ]
        guard let urlPath = components.url?.absoluteString else { return }
        
        let request = APIRequest(path: urlPath, method: .post, isInternal: true)
        
        NetworkService.sendRequest(with: request, decodingType: EmptyResponse.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true) { _ in }
    }
    
    func loadSelectedTrackInfo() {
        viewModel.selectedTrackID = track.track_id
        viewModel.name_en = track.name_en
        viewModel.name_hans = track.name_hans
        viewModel.name_hant = track.name_hant
        viewModel.startDate = ISO8601DateFormatter().date(from: track.start_date) ?? Date()
        viewModel.endDate = ISO8601DateFormatter().date(from: track.end_date) ?? Date()
        viewModel.image_url = track.image_url
        viewModel.from_la = track.from_latitude
        viewModel.from_lo = track.from_longitude
        viewModel.from_radius = track.from_radius
        viewModel.to_la = track.to_latitude
        viewModel.to_lo = track.to_longitude
        viewModel.to_radius = track.to_radius
        
        viewModel.elevationDifference = track.elevationDifference
        viewModel.subRegioName_en = track.subRegioName_en
        viewModel.subRegioName_hans = track.subRegioName_hans
        viewModel.subRegioName_hant = track.subRegioName_hant
        viewModel.prizePool = track.prizePool
        viewModel.score = track.score
        viewModel.distance = track.distance
        viewModel.terrainType = track.terrain_type
    }
}
