//
//  RunningFreeTrainingView.swift
//  sportsx
//
//  Created by 任杰 on 2026/3/5.
//

import SwiftUI
import MapKit


struct RunningFreeTrainingView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var locationManager = LocationManager.shared
    @ObservedObject var userManager = UserManager.shared
    @StateObject var viewModel = RunningFreeTrainingViewModel()
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
                        guard userManager.isLoggedIn else {
                            userManager.showingLogin = true
                            return
                        }
                        appState.navigationManager.append(.runningTrainingRecordHistoryView)
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
                                ZStack {
                                    RegionMapView(polygons: polygons)
                                        .frame(height: 250)
                                        .cornerRadius(12)
                                        .padding(.top, 20)
                                    Rectangle()
                                        .fill(Color.clear)
                                        .contentShape(Rectangle())
                                        .exclusiveTouchTapGesture {
                                            if let region = regionFromPolygons(polygons) {
                                                appState.navigationManager.append(
                                                    .runningTrainingMapView(
                                                        centerLat: region.center.latitude,
                                                        centerLng: region.center.longitude,
                                                        spanLat: region.span.latitudeDelta,
                                                        spanLng: region.span.longitudeDelta
                                                    )
                                                )
                                            } else {
                                                ToastManager.shared.show(toast: Toast(message: "training.exploration.region.not_supported"))
                                            }
                                        }
                                }
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
                                            .cancel("action.confirm"),
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
                        appState.competitionManager.sportFeature = .runningFreeTraining
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
            .padding(.top, 10)
            .padding(.bottom, 85)
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
        .onValueChange(of: locationManager.regionID) { _, newState in
            if let regionID = newState {
                queryExploration(with: regionID)
            }
        }
        .onValueChange(of: userManager.isLoggedIn) { _, newState in
            if newState {
                queryTrainingState()
                if let regionID = locationManager.regionID {
                    queryExploration(with: regionID)
                }
            }
        }
    }
    
    func regionFromPolygons(_ polygons: [MKPolygon]) -> MKCoordinateRegion? {
        guard !polygons.isEmpty else { return nil }
        var rect = MKMapRect.null
        
        for polygon in polygons {
            rect = rect.union(polygon.boundingMapRect)
        }
        if rect.isNull {
            return nil
        }
        
        // 加 padding（扩大 20%）
        let paddingFactor = 1.2
        let width = rect.size.width * paddingFactor
        let height = rect.size.height * paddingFactor
        
        let paddedRect = MKMapRect(
            x: rect.midX - width / 2,
            y: rect.midY - height / 2,
            width: width,
            height: height
        )
        return MKCoordinateRegion(paddedRect)
    }
    
    func queryTrainingState() {
        guard let components = URLComponents(string: "/training/running/training_states/me") else { return }
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
        var components = URLComponents(string: "/training/running/query_region_exploration")
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
                default:
                    break
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

struct RunningTrainingMapView: View {
    @ObservedObject var navigationManager = NavigationManager.shared
    let centerLat: Double
    let centerLng: Double
    let spanLat: Double
    let spanLng: Double
    
    @State var showGrids: Bool = true
    @State var selectedGrid: GridSelection? = nil
    @State var showSheet: Bool = false
    
    var body: some View {
        ZStack {
            TileBasedGridsRunningMapView(
                centerLat: centerLat,
                centerLng: centerLng,
                spanLat: spanLat,
                spanLng: spanLng,
                showGrids: showGrids,
                onGridTap: { selection in
                    selectedGrid = selection
                    showGrids = false
                    showSheet = true
                }
            )
            .ignoresSafeArea(.all)
        }
        .overlay(alignment: .top) {
            HStack {
                Button(action: {
                    navigationManager.removeLast()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 30))
                        .frame(width: 30, height: 30)
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.black.opacity(0.3))
                        .clipShape(Circle())
                }
                Spacer()
                Image("running")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 20)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(10)
                Spacer()
                // 占位，保持布局对称
                Image(systemName: "chevron.left")
                    .font(.system(size: 30))
                    .frame(width: 30, height: 30)
                    .foregroundColor(.clear)
                    .padding(10)
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
        }
        // 右侧控制栏
        .overlay(alignment: .trailing) {
            VStack {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 30))
                    .frame(width: 30, height: 30)
                    .foregroundColor(.white)
                    .padding(10)
                    .background(showGrids ? Color.defaultBackground : Color.black.opacity(0.3))
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(showGrids ? Color.orange : Color.clear, lineWidth: 2)
                    )
                    .padding(.top, 150)
                    .exclusiveTouchTapGesture {
                        showGrids.toggle()
                    }
                
                if showGrids {
                    VStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .bottom, spacing: 4) {
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.orange.opacity(0.1),
                                        Color.orange.opacity(0.3),
                                        Color.orange.opacity(0.5),
                                        Color.orange.opacity(0.6),
                                        Color.orange
                                    ]),
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                                .frame(width: 10, height: 140)
                                .cornerRadius(5)
                                
                                VStack {
                                    Text("10+")
                                    Spacer()
                                    Text("5")
                                    Spacer()
                                    Text("1")
                                }
                                .font(.system(size: 12, weight: .semibold))
                                .frame(height: 140)
                            }
                            
                            HStack(spacing: 11) {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 10, height: 10)
                                Text("0")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                        }
                        
                        VStack(spacing: 0) {
                            Text("training.exploration.2")
                            Text("common.times")
                        }
                        .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(Color.white)
                    .padding(10)
                    .background(Color.defaultBackground)
                    .cornerRadius(10)
                    .padding(.top, 50)
                }
                
                Spacer()
            }
            .padding(.trailing, 10)
        }
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBackGesture()
        .sheet(isPresented: $showSheet, onDismiss: {
            selectedGrid = nil
            showGrids = true
        }) {
            if let grid = selectedGrid {
                RunningGridDetailSheet(grid: grid, showSheet: $showSheet)
                    .presentationDetents([.medium, .large])
                    .interactiveDismissDisabled()
            }
        }
    }
}

struct RunningGridDetailSheet: View {
    @ObservedObject var userManager = UserManager.shared
    @ObservedObject var navigationManager = NavigationManager.shared
    
    let grid: GridSelection
    @Binding var showSheet: Bool
    
    @State private var me: GridFamiliarityMeInfo?
    @State private var rankList: [GridFamiliarityRankInfo] = []
    @State private var hasMore: Bool = false
    @State private var isLoading: Bool = false
    @State private var page: Int = 1
    let pageSize: Int = 10
    
    @State var backgroundColor: Color = .defaultBackground
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Button(action: {}) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(Color.clear)
                }
                Spacer()
                Text("training.realtime.grid.title")
                Spacer()
                Button(action: {
                    showSheet = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 30))
                }
            }
            .padding()
            .foregroundStyle(Color.secondText)
            
            HStack {
                Text("training.realtime.grid.exploration_status")
                Spacer()
            }
            .font(.headline)
            .padding(.horizontal)
            
            // 我的数据
            if let me {
                HStack {
                    Text("#\(me.rank)")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                    if let avatar = userManager.avatarImage {
                        Image(uiImage: avatar)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                    } else {
                        Image("placeholder")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                    }
                    Text("common.me")
                    Spacer()
                    Text("+\(me.count)")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                }
                .padding(.horizontal)
            }
            
            Rectangle()
                .foregroundStyle(Color.thirdText)
                .frame(height: 1)
                .padding(.horizontal)
            
            // 排行榜
            ScrollView(showsIndicators: false) {
                LazyVStack {
                    if rankList.isEmpty {
                        Text("training.realtime.grid.ranklist.no_data")
                            .foregroundStyle(Color.thirdText)
                            .padding(.top, 100)
                    } else {
                        ForEach(rankList) { info in
                            HStack {
                                Text("#\(info.rank)")
                                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                                CachedAsyncImage(urlString: info.avatarUrl)
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 50, height: 50)
                                    .clipShape(Circle())
                                    .exclusiveTouchTapGesture {
                                        showSheet = false
                                        navigationManager.append(.userView(id: info.userID))
                                    }
                                Text(info.nickName)
                                if info.rank == 1 {
                                    Text("training.realtime.grid.occupier")
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.orange)
                                        .cornerRadius(6)
                                }
                                Spacer()
                                Text("+\(info.count)")
                                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(10)
                            .onAppear {
                                if info.id == rankList.last?.id && hasMore {
                                    fetchRankListPage(grid: grid, reset: false)
                                }
                            }
                        }
                        if isLoading {
                            ProgressView()
                                .padding()
                        }
                    }
                }
                .padding()
                .foregroundStyle(Color.white)
            }
        }
        .background(backgroundColor)
        .onStableAppear {
            fetchMeRankInfo()
            fetchRankListPage(grid: grid, reset: true)
        }
    }
    
    func fetchMeRankInfo() {
        guard var components = URLComponents(string: "/training/running/query_grid_familiarity_me") else { return }
        components.queryItems = [
            URLQueryItem(name: "grid_x", value: "\(grid.gridX)"),
            URLQueryItem(name: "grid_y", value: "\(grid.gridY)"),
            URLQueryItem(name: "level", value: "\(grid.level)")
        ]
        guard let urlPath = components.string else { return }
        
        let request = APIRequest(path: urlPath, method: .get, requiresAuth: true)
        NetworkService.sendRequest(with: request, decodingType: GridFamiliarityMeInfo.self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    guard let unwrappedData = data else { return }
                    me = unwrappedData
                default:
                    break
                }
            }
        }
    }
    
    func fetchRankListPage(grid: GridSelection, reset: Bool) {
        if reset {
            page = 1
        }
        isLoading = true
        guard var components = URLComponents(string: "/training/running/query_grid_familiarity_ranklist") else { return }
        components.queryItems = [
            URLQueryItem(name: "grid_x", value: "\(grid.gridX)"),
            URLQueryItem(name: "grid_y", value: "\(grid.gridY)"),
            URLQueryItem(name: "level", value: "\(grid.level)"),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "size", value: "\(pageSize)")
        ]
        guard let urlPath = components.string else { return }
        
        let request = APIRequest(path: urlPath, method: .get)
        NetworkService.sendRequest(with: request, decodingType: GridFamiliarityRankResponse.self) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let data):
                    guard let unwrappedData = data else { return }
                    var tempRanks: [GridFamiliarityRankInfo] = []
                    for info in unwrappedData.data {
                        tempRanks.append(GridFamiliarityRankInfo(from: info))
                    }
                    if reset {
                        rankList = tempRanks
                        if let first = tempRanks.first {
                            downloadImages(url: first.avatarUrl)
                        }
                    } else {
                        rankList.append(contentsOf: tempRanks)
                    }
                    if unwrappedData.data.count < self.pageSize {
                        hasMore = false
                    } else {
                        hasMore = true
                        page += 1
                    }
                default:
                    break
                }
            }
        }
    }
    
    func downloadImages(url: String) {
        NetworkService.downloadImage(from: url) { image in
            if let image = image {
                if let avg = ImageTool.averageColor(from: image) {
                    DispatchQueue.main.async {
                        self.backgroundColor = avg.bestSoftDarkReadableColor()
                    }
                }
            }
        }
    }
}

struct TileBasedGridsRunningMapView: UIViewRepresentable {
    let centerLat: Double
    let centerLng: Double
    let spanLat: Double
    let spanLng: Double
    let showGrids: Bool
    
    var onGridTap: ((GridSelection) -> Void)?
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        mapView.addGestureRecognizer(tap)
        
        mapView.setRegion(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLng),
                span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLng)
            ),
            animated: false
        )
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        context.coordinator.showGrids = showGrids
        
        if !showGrids {
            let removable = uiView.overlays.filter {
                !($0 is SelectedGridOverlay)
            }
            uiView.removeOverlays(removable)
            context.coordinator.renderedTiles.removeAll()
        } else {
            let selected = uiView.overlays.filter { $0 is SelectedGridOverlay }
            uiView.removeOverlays(selected)
            context.coordinator.updateVisibleTiles(mapView: uiView)
        }
    }

    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator(showGrids: showGrids)
        coordinator.onGridTap = onGridTap
        return coordinator
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        // 是否显示网格
        var showGrids: Bool
        // L0 = 500m，每级翻倍
        let baseGridMeters: Double = 500
        // Cache 容量
        let maxCacheTiles = 200

        func tileSize(for level: Int) -> Int {
            switch level {
            case 0: return 32
            case 1: return 32
            case 2: return 16
            default: return 8
            }
        }

        // Cache
        var cache: [TileKey: [GridCell]] = [:]
        var tileAccessOrder: [TileKey] = []
        var renderedTiles: Set<TileKey> = []
        
        // 捕捉 level 变化
        var lastLevel: Int = -1
        
        var onGridTap: ((GridSelection) -> Void)?
        
        weak var mapViewRef: MKMapView?
        
        // init
        init(showGrids: Bool) {
            self.showGrids = showGrids
            super.init()
        }

        // Map 回调
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            self.mapViewRef = mapView
            updateVisibleTiles(mapView: mapView)
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tileOverlay = overlay as? TileOverlay {
                return TileRenderer(overlay: tileOverlay)
            }
            
            if let selected = overlay as? SelectedGridOverlay {
                let renderer = MKPolygonRenderer(polygon: selected.polygon)
                renderer.strokeColor = UIColor.yellow
                renderer.lineWidth = 3
                renderer.fillColor = UIColor.yellow.withAlphaComponent(0.25)
                return renderer
            }
            
            return MKOverlayRenderer(overlay: overlay)
        }

        // 主流程
        func updateVisibleTiles(mapView: MKMapView) {
            if !showGrids {
                return
            }
            let windowBbox = mapView.region
            
            let zoom = getZoomLevel(mapView: mapView)
            let level = levelForZoom(zoom)
            //print("zoom: \(zoom)")
            //print("level: \(level)")
            
            if level >= 3 && zoom < 10 {
                let removable = mapView.overlays.filter {
                    !($0 is SelectedGridOverlay)
                }
                mapView.removeOverlays(removable)
                renderedTiles.removeAll()
                return
            }
            
            let gridRange = convertBBoxToGridRange(bbox: windowBbox, level: level)
            //print("grids: \(gridRange)")
            
            let gridWidth = gridRange.maxX - gridRange.minX
            let gridHeight = gridRange.maxY - gridRange.minY
            let gridCount = gridWidth * gridHeight
            if gridCount > 1000 {
                //print("skip: too many grids: \(gridCount)")
                let removable = mapView.overlays.filter {
                    !($0 is SelectedGridOverlay)
                }
                mapView.removeOverlays(removable)
                renderedTiles.removeAll()
                return
            }

            let neededTiles = computeTiles(gridRange: gridRange, level: level)
            //print("neededTiles: \(neededTiles)")

            let missingTiles = neededTiles.filter { cache[$0] == nil }
            //print("missingTiles: \(missingTiles)")

            // 请求 missingTiles
            fetchTiles(mapView: mapView, tiles: missingTiles)
            // 已有的缓存先渲染
            //print("overlay tiles already: \(mapView.overlays.count)")
            let shouldReload = level != lastLevel || mapView.overlays.count > 1000
            render(mapView: mapView, tiles: neededTiles, removeAll: shouldReload)
            lastLevel = level
        }
        
        func getZoomLevel(mapView: MKMapView) -> Double {
            let region = mapView.region
            return log2(360 * Double(mapView.frame.size.width / 256 / region.span.longitudeDelta)) + 1
        }

        func levelForZoom(_ zoom: Double) -> Int {
            if zoom > 14.5 { return 0 }     // 500m
            if zoom > 13 { return 1 }       // 1km
            if zoom > 11.5 { return 2 }     // 2km
            return 3                        // 4km
        }
        
        func convertBBoxToGridRange(
            bbox: MKCoordinateRegion,
            level: Int
        ) -> (minX: Int, maxX: Int, minY: Int, maxY: Int) {
            let minLat = bbox.center.latitude - bbox.span.latitudeDelta / 2
            let maxLat = bbox.center.latitude + bbox.span.latitudeDelta / 2
            let minLng = bbox.center.longitude - bbox.span.longitudeDelta / 2
            let maxLng = bbox.center.longitude + bbox.span.longitudeDelta / 2
            
            let (minX, minY) = gridXY(lat: minLat, lng: minLng, level: level)
            let (maxX, maxY) = gridXY(lat: maxLat, lng: maxLng, level: level)
            
            return (
                min(minX, maxX),
                max(minX, maxX),
                min(minY, maxY),
                max(minY, maxY)
            )
        }
        
        func divFloor(_ a: Int, _ b: Int) -> Int {
            return Int(floor(Double(a) / Double(b)))
        }
        
        func computeTiles(
            gridRange: (minX: Int, maxX: Int, minY: Int, maxY: Int),
            level: Int
        ) -> [TileKey] {
            let tileSize = tileSize(for: level)

            let minTileX = divFloor(gridRange.minX, tileSize) - 1
            let maxTileX = divFloor(gridRange.maxX, tileSize) + 1

            let minTileY = divFloor(gridRange.minY, tileSize) - 1
            let maxTileY = divFloor(gridRange.maxY, tileSize) + 1

            var tiles: [TileKey] = []

            for x in minTileX...maxTileX {
                for y in minTileY...maxTileY {
                    tiles.append(TileKey(level: level, x: x, y: y))
                }
            }
            return tiles
        }
        
        func fetchTiles(mapView: MKMapView, tiles: [TileKey]) {
            guard !tiles.isEmpty, tiles.count < 50 else { return }
            
            var headers: [String: String] = [:]
            headers["Content-Type"] = "application/json"
            let requestData = TrainingGridTileRequest(tiles: tiles)
            guard let encodedBody = try? JSONEncoder().encode(requestData) else { return }
            
            let request = APIRequest(path: "/training/running/query_grid_tiles", method: .post, headers: headers, body: encodedBody, requiresAuth: true)
            
            NetworkService.sendRequest(with: request, decodingType: TrainingGridTileResponse.self, showLoadingToast: true, showErrorToast: true) { result in
                switch result {
                case .success(let data):
                    guard let unwrappedData = data else { return }
                    DispatchQueue.main.async {
                        var result: [TileKey: [GridCell]] = [:]
                        for tile in unwrappedData.tiles {
                            result[tile.key] = tile.cells
                        }
                        // 写 cache
                        for (tile, cells) in result {
                            self.cache[tile] = cells
                            self.tileAccessOrder.removeAll { $0 == tile }   // 去重
                            self.tileAccessOrder.append(tile)
                        }
                        // 清 cache
                        while self.cache.count > self.maxCacheTiles {
                            let oldest = self.tileAccessOrder.removeFirst()
                            self.cache.removeValue(forKey: oldest)
                            //print("remove cache key: \(oldest)")
                        }
                        
                        // 防止过期数据污染，如果当前视图 level 和返回 tile 的 level 不一致则丢弃渲染
                        let currentZoom = self.getZoomLevel(mapView: mapView)
                        let currentLevel = self.levelForZoom(currentZoom)
                        if let tileLevel = tiles.first?.level, tileLevel != currentLevel {
                            return
                        }
                        self.render(mapView: mapView, tiles: tiles, removeAll: false)
                    }
                default: break
                }
            }
        }
        
        func render(mapView: MKMapView, tiles: [TileKey], removeAll: Bool) {
            if removeAll {
                let removable = mapView.overlays.filter {
                    !($0 is SelectedGridOverlay)
                }
                mapView.removeOverlays(removable)
                renderedTiles.removeAll()
            }
            
            let visibleRect = mapView.visibleMapRect
            let padding = visibleRect.size.width * 0.2
            let paddedRect = visibleRect.insetBy(dx: -padding, dy: -padding)

            for tile in tiles {
                guard let cells = cache[tile] else { continue }
                
                // 避免重复添加同一个 tile overlay
                if !removeAll && renderedTiles.contains(tile) {
                    continue
                }
                
                let tileSize = tileSize(for: tile.level)
                let startX = tile.x * tileSize
                let endX = startX + tileSize - 1
                let startY = tile.y * tileSize
                let endY = startY + tileSize - 1
                
                var map: [String: Int] = [:]
                for cell in cells {
                    map["\(cell.grid_x)_\(cell.grid_y)"] = cell.count
                }
                
                var coords: [CLLocationCoordinate2D] = []
                var colors: [Int] = []
                
                for gx in startX...endX {
                    for gy in startY...endY {
                        let key = "\(gx)_\(gy)"
                        let count = map[key] ?? 0
                        // render
                        let polygon = makePolygon(gridX: gx, gridY: gy, level: tile.level)
                        coords.append(contentsOf: polygon.coordinates())
                        colors.append(count)
                    }
                }
                if !coords.isEmpty {
                    let overlay = TileOverlay(coordinates: coords, counts: colors, level: tile.level)
                    mapView.addOverlay(overlay)
                    renderedTiles.insert(tile)
                    //print("new upsert tile: \(tile)")
                }
            }
        }
        
        func makePolygon(gridX: Int, gridY: Int, level: Int) -> MKPolygon {
            let gridSize = baseGridMeters * pow(2.0, Double(level))
            
            let minX = Double(gridX) * gridSize
            let minY = Double(gridY) * gridSize
            let maxX = minX + gridSize
            let maxY = minY + gridSize
            
            let p1 = CoordinateConverter.mercatorToLatLng(x: minX, y: minY)
            let p2 = CoordinateConverter.mercatorToLatLng(x: maxX, y: minY)
            let p3 = CoordinateConverter.mercatorToLatLng(x: maxX, y: maxY)
            let p4 = CoordinateConverter.mercatorToLatLng(x: minX, y: maxY)
            
            let coords = [
                CoordinateConverter.parseCoordinate(coordinate: CLLocationCoordinate2D(latitude: p1.lat, longitude: p1.lng)),
                CoordinateConverter.parseCoordinate(coordinate: CLLocationCoordinate2D(latitude: p2.lat, longitude: p2.lng)),
                CoordinateConverter.parseCoordinate(coordinate: CLLocationCoordinate2D(latitude: p3.lat, longitude: p3.lng)),
                CoordinateConverter.parseCoordinate(coordinate: CLLocationCoordinate2D(latitude: p4.lat, longitude: p4.lng))
            ]
            return MKPolygon(coordinates: coords, count: coords.count)
        }
        
        func gridXY(lat: Double, lng: Double, level: Int) -> (Int, Int) {
            let (x, y) = CoordinateConverter.latLngToMercator(lat: lat, lng: lng)
            let gridSize = baseGridMeters * pow(2.0, Double(level))
            let gx = Int(floor(x / gridSize))
            let gy = Int(floor(y / gridSize))
            return (gx, gy)
        }
        
        func showSelectedGrid(mapView: MKMapView, gridX: Int, gridY: Int, level: Int) {
            // 移除旧的选中
            let removable = mapView.overlays.filter { $0 is SelectedGridOverlay }
            mapView.removeOverlays(removable)

            let polygon = makePolygon(gridX: gridX, gridY: gridY, level: level)
            let overlay = SelectedGridOverlay(polygon: polygon)
            mapView.addOverlay(overlay)
        }
    }
}

extension TileBasedGridsRunningMapView.Coordinator {
    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let mapView = mapViewRef, showGrids, !renderedTiles.isEmpty else { return }
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let point = gesture.location(in: mapView)
        let coord = mapView.convert(point, toCoordinateFrom: mapView)
        var coordParse = coord
        
        if !CoordinateConverter.outOfChina(coordinate: coord) {
            coordParse = CoordinateConverter.gcj02ToWgs84(lat: coord.latitude, lon: coord.longitude)
        }
        let zoom = getZoomLevel(mapView: mapView)
        let level = levelForZoom(zoom)
        
        let (gx, gy) = gridXY(lat: coordParse.latitude, lng: coordParse.longitude, level: level)
        onGridTap?(GridSelection(gridX: gx, gridY: gy, level: level))
        showSelectedGrid(mapView: mapView, gridX: gx, gridY: gy, level: level)
        
        // 将选中网格移动到视角上方中央
        let currentRegion = mapView.region
        let latOffset = currentRegion.span.latitudeDelta * 0.25   // 向下移动约1/4屏
        let newCenter = CLLocationCoordinate2D(
            latitude: coord.latitude - latOffset,
            longitude: coord.longitude
        )
        let newRegion = MKCoordinateRegion(
            center: newCenter,
            span: currentRegion.span
        )
        mapView.setRegion(newRegion, animated: true)
        //print("Tapped running grid: (\(gx), \(gy)) at level \(level)")
    }
}

class RunningFreeTrainingViewModel: ObservableObject {
    @Published var didLoad: Bool = false
}

#Preview() {
    let app = AppState.shared
    return RunningFreeTrainingView()
        .environmentObject(app)
        .preferredColorScheme(.dark)
}
