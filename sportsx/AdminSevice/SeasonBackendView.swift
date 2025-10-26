//
//  SeasonBackendView.swift
//  sportsx
//
//  Created by 任杰 on 2025/6/4.
//

import SwiftUI


struct SeasonBackendView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var sportType: SportName = .Running
    @State private var seasonName: String = ""
    @State private var regionName: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
    
    @State var seasonImage: UIImage? = nil
    
    
    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    appState.navigationManager.removeLast()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.black)
                }
                
                Spacer()
                
                Text("赛季管理")
                    .font(.system(size: 18, weight: .bold))
                
                Spacer()
                
                // 平衡布局的空按钮
                Button(action: {}) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.clear)
                }
            }
            .padding(.horizontal)
            
            Form {
                Section(header: Text("运动类型")) {
                    Picker("运动", selection: $sportType) {
                        ForEach(SportName.allCases.filter { $0.isSupported }, id: \.self) { type in
                            Text(type.name).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(header: Text("赛季名称")) {
                    TextField("请输入赛季名称", text: $seasonName)
                }
                
                Section(header: Text("赛季时间")) {
                    DatePicker("开始时间", selection: $startDate, displayedComponents: .date)
                    DatePicker("结束时间", selection: $endDate, displayedComponents: .date)
                }
                
                Section {
                    HStack {
                        Spacer()
                        Button(action: createSeason) {
                            Text("创建赛季")
                        }
                        .disabled(seasonName.isEmpty)
                        Spacer()
                    }
                }
                
                Section(header: Text("地理区域名称")) {
                    TextField("请输入地理区域名称", text: $regionName)
                }
                
                Section {
                    Button("创建地理区域") {
                        createRegion()
                    }
                    .disabled(regionName.isEmpty)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBackGesture()
    }
    
    func createSeason() {
        let boundary = "Boundary-\(UUID().uuidString)"
        
        var headers: [String: String] = [:]
        headers["Content-Type"] = "multipart/form-data; boundary=\(boundary)"
        
        var body = Data()
        
        // 文字字段
        let dateFormatter = ISO8601DateFormatter()
        let textFields: [String : String] = [
            "name": seasonName,
            "start_date": dateFormatter.string(from: startDate),
            "end_date": dateFormatter.string(from: endDate),
            "sport_type": sportType.rawValue
        ]
        for (key, value) in textFields {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.append("\(value)\r\n")
        }
        
        // 图片字段
        let images: [(name: String, image: UIImage?, filename: String)] = [
            ("event_image", seasonImage, "background.png")
        ]
        for (name, image, filename) in images {
            if let unwrappedImage = image, let imageData = unwrappedImage.pngData() {
                body.append("--\(boundary)\r\n")
                body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
                body.append("Content-Type: image/png\r\n\r\n")
                body.append(imageData)
                body.append("\r\n")
            }
        }
        
        body.append("--\(boundary)--\r\n")

        let request = APIRequest(path: "/competition/create_season", method: .post, headers: headers, body: body, isInternal: true)

        NetworkService.sendRequest(with: request, decodingType: EmptyResponse.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    seasonName = ""
                default: break
                }
            }
        }
    }
    
    func createRegion() {
        var headers: [String: String] = [:]
        headers["Content-Type"] = "application/json"
        
        let body: [String: String] = [
            "name": regionName
        ]
        guard let encodedBody = try? JSONEncoder().encode(body) else {
            return
        }
        let request = APIRequest(path: "/competition/create_region", method: .post, headers: headers, body: encodedBody, isInternal: true)

        NetworkService.sendRequest(with: request, decodingType: EmptyResponse.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    regionName = ""
                default: break
                }
            }
        }
    }
}


#Preview {
    SeasonBackendView()
}
