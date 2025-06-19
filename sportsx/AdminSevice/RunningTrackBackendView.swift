//
//  RunningTrackBackendView.swift
//  sportsx
//
//  Created by 任杰 on 2025/6/11.
//

import SwiftUI
import PhotosUI


struct RunningTrackBackendView: View {
    @EnvironmentObject var appState: AppState
    @StateObject var viewModel = RunningTrackBackendViewModel()
    
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
                
                Text("跑步赛道管理")
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
                        RunningTrackCardView(viewModel: viewModel, track: track)
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
        .enableBackGesture()
        .sheet(isPresented: $viewModel.showCreateSheet) {
            RunningTrackCreateView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showUpdateSheet) {
            RunningTrackUpdateView(viewModel: viewModel)
        }
    }
    
    func queryTracks() {
        isLoading = true
        guard var components = URLComponents(string: "/competition/running/query_tracks") else { return }
        components.queryItems = [
            URLQueryItem(name: "track_name", value: name),
            URLQueryItem(name: "event_name", value: eventName),
            URLQueryItem(name: "season_name", value: seasonName),
            URLQueryItem(name: "region_name", value: regionName),
            URLQueryItem(name: "page", value: "\(viewModel.currentPage)")
        ]
        guard let urlPath = components.string else { return }
        
        let request = APIRequest(path: urlPath, method: .get, isInternal: true)
        
        NetworkService.sendRequest(with: request, decodingType: RunningTracksInternalResponse.self, showSuccessToast: true, showErrorToast: true) { result in
            isLoading = false
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        for track in unwrappedData.tracks {
                            viewModel.tracks.append(RunningTrackCardEntry(from: track))
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

struct RunningTrackCreateView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: RunningTrackBackendViewModel
    
    @State var name: String = ""
    @State var eventName: String = ""
    @State var seasonName: String = ""
    @State var regionName: String = ""
    @State var startDate: Date = Date()
    @State var endDate: Date = Date().addingTimeInterval(3600*24)
    
    @State var from_la: String = ""
    @State var from_lo: String = ""
    @State var to_la: String = ""
    @State var to_lo: String = ""
    
    @State var elevationDifference: String = ""
    @State var subRegioName: String = ""
    @State var fee: String = ""
    @State var prizePool: String = ""
    @State var distance: String = ""
    
    @State var trackImage: UIImage? = nil
    @State var showImagePicker: Bool = false
    @State var selectedImageItem: PhotosPickerItem?
    
    
    var body: some View {
        VStack {
            Form {
                Section(header: Text("基本信息")) {
                    TextField("赛道名称", text: $name)
                    TextField("赛事名称", text: $eventName)
                    TextField("赛季名称", text: $seasonName)
                    TextField("区域名称", text: $regionName)
                }
                Section(header: Text("时间")) {
                    DatePicker("开始时间", selection: $startDate, displayedComponents: [.date])
                    DatePicker("结束时间", selection: $endDate, displayedComponents: [.date])
                }
                Section(header: Text("位置信息")) {
                    TextField("起点纬度", text: $from_la)
                        .keyboardType(.decimalPad)
                    TextField("起点经度", text: $from_lo)
                        .keyboardType(.decimalPad)
                    TextField("终点纬度", text: $to_la)
                        .keyboardType(.decimalPad)
                    TextField("终点经度", text: $to_lo)
                        .keyboardType(.decimalPad)
                }
                Section(header: Text("赛道信息")) {
                    TextField("海拔差", text: $elevationDifference)
                        .keyboardType(.numberPad)
                    TextField("子区域", text: $subRegioName)
                    TextField("报名费", text: $fee)
                        .keyboardType(.numberPad)
                    TextField("奖金池", text: $prizePool)
                        .keyboardType(.numberPad)
                    TextField("路程", text: $distance)
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
                        name.isEmpty || eventName.isEmpty || seasonName.isEmpty || regionName.isEmpty
                        || from_la.isEmpty || from_lo.isEmpty || to_la.isEmpty || to_lo.isEmpty
                        || elevationDifference.isEmpty || subRegioName.isEmpty || fee.isEmpty || prizePool.isEmpty
                    )
                }
            }
        }
        .photosPicker(isPresented: $showImagePicker, selection: $selectedImageItem, matching: .images)
        .onChange(of: selectedImageItem) {
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
        
        // 文字字段
        var textFields: [String : String] = [
            "name": name,
            "start_date": ISO8601DateFormatter().string(from: startDate),
            "end_date": ISO8601DateFormatter().string(from: endDate),
            "event_name": eventName,
            "season_name": seasonName,
            "region_name": regionName
        ]
        
        if !from_la.isEmpty { textFields["from_latitude"] = from_la }
        if !from_lo.isEmpty { textFields["from_longitude"] = from_lo }
        if !to_la.isEmpty { textFields["to_latitude"] = to_la }
        if !to_lo.isEmpty { textFields["to_longitude"] = to_lo }
        if !elevationDifference.isEmpty { textFields["elevationDifference"] = elevationDifference }
        if !subRegioName.isEmpty { textFields["subRegioName"] = subRegioName }
        if !fee.isEmpty { textFields["fee"] = fee }
        if !prizePool.isEmpty { textFields["prizePool"] = prizePool }
        if !distance.isEmpty { textFields["distance"] = distance }
        
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
            if let unwrappedImage = image, let imageData = ImageTool.compressImage(unwrappedImage, maxSizeKB: 1000) {
                body.append("--\(boundary)\r\n")
                body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
                body.append("Content-Type: image/jpeg\r\n\r\n")
                body.append(imageData)
                body.append("\r\n")
            }
        }
        
        body.append("--\(boundary)--\r\n")
        
        let request = APIRequest(path: "/competition/running/create_track", method: .post, headers: headers, body: body, isInternal: true)
        
        NetworkService.sendRequest(with: request, decodingType: EmptyResponse.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true) { _ in }
    }
}

struct RunningTrackUpdateView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: RunningTrackBackendViewModel
    
    @State var trackImage: UIImage? = nil
    @State var showImagePicker: Bool = false
    @State var selectedImageItem: PhotosPickerItem?
    
    
    var body: some View {
        VStack {
            Form {
                Section(header: Text("基本信息")) {
                    TextField("赛道名称", text: $viewModel.name)
                }
                Section(header: Text("时间")) {
                    DatePicker("开始时间", selection: $viewModel.startDate, displayedComponents: [.date])
                    DatePicker("结束时间", selection: $viewModel.endDate, displayedComponents: [.date])
                }
                Section(header: Text("位置信息")) {
                    TextField("起点纬度", text: $viewModel.from_la)
                        .keyboardType(.decimalPad)
                    TextField("起点经度", text: $viewModel.from_lo)
                        .keyboardType(.decimalPad)
                    TextField("终点纬度", text: $viewModel.to_la)
                        .keyboardType(.decimalPad)
                    TextField("终点经度", text: $viewModel.to_lo)
                        .keyboardType(.decimalPad)
                }
                Section(header: Text("赛道信息")) {
                    TextField("海拔差", text: $viewModel.elevationDifference)
                        .keyboardType(.numberPad)
                    TextField("子区域", text: $viewModel.subRegioName)
                    TextField("报名费", text: $viewModel.fee)
                        .keyboardType(.numberPad)
                    TextField("奖金池", text: $viewModel.prizePool)
                        .keyboardType(.numberPad)
                    TextField("路程", text: $viewModel.distance)
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
        .onChange(of: selectedImageItem) {
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
        
        // 文字字段
        let textFields: [String : String] = [
            "track_id": viewModel.selectedTrackID,
            "name": viewModel.name,
            "start_date": ISO8601DateFormatter().string(from: viewModel.startDate),
            "end_date": ISO8601DateFormatter().string(from: viewModel.endDate),
            "from_latitude": viewModel.from_la,
            "from_longitude": viewModel.from_lo,
            "to_latitude": viewModel.to_la,
            "to_longitude": viewModel.to_lo,
            "elevationDifference": viewModel.elevationDifference,
            "subRegioName": viewModel.subRegioName,
            "fee": viewModel.fee,
            "prizePool": viewModel.prizePool,
            "distance": viewModel.distance
        ]
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
            if let unwrappedImage = image, let imageData = ImageTool.compressImage(unwrappedImage, maxSizeKB: 1000) {
                body.append("--\(boundary)\r\n")
                body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
                body.append("Content-Type: image/jpeg\r\n\r\n")
                body.append(imageData)
                body.append("\r\n")
            }
        }
        
        body.append("--\(boundary)--\r\n")
        
        let request = APIRequest(path: "/competition/running/update_track", method: .post, headers: headers, body: body, isInternal: true)
        
        NetworkService.sendRequest(with: request, decodingType: EmptyResponse.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true) { _ in }
    }
}

struct RunningTrackCardView: View {
    @ObservedObject var viewModel: RunningTrackBackendViewModel
    let track: RunningTrackCardEntry
    
    
    var body: some View {
        HStack {
            Text(track.season_name)
            Text(track.region_name)
            Text(track.event_name)
            Text(track.name)
            Spacer()
            Button("修改") {
                loadSelectedTrackInfo()
                viewModel.showUpdateSheet = true
            }
        }
    }
    
    func loadSelectedTrackInfo() {
        viewModel.selectedTrackID = track.track_id
        viewModel.name = track.name
        viewModel.startDate = ISO8601DateFormatter().date(from: track.start_date) ?? Date()
        viewModel.endDate = ISO8601DateFormatter().date(from: track.end_date) ?? Date()
        viewModel.image_url = track.image_url
        viewModel.from_la = track.from_latitude
        viewModel.from_lo = track.from_longitude
        viewModel.to_la = track.to_latitude
        viewModel.to_lo = track.to_longitude
        
        viewModel.elevationDifference = track.elevationDifference
        viewModel.subRegioName = track.subRegioName
        viewModel.fee = track.fee
        viewModel.prizePool = track.prizePool
        viewModel.distance = track.distance
    }
}

#Preview {
    RunningTrackBackendView()
}
