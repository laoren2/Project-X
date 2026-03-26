//
//  BikeFreeTrainingView.swift
//  sportsx
//
//  Created by 任杰 on 2026/3/5.
//

import SwiftUI
import MapKit


struct BikeFreeTrainingView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var locationManager = LocationManager.shared
    @ObservedObject var userManager = UserManager.shared
    @StateObject var viewModel = BikeFreeTrainingViewModel()
    @State var stateValue: Int = 0
    @State private var polygons: [MKPolygon] = []
    @State private var explorationProgress: Double = 0
    @State private var isExplorationLoading: Bool = false
    @State private var isStateLoading: Bool = false
    
    let globalConfig = GlobalConfig.shared
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                HStack {
                    Button(action:{
                        appState.navigationManager.append(.bikeTrainingRecordHistoryView)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                            Text("common.history")
                        }
                        .foregroundStyle(Color.white)
                        .font(.system(size: 20))
                    }
                    Spacer()
                    Button(action: {
                        appState.navigationManager.append(.sensorBindView)
                    }) {
                        Image("device_bind")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 20)
                            .padding(.vertical, 5)
                            .padding(.leading, 20)
                    }
                }
                .padding(.horizontal)
                
                ZStack {
                    VStack(spacing: 20) {
                        // 进度条
                        if isStateLoading {
                            Capsule()
                                .foregroundStyle(Color.gray.opacity(0.5))
                                .frame(height: 20)
                        } else {
                            VStack {
                                HStack(spacing: 5) {
                                    Text("training.sport_state")
                                    Image(systemName: "info.circle")
                                        .foregroundStyle(Color.secondText)
                                        .font(.subheadline)
                                        .exclusiveTouchTapGesture {
                                            PopupWindowManager.shared.presentPopup(
                                                title: "training.sport_state",
                                                message: "training.sport_state.description",
                                                bottomButtons: [.confirm()]
                                            )
                                        }
                                    Spacer()
                                    Text("\(stateValue)")
                                }
                                HStack {
                                    Image(systemName: "flame.fill")
                                    ProgressBar(progress: Double(stateValue) / 100)
                                        .frame(height: 20)
                                }
                            }
                            .foregroundStyle(Color.white)
                        }
                        
                        // Map 视图显示当前的 region 完整轮廓，不可交互
                        if isExplorationLoading {
                            Rectangle()
                                .frame(height: 250)
                                .foregroundStyle(Color.gray.opacity(0.5))
                                .cornerRadius(12)
                                .padding(.top, 20)
                            Capsule()
                                .foregroundStyle(Color.gray.opacity(0.5))
                                .frame(height: 25)
                        } else {
                            if !polygons.isEmpty {
                                RegionMapView(polygons: polygons)
                                    .frame(height: 250)
                                    .cornerRadius(12)
                                    .padding(.top, 20)
                            } else {
                                ZStack {
                                    Rectangle()
                                        .frame(height: 250)
                                        .foregroundStyle(Color.gray.opacity(0.5))
                                        .cornerRadius(12)
                                        .padding(.top, 20)
                                    Text("training.exploration.region.not_supported")
                                        .foregroundStyle(Color.white)
                                }
                            }
                            // 进度条显示探索度
                            ZStack {
                                ProgressBar(progress: explorationProgress)
                                    .frame(height: 25)
                                HStack(spacing: 10) {
                                    Spacer()
                                    Text("training.exploration")
                                    Text(String(format: "%.2f %%", explorationProgress * 100))
                                    Image(systemName: "info.circle")
                                        .foregroundStyle(Color.secondText)
                                        .font(.subheadline)
                                        .exclusiveTouchTapGesture {
                                            PopupWindowManager.shared.presentPopup(
                                                title: "training.exploration",
                                                message: "training.exploration.description",
                                                bottomButtons: [.confirm()]
                                            )
                                        }
                                    Spacer()
                                }
                            }
                            .foregroundStyle(Color.white)
                        }
                    }
                    .padding()
                    
                    if !userManager.isLoggedIn {
                        Text("training.error.no_login")
                            .font(.title2)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.black.opacity(0.8))
                    }
                }
                
                VStack(spacing: 20) {
                    if DeviceManager.shared.defaultSensorPos != nil {
                        HStack(spacing: 4) {
                            Image("healthkit")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20)
                            Text("competition.cardselect.healthkit.title")
                            Image(systemName: "info.circle")
                                .exclusiveTouchTapGesture {
                                    PopupWindowManager.shared.presentPopup(
                                        title: "competition.cardselect.healthkit.title",
                                        message: "competition.cardselect.healthkit.content",
                                        bottomButtons: [
                                            .confirm(),
                                            .confirm("action.detail") {
                                                appState.navigationManager.append(.privacyPanelView)
                                            }
                                        ]
                                    )
                                }
                            Spacer()
                        }
                        .foregroundStyle(Color.thirdText)
                        .font(.subheadline)
                    }
                    
                    // 开始按钮
                    Button(action: {
                        guard userManager.isLoggedIn else {
                            userManager.showingLogin = true
                            return
                        }
                        appState.competitionManager.sportFeature = .bikeFreeTraining
                        appState.navigationManager.append(.freeTrainingRealtimeView)
                    }) {
                        
                        Text(userManager.isLoggedIn ? "training.action.ready" : "training.action.ready.no_login")
                            .foregroundStyle(Color.white)
                            .padding(.vertical)
                            .frame(maxWidth: .infinity)
                            .background(appState.competitionManager.isRecording ? Color.gray : Color.orange)
                            .cornerRadius(10)
                    }
                    .disabled(appState.competitionManager.isRecording)
                }
                .padding(.top, 10)
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.vertical)
        }
        .onStableAppear {
            if (!viewModel.didLoad) || globalConfig.refreshFreeTrainingView {
                queryTrainingState()
                if let regionID = locationManager.regionID {
                    queryExploration(with: regionID)
                }
                globalConfig.refreshFreeTrainingView  = false
            }
            DispatchQueue.main.async {
                viewModel.didLoad = true
            }
        }
        .onValueChange(of: locationManager.regionID) {
            if let regionID = locationManager.regionID {
                queryExploration(with: regionID)
            }
        }
        .onValueChange(of: userManager.isLoggedIn) {
            if userManager.isLoggedIn {
                queryTrainingState()
                if let regionID = locationManager.regionID {
                    queryExploration(with: regionID)
                }
            }
        }
    }
    
    func queryTrainingState() {
        guard let components = URLComponents(string: "/training/bike/training_states/me") else { return }
        guard let urlPath = components.url?.absoluteString else { return }
        
        let request = APIRequest(path: urlPath, method: .get, requiresAuth: true)
        
        isStateLoading = true
        NetworkService.sendRequest(with: request, decodingType: Int.self, showLoadingToast: true, showErrorToast: true) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    if let unwrappedData = data {
                        stateValue = unwrappedData
                    }
                default: break
                }
                isStateLoading = false
            }
        }
    }
    
    func queryExploration(with regionID: String) {
        var components = URLComponents(string: "/training/bike/query_region_exploration")
        components?.queryItems = [
            URLQueryItem(name: "region_id", value: regionID)
        ]
        guard let urlPath = components?.url?.absoluteString else { return }
        
        let request = APIRequest(path: urlPath, method: .get, requiresAuth: true)
        
        isExplorationLoading = true
        polygons = []
        NetworkService.sendRequest(
            with: request,
            decodingType: RegionExploreResponse.self,
            showLoadingToast: true,
            showErrorToast: true
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    guard let data else { return }
                    explorationProgress = max(0, min(1, Double(data.explored_grids) / Double(max(data.total_grids, 1))))
                    polygons = parseGeoJSON(data.boundary)
                default: break
                }
                isExplorationLoading = false
            }
        }
    }
    
    func parseGeoJSON(_ boundary: JSONValue) -> [MKPolygon] {
        guard let data = boundary.toData() else { return [] }
        do {
            let features = try MKGeoJSONDecoder().decode(data)
            var polygons: [MKPolygon] = []
            for feature in features {
                guard let geoFeature = feature as? MKGeoJSONFeature else { continue }
                for geometry in geoFeature.geometry {
                    if let polygon = geometry as? MKPolygon {
                        polygons.append(polygon)
                    } else if let multi = geometry as? MKMultiPolygon {
                        polygons.append(contentsOf: multi.polygons)
                    }
                }
            }
            return polygons
        } catch {
            print("GeoJSON parse error:", error)
            return []
        }
    }
}

struct RegionMapView: UIViewRepresentable {
    var polygons: [MKPolygon]
    
    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.isUserInteractionEnabled = false
        map.showsUserLocation = false
        map.delegate = context.coordinator
        return map
    }
    
    func updateUIView(_ map: MKMapView, context: Context) {
        map.removeOverlays(map.overlays)
        map.addOverlays(polygons)
        
        var rect = MKMapRect.null
        for polygon in polygons {
            rect = rect.union(polygon.boundingMapRect)
        }
        if !rect.isNull {
            map.setVisibleMapRect(
                rect,
                edgePadding: UIEdgeInsets(top: 40, left: 40, bottom: 40, right: 40),
                animated: true
            )
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(
            _ mapView: MKMapView,
            rendererFor overlay: MKOverlay
        ) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.strokeColor = .systemOrange
                renderer.fillColor = UIColor.systemOrange.withAlphaComponent(0.2)
                renderer.lineWidth = 2
                
                return renderer
            }
            return MKOverlayRenderer()
        }
    }
}

struct RegionExploreResponse: Codable {
    let explored_grids: Int
    let total_grids: Int
    let boundary: JSONValue
}

class BikeFreeTrainingViewModel: ObservableObject {
    @Published var didLoad: Bool = false
}

#Preview() {
    let app = AppState.shared
    return BikeFreeTrainingView()
        .environmentObject(app)
        .preferredColorScheme(.dark)
}
