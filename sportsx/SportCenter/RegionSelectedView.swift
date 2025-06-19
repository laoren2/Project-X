//
//  RegionSelectedView.swift
//  sportsx
//
//  Created by 任杰 on 2025/6/19.
//

import SwiftUI
import CoreLocation


struct RegionSelectedView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var locationManager = LocationManager.shared
    @State var selectedProvince: String = "未知"
    @State private var onlyShowWithEvents: Bool = false
    @State var regionsWithEvents: [String] = []

    var regions: [String: [String]] {
        let base: [String: [String]]
        if locationManager.countryCode == "CN" {
            base = regions_CN
        } else if locationManager.countryCode == "HK" {
            base = regions_HK
        } else {
            base = ["未知": ["未知"]]
        }
        
        if onlyShowWithEvents && (locationManager.countryCode != "未知") {
            // 过滤只保留包含赛事城市的区域
            var filtered: [String: [String]] = [:]
            for (province, cities) in base {
                let matchingCities = cities.filter { regionsWithEvents.contains($0) }
                if !matchingCities.isEmpty {
                    filtered[province] = matchingCities
                }
            }
            return filtered
        } else {
            return base
        }
    }
    
    private let regions_CN: [String: [String]] = [
        "北京市": ["北京市"],
        "上海市": ["上海市"],
        "广东省": ["广州市", "深圳市", "佛山市"],
        "浙江省": ["杭州市", "宁波市", "温州市"],
        "江苏省": ["南京市", "苏州市", "无锡市"]
    ]
    
    private let regions_HK: [String: [String]] = [
        "香港岛": ["中西区", "东区", "南区", "湾仔区"],
        "九龙": ["九龙城区", "油尖旺区"],
        "新界": ["北区", "西贡区", "沙田区"]
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: {
                    appState.navigationManager.removeLast()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
                
                Spacer()
                
                Text("选择区域")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                // 平衡布局的空按钮
                Button(action: {}) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.clear)
                }
            }
            .padding(.horizontal)
            
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(.white)
                Text(locationManager.region)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button("重新定位") {
                    reposition()
                }
                Spacer()
                Toggle(isOn: $onlyShowWithEvents) {
                    Text("仅显示赛事区域")
                        .font(.subheadline)
                        .foregroundStyle(Color.thirdText)
                }
                .frame(width: 170)
            }
            .padding()
            
            Divider()
            
            // 左右滚动列
            HStack(spacing: 0) {
                // 省份列表
                ScrollView {
                    VStack(alignment: .leading) {
                        if !regions.isEmpty {
                            ForEach(regions.keys.sorted(), id: \.self) { province in
                                Button(action: {
                                    selectedProvince = province
                                }) {
                                    Text(province)
                                        .foregroundColor(province == selectedProvince ? .white : .thirdText)
                                        .padding(.vertical, 8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        } else {
                            Text("未知")
                                .foregroundColor(.thirdText)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding()
                }
                .frame(width: 150)
                .background(Color.gray.opacity(0.1))
                
                Divider()
                
                // 城市列表
                ScrollView {
                    VStack(alignment: .leading) {
                        if let cities = regions[selectedProvince] {
                            ForEach(cities, id: \.self) { city in
                                Button(action: {
                                    locationManager.region = city
                                    appState.navigationManager.removeLast()
                                }) {
                                    Text(city)
                                        .foregroundColor(city == locationManager.region ? .white : .thirdText)
                                        .padding(.vertical, 8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        } else {
                            Text("未知")
                                .foregroundColor(.thirdText)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding()
                }
                .background(Color.gray.opacity(0.2))
            }
        }
        .background(Color.defaultBackground)
        .toolbar(.hidden, for: .navigationBar)
        .enableBackGesture()
        .onAppear {
            selectedProvince = regions.keys.sorted().first ?? "未知"
            fetchCities()
        }
        .onChange(of: regions) {
            selectedProvince = regions.keys.sorted().first ?? "未知"
        }
        .onChange(of: locationManager.countryCode) {
            fetchCities()
        }
    }
    
    func reposition() {
        guard let location = LocationManager.shared.getLocation() else {
            locationManager.region = "未知"
            return
        }
        // 强制刷新一次
        getCityName(from: location)
    }
    
    func getCityName(from location: CLLocation) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { (placemarks, error) in
            if let placemark = placemarks?.first, let city = placemark.locality, !city.isEmpty, city != locationManager.region {
                locationManager.region = city
            }
        }
    }
    
    func fetchCities() {
        if locationManager.countryCode == "未知" { return }
        
        guard var components = URLComponents(string: "/competition/query_regions") else { return }
        components.queryItems = [
            URLQueryItem(name: "sport_type", value: appState.sport.rawValue),
            URLQueryItem(name: "country_code", value: locationManager.countryCode)
        ]
        guard let urlPath = components.string else { return }
            
        let request = APIRequest(path: urlPath, method: .get)
        
        NetworkService.sendRequest(with: request, decodingType: RegionResponse.self, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    regionsWithEvents = unwrappedData.regions_with_events
                }
            default: break
            }
        }
    }
}


#Preview {
    let app = AppState.shared
    return RegionSelectedView()
        .environmentObject(app)
}
