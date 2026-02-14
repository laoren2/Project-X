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
    @State var selectedProvince: String = "error.unknown"
    @State private var onlyShowWithEvents: Bool = false
    @State var regionIDsWithEvents: [String] = []

    var regions: [String: [Region]] {
        let base: [String: [Region]]
        if locationManager.countryCode == "CN" {
            base = regionTable_CN
        } else if locationManager.countryCode == "HK" {
            base = regionTable_HK
        } else if locationManager.countryCode == "TW" {
            base = regionTable_TW
        } else {
            base = regionTable_HK   // 未来删除
        }
        
        if onlyShowWithEvents {
            // 过滤只保留包含赛事城市的区域
            var filtered: [String: [Region]] = [:]
            for (province, cities) in base {
                let matchingCities = cities.filter { regionIDsWithEvents.contains($0.regionID) }
                if !matchingCities.isEmpty {
                    filtered[province] = matchingCities
                }
            }
            return filtered
        } else {
            return base
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                CommonIconButton(icon: "chevron.left") {
                    appState.navigationManager.removeLast()
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                Spacer()
                Text("competition.location_select.title")
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
                Image("location")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundColor(.white)
                Text(locationManager.regionName ?? "error.unknown")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                CommonTextButton(text: "competition.location_select.action.relocation") {
                    reposition()
                }
                .foregroundStyle(Color.thirdText)
                Spacer()
                Toggle(isOn: $onlyShowWithEvents) {
                    Text("competition.location_select.regions_with_events")
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
                                CommonTextButton(text: province) {
                                    selectedProvince = province
                                }
                                .foregroundColor(province == selectedProvince ? .white : .thirdText)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        } else {
                            Text("error.unknown")
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
                            ForEach(cities) { city in
                                CommonTextButton(text: city.regionName) {
                                    locationManager.regionID = city.regionID
                                    appState.navigationManager.removeLast()
                                }
                                .foregroundColor(city.regionID == locationManager.regionID ? .white : .thirdText)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        } else {
                            Text("error.unknown")
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
        .enableSwipeBackGesture()
        .onFirstAppear {
            fetchRegionsWithEvents()
            for (province, cities) in regions {
                for city in cities {
                    if city.regionID == locationManager.regionID {
                        selectedProvince = province
                        return
                    }
                }
            }
            selectedProvince = regions.keys.sorted().first ?? "error.unknown"
        }
        .onValueChange(of: regions) {
            for (province, cities) in regions {
                for city in cities {
                    if city.regionID == locationManager.regionID {
                        selectedProvince = province
                        return
                    }
                }
            }
            selectedProvince = regions.keys.sorted().first ?? "error.unknown"
        }
        .onValueChange(of: locationManager.countryCode) {
            fetchRegionsWithEvents()
        }
    }
    
    func reposition() {
        guard let location = LocationManager.shared.getLocation() else {
            locationManager.regionID = nil
            PopupWindowManager.shared.presentPopup(
                title: "competition.location_select.no_auth.popup.title",
                message: "competition.location_select.no_auth.popup.content",
                bottomButtons: [.confirm()]
            )
            // todo?: 可以考虑添加location代理重新请求一次位置更新
            return
        }
        // 强制刷新一次
        getCityName(from: location)
    }
    
    func getCityName(from location: CLLocation) {
        locationManager.regionID = GlobalConfig.shared.locationID
        
        fetchRegionID(location: location)
        
        /*let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { (placemarks, error) in
            DispatchQueue.main.async {
                if let placemark = placemarks?.first {
                    if let country = placemark.isoCountryCode, country != locationManager.countryCode {
                        locationManager.countryCode = country
                    }
                }
            }
        }*/
    }
    
    func fetchRegionID(location: CLLocation) {
        var lat = location.coordinate.latitude
        var lon = location.coordinate.longitude
#if DEBUG
        if GlobalConfig.shared.isMockLocation_debug {
            lat = GlobalConfig.shared.location_debug.latitude
            lon = GlobalConfig.shared.location_debug.longitude
        }
#endif
        guard var components = URLComponents(string: "/competition/query_region_id_force") else { return }
        components.queryItems = [
            URLQueryItem(name: "lat", value: "\(lat)"),
            URLQueryItem(name: "lon", value: "\(lon)")
        ]
        guard let urlPath = components.string else { return }
        
        let request = APIRequest(path: urlPath, method: .get, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: RegionResponse.self, showLoadingToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        self.locationManager.regionID = unwrappedData.region_id
                        GlobalConfig.shared.locationID = unwrappedData.region_id
                        locationManager.countryCode = unwrappedData.country_code
                        if let regionID = unwrappedData.region_id, let _ = unwrappedData.country_code {
                            let userManager = UserManager.shared
                            if userManager.isLoggedIn && userManager.user.enableAutoLocation && userManager.user.location != regionID {
                                userManager.updateUserLocation(regionID: regionID)
                            }
                            UserDefaults.standard.set(regionID, forKey: "global.regionID")
                        }
                    }
                }
            default: break
            }
        }
    }
    
    func fetchRegionsWithEvents() {
        //guard let code = locationManager.countryCode else { return }
        guard var components = URLComponents(string: "/competition/query_regions_with_events") else { return }
        components.queryItems = [
            URLQueryItem(name: "sport_type", value: appState.sport.rawValue),
            URLQueryItem(name: "country_code", value: "HK")     // 未来删除
        ]
        guard let urlPath = components.string else { return }
            
        let request = APIRequest(path: urlPath, method: .get)
        
        NetworkService.sendRequest(with: request, decodingType: RegionIDResponse.self, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    regionIDsWithEvents = unwrappedData.regions_with_events
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
