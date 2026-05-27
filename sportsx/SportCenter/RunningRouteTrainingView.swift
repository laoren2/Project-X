//
//  RunningRouteTrainingView.swift
//  sportsx
//
//  Created by 任杰 on 2026/4/22.
//

import SwiftUI
import MapKit


struct RunningRouteTrainingView: View {
    @StateObject var viewModel = RunningRouteTrainingViewModel()
    @ObservedObject var competitionManager = CompetitionManager.shared
    @ObservedObject var navigationManager = NavigationManager.shared
    @ObservedObject var userManager = UserManager.shared
    @ObservedObject var locationManager = LocationManager.shared
    @State var showFullMap: Bool = false
    @State var onSortTypeSwitch: Bool = false
    
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 10) {
                    HStack {
                        Button(action:{
                            guard userManager.isLoggedIn else {
                                userManager.showingLogin = true
                                return
                            }
                            navigationManager.append(.runningTrainingRecordHistoryView)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                Text("common.history")
                            }
                        }
                        Spacer()
                        Button(action: {
                            guard userManager.isLoggedIn else {
                                userManager.showingLogin = true
                                return
                            }
                            navigationManager.append(.runningRouteManageView)
                        }) {
                            Text("common.my")
                        }
                    }
                    .font(.system(size: 20))
                    .foregroundStyle(Color.white)
                    VStack(spacing: 0) {
                        HStack {
                            Image("road_sign")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 30)
                            Spacer()
                            if onSortTypeSwitch {
                                ScrollView(.horizontal) {
                                    HStack(spacing: 8) {
                                        ForEach(RouteSortType.allCases, id: \.self) { type in
                                            Text(LocalizedStringKey(type.displayName))
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundStyle(viewModel.sortType == type ? Color.white : Color.thirdText)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(
                                                    Capsule()
                                                        .fill(viewModel.sortType == type ? Color.orange : Color.secondBackground)
                                                )
                                                .exclusiveTouchTapGesture {
                                                    onSortTypeSwitch.toggle()
                                                    let lastSortType = viewModel.sortType
                                                    viewModel.sortType = type
                                                    if let regionID = locationManager.regionID,
                                                       lastSortType != type,
                                                       !viewModel.routes.isEmpty {
                                                        viewModel.queryRoutes(with: regionID, reset: true)
                                                    }
                                                }
                                        }
                                    }
                                }
                                .frame(maxWidth: 200)
                            } else {
                                HStack(spacing: 4) {
                                    Text(LocalizedStringKey(viewModel.sortType.displayName))
                                        .foregroundStyle(Color.white)
                                        .font(.system(size: 13, weight: .medium))
                                    Image(systemName: "arrow.up.arrow.down")
                                        .foregroundStyle(Color.secondText)
                                        .font(.system(size: 10, weight: .light))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .overlay(
                                    Capsule()
                                        .stroke(Color.orange, lineWidth: 1)
                                )
                                .exclusiveTouchTapGesture {
                                    onSortTypeSwitch.toggle()
                                }
                            }
                        }
                        .padding()
                        ScrollView {
                            LazyVStack {
                                if viewModel.isResetLoading {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.gray)
                                        .frame(height: 60)
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.gray)
                                        .frame(height: 60)
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.gray)
                                        .frame(height: 60)
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.gray)
                                        .frame(height: 60)
                                } else {
                                    if viewModel.routes.isEmpty {
                                        VStack(spacing: 10) {
                                            Image("no_data")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(height: 100)
                                            Text("error.nothing_here")
                                                .font(.system(size: 15))
                                                .foregroundStyle(Color.secondText)
                                        }
                                        .padding(.top, 100)
                                    } else {
                                        ForEach(viewModel.routes) { route in
                                            RunningRouteCardView(route: route, sortType: viewModel.sortType)
                                                .contentShape(Rectangle())
                                                .background (
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .fill(Color.black.opacity(0.2))
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 10)
                                                                .stroke(viewModel.selectedRoute?.id == route.id ? Color.orange : Color.clear, lineWidth: 1)
                                                        )
                                                )
                                                .exclusiveTouchTapGesture {
                                                    viewModel.selectedRoute = route
                                                }
                                                .onAppear {
                                                    if route.routeID == viewModel.routes.last?.routeID {
                                                        if let regionID = locationManager.regionID, viewModel.nextCursor != nil {
                                                            viewModel.queryRoutes(with: regionID, reset: false)
                                                        }
                                                    }
                                                }
                                        }
                                        if viewModel.isLoading {
                                            ProgressView()
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.top, 5)
                            .padding(.bottom, 10)
                        }
                        .frame(height: 300)
                    }
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(12)
                    
                    // 使用 MapPreviewRepresentable 展示当前选中 route 的详细路线
                    if let route = viewModel.selectedRoute {
                        if !locationManager.regionBoundary.isEmpty {
                            ZStack {
                                MapPreviewRepresentable(routePoints: route.routePoints, polygons: locationManager.regionBoundary, needParse: true)
                                    .frame(height: 200)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .circular)
                                            .stroke(Color.orange, lineWidth: 1)
                                    )
                                    .disabled(true)
                                Rectangle()
                                    .fill(Color.clear)
                                    .contentShape(Rectangle())
                                    .exclusiveTouchTapGesture {
                                        showFullMap.toggle()
                                    }
                            }
                        } else {
                            ZStack {
                                Rectangle()
                                    .frame(height: 200)
                                    .foregroundStyle(Color.gray.opacity(0.5))
                                    .cornerRadius(12)
                                Text("地理信息错误，请切换区域重试")
                                    .foregroundStyle(Color.thirdText)
                            }
                        }
                        
                        // 详细信息视图
                        VStack(alignment: .leading, spacing: 10) {
                            // 赛道标题
                            HStack {
                                Text("training.route.info")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .lineLimit(1)
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                HStack {
                                    Text("competition.track.leaderboard")
                                    Image(systemName: "chevron.right")
                                }
                                .font(.subheadline)
                                .exclusiveTouchTapGesture {
                                    navigationManager.append(.runningRouteRankListView(routeID: route.routeID, isPremium: route.isPremium))
                                }
                            }
                            
                            Divider()
                            
                            // 赛道详细信息
                            let infoItems: [(icon: String, text: String, value: String, unit: String?, isSysIcon: Bool)] = [
                                (route.routeType.icon, "training.route.mode", route.routeType.displayName, nil, false),
                                ("terrain", "competition.track.terrain", route.terrainType.displayName, nil, false),
                                (route.elevationDiff >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill", "competition.track.altitude", "\(route.elevationDiff)", "distance.m", true),
                                ("total_distance", "competition.track.distance", DistanceHelper.paceString(from: route.totalDistance), nil, false)
                            ]
                            HStack(alignment: .top) {
                                Spacer()
                                VStack(alignment: .leading, spacing: 10) {
                                    ForEach(0..<infoItems.count, id: \.self) { index in
                                        if index <= (infoItems.count - 1) / 2 {
                                            InfoItemView(
                                                iconName: infoItems[index].icon,
                                                text: infoItems[index].text,
                                                param: infoItems[index].value,
                                                unit: infoItems[index].unit,
                                                isSysIcon: infoItems[index].isSysIcon
                                            )
                                        }
                                    }
                                }
                                Spacer()
                                VStack(alignment: .leading, spacing: 10) {
                                    ForEach(0..<infoItems.count, id: \.self) { index in
                                        if index > (infoItems.count - 1) / 2 {
                                            InfoItemView(
                                                iconName: infoItems[index].icon,
                                                text: infoItems[index].text,
                                                param: infoItems[index].value,
                                                unit: infoItems[index].unit,
                                                isSysIcon: infoItems[index].isSysIcon
                                            )
                                        }
                                    }
                                    Spacer()
                                }
                                Spacer()
                            }
                            .padding(.vertical, 6)
                        }
                        .padding()
                        .background(Color.black.opacity(0.2))
                        .cornerRadius(20)
                    }
                }
                .padding(10)
                .padding(.bottom, 170)
            }
            .scrollIndicators(.hidden)
            
            HStack {
                Button(action: {
                    guard userManager.isLoggedIn else {
                        userManager.showingLogin = true
                        return
                    }
                    guard let route = viewModel.selectedRoute else { return }
                    competitionManager.resetRunningRouteEnv(route: route.toEnv())
                    navigationManager.append(.competitionCardSelectView)
                }) {
                    Text("training.action.ready")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.vertical, 15)
                        .frame(maxWidth: .infinity)
                        .background(
                            Capsule()
                                .fill((viewModel.selectedRoute == nil || competitionManager.isRecording) ? Color.gray : Color.orange)
                        )
                }
                .disabled(viewModel.selectedRoute == nil || competitionManager.isRecording)
                Button(action: {
                    guard userManager.isLoggedIn else {
                        userManager.showingLogin = true
                        return
                    }
                    navigationManager.append(.runningRouteCreateView)
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(15)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.3))
                        )
                }
                .disabled(competitionManager.isRecording)
            }
            .padding(10)
            .background(Color.defaultBackground)
            .padding(.bottom, 85)
        }
        .ignoresSafeArea(edges: .bottom)
        .fullScreenCover(isPresented: $showFullMap) {
            if let route = viewModel.selectedRoute {
                FullScreenRouteMapView(showMap: $showFullMap, routePoints: route.routePoints)
            }
        }
        .onFirstAppear {
            if let regionID = locationManager.regionID {
                viewModel.queryRoutes(with: regionID, reset: true)
            }
        }
        .onValueChange(of: locationManager.regionID) { _, newState in
            if let regionID = newState {
                viewModel.queryRoutes(with: regionID, reset: true)
            }
        }
    }
}

class RunningRouteTrainingViewModel: ObservableObject {
    @Published var routes: [RunningRouteItem] = []
    @Published var nextCursor: String? = nil
    @Published var sortType: RouteSortType = .participation
    @Published var selectedRoute: RunningRouteItem?
    
    @Published var isLoading = false
    @Published var isResetLoading = false
    
    
    func queryRoutes(with regionID: String, reset: Bool = true) {
        guard !isLoading, let loc = LocationManager.shared.getLocation() else { return }
        
        if reset {
            routes = []
            nextCursor = nil
            isResetLoading = true
        }
        
        isLoading = true
        
        var query: [String: String] = [
            "region_id": regionID,
            "sort_type": sortType.rawValue,
            "limit": "10",
            "lat": "\(loc.coordinate.latitude)",
            "lng": "\(loc.coordinate.longitude)"
        ]
        
        if let cursor = nextCursor {
            query["cursor"] = cursor
        }
        
        var components = URLComponents(string: "/training/running/routes")
        components?.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        guard let urlPath = components?.url?.absoluteString else { return }
        
        let request = APIRequest(path: urlPath, method: .get)
        
        NetworkService.sendRequest(with: request, decodingType: RunningRouteInfoResponse.self, showErrorToast: true) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                self.isResetLoading = false
                switch result {
                case .success(let data):
                    if let data {
                        var tempRoutes: [RunningRouteItem] = []
                        for route in data.routes {
                            tempRoutes.append(RunningRouteItem(from: route))
                        }
                        if reset {
                            self.routes = tempRoutes
                            self.selectedRoute = self.routes.first
                        } else {
                            self.routes.append(contentsOf: tempRoutes)
                        }
                        self.nextCursor = data.next_cursor
                    }
                default:
                    break
                }
            }
        }
    }
}

struct RunningRouteManageCardView: View {
    @EnvironmentObject var appState: AppState
    let route: RunningRouteManageItem
    var onDeleteSuccess: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(route.title)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
                Image(systemName: route.isPublic ? "eye" : "eye.slash")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.white)
            }
            Rectangle()
                .foregroundStyle(Color.gray)
                .frame(height: 1)
            HStack(spacing: 4) {
                Image(route.routeType.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 16)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 5)
                    .background(Color.white.opacity(0.3))
                    .cornerRadius(4)
                Image(route.isPremium ? "leaderboard_premium" : "leaderboard")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 16)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 5)
                    .background(Color.white.opacity(0.3))
                    .cornerRadius(4)
                if route.enableMagicCard {
                    Image("magiccard")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 16)
                        .padding(.vertical, 3)
                        .padding(.horizontal, 5)
                        .background(Color.white.opacity(0.3))
                        .cornerRadius(4)
                }
                Spacer()
                HStack(spacing: 4) {
                    Text("competition.track.leaderboard")
                    Image(systemName: "chevron.right")
                }
                .font(.system(size: 15))
                .exclusiveTouchTapGesture {
                    appState.navigationManager.append(.runningRouteRankListView(routeID: route.routeID, isPremium: route.isPremium))
                }
            }
            Rectangle()
                .foregroundStyle(Color.gray)
                .frame(height: 1)
            HStack {
                Button(action: {
                    appState.competitionManager.resetRunningRouteEnv(route: route.toEnv())
                    appState.navigationManager.append(.competitionCardSelectView)
                }) {
                   Text("training.action.ready")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.white)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 10)
                        .background(
                            Capsule()
                                .fill(appState.competitionManager.isRecording ? Color.gray : Color.orange.opacity(0.6))
                        )
                }
                .disabled(appState.competitionManager.isRecording)
                Spacer()
                /*if !route.isPublic {
                    Button(action: {
                        
                    }) {
                       Text("edit")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.white)
                            .padding(.vertical, 5)
                            .padding(.horizontal, 10)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.3))
                            )
                    }
                }*/
                Button(action: {
                    PopupWindowManager.shared.presentPopup(
                        title: "training.route.delete.title",
                        message: "training.route.delete.content",
                        bottomButtons: [
                            .cancel(),
                            .confirm() {
                                deleteRoute()
                            }
                        ]
                    )
                }) {
                   Image(systemName: "trash")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.white)
                        .padding(5)
                        .background(Color.red.opacity(0.6))
                        .clipShape(Circle())
                }
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.3))
        .cornerRadius(12)
    }
    
    func deleteRoute() {
        guard var components = URLComponents(string: "/training/running/routes/delete") else { return }
        components.queryItems = [
            URLQueryItem(name: "route_id", value: route.routeID)
        ]
        guard let urlPath = components.string else { return }
        let request = APIRequest(path: urlPath, method: .post, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: EmptyResponse.self, showLoadingToast: true, showErrorToast: true) { result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    onDeleteSuccess(route.routeID)
                }
            default:
                break
            }
        }
    }
}

struct RunningRouteManageView: View {
    @EnvironmentObject var appState: AppState
    @State private var routes: [RunningRouteManageItem] = []
    @State private var hasMore: Bool = false
    @State private var isLoading: Bool = false
    @State private var page: Int = 1
    let pageSize: Int = 10
    
    var body: some View {
        VStack {
            HStack {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .exclusiveTouchTapGesture {
                        appState.navigationManager.removeLast()
                    }
                Spacer()
                HStack(spacing: 4) {
                    Image("running")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20)
                    Text("training.route.manage")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
                Spacer()
                Image(systemName: "chevron.left")
                    .opacity(0)
            }
            .padding(.horizontal)
            ScrollView {
                LazyVStack {
                    if routes.isEmpty {
                        VStack {
                            Image("no_data")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 60)
                            Text("error.nothing_here")
                                .foregroundStyle(Color.thirdText)
                        }
                        .padding(.top, 100)
                    } else {
                        ForEach(routes) { route in
                            RunningRouteManageCardView(
                                route: route,
                                onDeleteSuccess: { routeID in
                                    routes.removeAll { $0.routeID == routeID }
                                }
                            )
                            .onAppear {
                                if route.id == routes.last?.id && hasMore {
                                    queryRoutes(reset: false)
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
            }
        }
        .background(Color.defaultBackground)
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBackGesture()
        .onFirstAppear {
            queryRoutes(reset: true)
        }
    }
    
    func queryRoutes(reset: Bool) {
        if reset {
            page = 1
        }
        isLoading = true
        guard var components = URLComponents(string: "/training/running/routes/my") else { return }
        components.queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "size", value: "\(pageSize)")
        ]
        guard let urlPath = components.string else { return }
        
        let request = APIRequest(path: urlPath, method: .get, requiresAuth: true)
        NetworkService.sendRequest(with: request, decodingType: RunningRouteManageInfoResponse.self, showLoadingToast: reset) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let data):
                    guard let unwrappedData = data else { return }
                    var tempRoutes: [RunningRouteManageItem] = []
                    for route in unwrappedData.routes {
                        tempRoutes.append(RunningRouteManageItem(from: route))
                    }
                    if reset {
                        routes = tempRoutes
                    } else {
                        routes.append(contentsOf: tempRoutes)
                    }
                    if unwrappedData.routes.count < self.pageSize {
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
}

struct RunningRouteCardView: View {
    let route: RunningRouteItem
    let sortType: RouteSortType
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(route.title)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
                HStack(spacing: 4) {
                    if sortType == .distance {
                        Image("location")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20)
                        Text(DistanceHelper.paceString(from: route.distance / 1000))
                    } else {
                        Image(systemName: "person")
                        Text("\(route.participateCount)")
                    }
                }
                .font(.system(size: 15))
            }
            HStack(spacing: 4) {
                HStack(spacing: 2) {
                    if sortType == .distance {
                        Image(systemName: "person")
                        Text("\(route.participateCount)")
                            .font(.caption)
                    } else {
                        Image("location")
                            .resizable()
                            .scaledToFit()
                        Text(DistanceHelper.paceString(from: route.distance / 1000))
                            .font(.caption)
                    }
                }
                .frame(height: 16)
                .padding(.vertical, 3)
                .padding(.horizontal, 5)
                .background(Color.white.opacity(0.3))
                .cornerRadius(4)
                Image(route.routeType.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 16)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 5)
                    .background(Color.white.opacity(0.3))
                    .cornerRadius(4)
                Image(route.isPremium ? "leaderboard_premium" : "leaderboard")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 16)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 5)
                    .background(Color.white.opacity(0.3))
                    .cornerRadius(4)
                if route.enableMagicCard {
                    Image("magiccard")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 16)
                        .padding(.vertical, 3)
                        .padding(.horizontal, 5)
                        .background(Color.white.opacity(0.3))
                        .cornerRadius(4)
                }
            }
        }
        .padding(10)
    }
}

struct RunningRouteItem: Identifiable {
    var id: String { routeID }
    let routeID: String
    let title: String
    let routeType: RouteType
    let terrainType: RunningTrackTerrainType
    let isPremium: Bool
    let enableMagicCard: Bool
    let distance: Double
    let totalDistance: Double
    let elevationDiff: Int
    let participateCount: Int
    let routePoints: [RoutePoint]
    
    init(from dto: RunningRouteInfo) {
        self.routeID = dto.route_id
        self.title = dto.title
        self.routeType = dto.route_type
        self.terrainType = dto.terrain_type
        self.isPremium = dto.is_premium
        self.enableMagicCard = dto.enable_magiccard
        self.distance = dto.distance
        self.totalDistance = dto.total_distance
        self.elevationDiff = dto.elevation_diff
        self.participateCount = dto.participate_count
        
        var parsed: [RoutePoint] = []
        
        if let steps = dto.route_data["steps"]?.arrayValue {
            for step in steps {
                guard let kind = step["kind"]?.stringValue else { continue }
                
                if kind == "checkpoint" {
                    if let lat = step["lat"]?.doubleValue,
                       let lng = step["lng"]?.doubleValue,
                       let radius = step["radius"]?.doubleValue {
                        let penalty = step["penalty"]?.intValue
                        let checkpoint = Checkpoint(
                            lat: lat,
                            lng: lng,
                            radius: radius,
                            penalty: penalty
                        )
                        parsed.append(.checkpoint(checkpoint))
                    }
                }
                
                if kind == "segment" {
                    if let pointsArray = step["points"]?.arrayValue {
                        var coords: [CLLocationCoordinate2D] = []
                        
                        for p in pointsArray {
                            if let pair = p.arrayValue,
                               pair.count == 2,
                               let lat = pair[0].doubleValue,
                               let lng = pair[1].doubleValue {
                                coords.append(CLLocationCoordinate2D(latitude: lat, longitude: lng))
                            }
                        }
                        
                        let width = step["width"]?.doubleValue ?? 5
                        
                        let segment = Segment(
                            points: coords,
                            width: width
                        )
                        parsed.append(.segment(segment))
                    }
                }
            }
        }
        self.routePoints = parsed
    }
    
    func toEnv() -> RunningRouteEnv {
        return RunningRouteEnv(
            routeID: routeID,
            title: title,
            enableMagicCard: enableMagicCard,
            routeType: routeType,
            routePoints: routePoints.toRealtimePoints()
        )
    }
}

struct RunningRouteManageItem: Identifiable {
    var id: String { routeID }
    let routeID: String
    let title: String
    let isPublic: Bool
    let routeType: RouteType
    let terrainType: RunningTrackTerrainType
    let isPremium: Bool
    let enableMagicCard: Bool
    let routePoints: [RoutePoint]
    
    init(from dto: RunningRouteManageInfo) {
        self.routeID = dto.route_id
        self.title = dto.title
        self.isPublic = dto.is_public
        self.routeType = dto.route_type
        self.terrainType = dto.terrain_type
        self.isPremium = dto.is_premium
        self.enableMagicCard = dto.enable_magiccard
        
        var parsed: [RoutePoint] = []
        
        if let steps = dto.route_data["steps"]?.arrayValue {
            for step in steps {
                guard let kind = step["kind"]?.stringValue else { continue }
                
                if kind == "checkpoint" {
                    if let lat = step["lat"]?.doubleValue,
                       let lng = step["lng"]?.doubleValue,
                       let radius = step["radius"]?.doubleValue {
                        let penalty = step["penalty"]?.intValue
                        let checkpoint = Checkpoint(
                            lat: lat,
                            lng: lng,
                            radius: radius,
                            penalty: penalty
                        )
                        parsed.append(.checkpoint(checkpoint))
                    }
                }
                
                if kind == "segment" {
                    if let pointsArray = step["points"]?.arrayValue {
                        var coords: [CLLocationCoordinate2D] = []
                        
                        for p in pointsArray {
                            if let pair = p.arrayValue,
                               pair.count == 2,
                               let lat = pair[0].doubleValue,
                               let lng = pair[1].doubleValue {
                                coords.append(CLLocationCoordinate2D(latitude: lat, longitude: lng))
                            }
                        }
                        
                        let width = step["width"]?.doubleValue ?? 5
                        
                        let segment = Segment(
                            points: coords,
                            width: width
                        )
                        parsed.append(.segment(segment))
                    }
                }
            }
        }
        self.routePoints = parsed
    }
    
    func toEnv() -> RunningRouteEnv {
        return RunningRouteEnv(
            routeID: routeID,
            title: title,
            enableMagicCard: enableMagicCard,
            routeType: routeType,
            routePoints: routePoints.toRealtimePoints()
        )
    }
}

struct RunningRouteManageInfo: Codable {
    let route_id: String
    let title: String
    let is_public: Bool
    let route_type: RouteType
    let terrain_type: RunningTrackTerrainType
    let is_premium: Bool
    let enable_magiccard: Bool
    let route_data: JSONValue
}

struct RunningRouteManageInfoResponse: Codable {
    let routes: [RunningRouteManageInfo]
}

struct RunningRouteInfo: Codable {
    let route_id: String
    let title: String
    let route_type: RouteType
    let terrain_type: RunningTrackTerrainType
    let is_premium: Bool
    let enable_magiccard: Bool
    let distance: Double
    let total_distance: Double
    let elevation_diff: Int
    let participate_count: Int
    let route_data: JSONValue
}

struct RunningRouteInfoResponse: Codable {
    let routes: [RunningRouteInfo]
    let next_cursor: String?
}

struct RunningRouteCreateView: View {
    @StateObject var store: RouteEditorStore = RouteEditorStore()
    @ObservedObject var navigationManager = NavigationManager.shared
    @ObservedObject var locationManager = LocationManager.shared
    @ObservedObject var userManager = UserManager.shared
    @State var title: String = ""
    @State var terrainType: RunningTrackTerrainType = .road
    @State var terrainTypeOnSelect: Bool = false
    @State var isPublic: Bool = true
    //@State var enableRankList: Bool = true
    @State var enableMagicCardSys: Bool = true
    @State var routeCardUrl: String?
    
    var routeDistance: Double {
        guard store.routePoints.count > 1 else { return 0 }
        
        var totalDistance: Double = 0
        
        for i in 0..<(store.routePoints.count - 1) {
            let p1 = store.routePoints[i].coordinate
            let p2 = store.routePoints[i + 1].coordinate
            
            let loc1 = CLLocation(latitude: p1.latitude, longitude: p1.longitude)
            let loc2 = CLLocation(latitude: p2.latitude, longitude: p2.longitude)
            
            totalDistance += loc1.distance(from: loc2)
        }
        
        // 转换为 km
        return totalDistance / 1000.0
    }
    

    init() {
        // iOS16 会多次调用，StateObject 不能放在 init 里初始化
        //let store = RouteEditorStore()
        //_store = StateObject(wrappedValue: store)
        //storeID = NavigationStoreManager.shared.register(store)
    }
    
    var body: some View {
        VStack {
            HStack {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .exclusiveTouchTapGesture {
                        navigationManager.removeLast()
                    }
                Spacer()
                HStack(spacing: 4) {
                    Image("running")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20)
                    Text("training.route.create")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
                Spacer()
                Image(systemName: "chevron.left")
                    .opacity(0)
            }
            .padding(.horizontal)
            
            ScrollView {
                VStack(spacing: 15) {
                    HStack {
                        Text("training.route.title")
                        Spacer()
                    }
                    TextField(text: $title) {
                        Text("training.route.title.enter")
                            .foregroundColor(.thirdText)
                    }
                    .padding()
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden) // 隐藏系统默认的背景
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .onValueChange(of: title) { _, newState in
                        DispatchQueue.main.async {
                            if newState.count > 20 {
                                title = String(title.prefix(20)) // 限制为最多20个字符
                            }
                        }
                    }
                    HStack {
                        Spacer()
                        Text("user.intro.words_entered \(title.count) \(20)")
                            .font(.footnote)
                            .foregroundStyle(Color.thirdText)
                    }
                    
                    if !locationManager.regionBoundary.isEmpty {
                        ZStack {
                            MapPreviewRepresentable(routePoints: store.routePoints.toRoutePoints(), polygons: locationManager.regionBoundary, needParse: false)
                                .frame(height: 200)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .circular)
                                        .stroke(Color.orange.opacity(0.5), lineWidth: 2)
                                )
                                .disabled(true)
                            Rectangle()
                                .fill(Color.clear)
                                .contentShape(Rectangle())
                                .exclusiveTouchTapGesture {
                                    store.tempSelectedType = store.selectedType
                                    store.tempRoutePoints = store.routePoints
                                    navigationManager.append(.routeEditorView(storeID: store.id))
                                }
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    Text("training.route.edit_on_tap")
                                    Spacer()
                                }
                                .foregroundStyle(Color.thirdText)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    Color.black.opacity(0.7),
                                                    Color.black.opacity(0)
                                                ]),
                                                startPoint: .bottom,
                                                endPoint: .top
                                            )
                                        )
                                )
                            }
                        }
                    } else {
                        ZStack {
                            Rectangle()
                                .frame(height: 200)
                                .foregroundStyle(Color.gray.opacity(0.5))
                                .cornerRadius(12)
                            Text("error.region")
                                .foregroundStyle(Color.white)
                        }
                    }
                    
                    HStack {
                        Text("training.route.mode") + Text(":")
                        Spacer()
                        Text(LocalizedStringKey(store.selectedType.displayName))
                    }
                    
                    HStack {
                        Text("competition.track.sub_region") + Text(":")
                        Spacer()
                        Text(locationManager.regionName ?? "-")
                    }
                    
                    HStack {
                        Text("competition.track.terrain") + Text(":")
                        Spacer()
                        if terrainTypeOnSelect {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(RunningTrackTerrainType.allCases, id: \.self) { type in
                                        Text(LocalizedStringKey(type.displayName))
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(terrainType == type ? Color.white : Color.thirdText)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                Capsule()
                                                    .fill(terrainType == type ? Color.orange : Color.secondBackground)
                                            )
                                            .exclusiveTouchTapGesture {
                                                terrainType = type
                                                terrainTypeOnSelect.toggle()
                                            }
                                    }
                                }
                            }
                            .frame(width: 200)
                        } else {
                            HStack(spacing: 4) {
                                Text(LocalizedStringKey(terrainType.displayName))
                                    .foregroundStyle(Color.white)
                                    .font(.system(size: 13, weight: .medium))
                                Image(systemName: "arrow.left.arrow.right")
                                    .foregroundStyle(Color.secondText)
                                    .font(.system(size: 10, weight: .light))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.defaultBackground)
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.orange, lineWidth: 2)
                                    )
                            )
                            .exclusiveTouchTapGesture {
                                terrainTypeOnSelect.toggle()
                            }
                        }
                    }
                    
                    HStack {
                        Text("competition.track.distance") + Text(":")
                        Spacer()
                        if store.routePoints.count > 1 {
                            Text(DistanceHelper.paceString(from: routeDistance))
                            if routeDistance > 50 {
                                (Text("(") + Text("training.route.distance \(50)") + Text(")"))
                                    .foregroundStyle(Color.pink)
                                    .font(.system(size: 15))
                            } else if routeDistance < 0.1 {
                                (Text("(") + Text("training.route.distance.less \(100)") + Text(")"))
                                    .foregroundStyle(Color.pink)
                                    .font(.system(size: 15))
                            }
                        } else {
                            Text("-")
                        }
                    }
                    
                    HStack {
                        Text("competition.track.altitude") + Text(":")
                        Spacer()
                        if store.isLoadingElevation {
                            ProgressView()
                        } else if let diff = store.routeElevationDiff {
                            Image(systemName: diff > 0 ? "triangle.fill" : "arrowtriangle.down.fill")
                            Text("\(abs(diff)) m")
                        } else {
                            Text("-")
                        }
                    }
                    
                    HStack {
                        HStack(spacing: 4) {
                            Text("training.route.is_public") + Text(":")
                            Image(systemName: "info.circle")
                                .font(.subheadline)
                                .exclusiveTouchTapGesture {
                                    PopupWindowManager.shared.presentPopup(
                                        title: "training.route.is_public",
                                        message: "training.route.is_public.content",
                                        bottomButtons: [
                                            .confirm()
                                        ]
                                    )
                                }
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { isPublic },
                            set: { newValue in
                                isPublic = newValue
                                enableMagicCardSys = enableMagicCardSys && newValue
                            }
                        ))
                        .tint(.orange)
                        .labelsHidden()
                    }
                    
                    HStack {
                        Text("training.route.enable_leaderboard") + Text(":")
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { isPublic },
                            set: { newValue in
                                return
                            }
                        ))
                        .tint(.gray)
                        .labelsHidden()
                    }
                    
                    if isPublic {
                        HStack(spacing: 10) {
                            HStack(spacing: 4) {
                                Text("common.total")
                                    .font(.system(size: 12, weight: .medium))
                                if !userManager.user.isVip {
                                    HStack(spacing: 0) {
                                        Image(systemName: "person")
                                        Text("100")
                                    }
                                    .font(.system(size: 12))
                                    .padding(.vertical, 2)
                                    .padding(.horizontal, 6)
                                    .background(Color.gray)
                                    .clipShape(Capsule())
                                }
                            }
                            .padding(.vertical, userManager.user.isVip ? 4 : 2)
                            .padding(.leading, 8)
                            .padding(.trailing, userManager.user.isVip ? 8 : 2)
                            .background(Color.orange)
                            .clipShape(Capsule())
                            
                            ZStack {
                                Text("common.male")
                                    .font(.system(size: 12, weight: .medium))
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(userManager.user.isVip ? Color.orange : Color.gray)
                                    .clipShape(Capsule())
                                if !userManager.user.isVip {
                                    Image(systemName: "nosign")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(Color.pink.opacity(0.5))
                                }
                            }
                            
                            ZStack {
                                Text("common.female")
                                    .font(.system(size: 12, weight: .medium))
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(userManager.user.isVip ? Color.orange : Color.gray)
                                    .clipShape(Capsule())
                                if !userManager.user.isVip {
                                    Image(systemName: "nosign")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(Color.pink.opacity(0.5))
                                }
                            }
                            
                            Spacer()
                            
                            if !userManager.user.isVip {
                                HStack(spacing: 4) {
                                    Text("training.route.unlock_leaderboard")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(Color.secondText)
                                    Image("vip_icon_on")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 15)
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                                .exclusiveTouchTapGesture {
                                    guard userManager.isLoggedIn else {
                                        userManager.showingLogin = true
                                        return
                                    }
                                    navigationManager.append(.subscriptionDetailView)
                                }
                            }
                        }
                    }
                    
                    HStack {
                        Text("training.route.enable_magiccard") + Text(":")
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { enableMagicCardSys },
                            set: { newValue in
                                guard isPublic else { return }
                                enableMagicCardSys = newValue
                            }
                        ))
                        .tint(isPublic ? .orange : .gray)
                        .labelsHidden()
                    }
                    
                    let isDisabled = title.isEmpty
                    || (store.routeElevationDiff == nil)
                    || (locationManager.regionID == nil)
                    || routeDistance > 50
                    || routeDistance < 0.1
                    Button(action: {
                        PopupWindowManager.shared.presentPopup(
                            title: "training.route.create",
                            message: "training.route.create.content",
                            bottomButtons: [
                                .cancel(),
                                .confirm() {
                                    createRoute()
                                }
                            ]
                        )
                    }) {
                        HStack(spacing: 10) {
                            Text("action.create")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            if let url = routeCardUrl {
                                CachedAsyncImage(urlString: url)
                                    .aspectRatio(contentMode: .fit)
                                    .frame(height: 30)
                                    .clipped()
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(isDisabled ? Color.gray : Color.orange)
                        )
                    }
                    .padding(.top, 10)
                    .disabled(isDisabled)
                }
                .padding()
                .foregroundStyle(Color.white)
            }
            .scrollIndicators(.hidden)
        }
        .background(Color.defaultBackground)
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBackGesture()
        .hideKeyboardOnTap()
        .ignoresSafeArea(.keyboard)
        .onFirstAppear {
            queryRouteCardInfo()
        }
    }
    
    func queryRouteCardInfo() {
        guard let components = URLComponents(string: "/training/running/route_card_info") else { return }
        guard let urlPath = components.string else { return }
        
        let request = APIRequest(path: urlPath, method: .get)
        NetworkService.sendRequest(with: request, decodingType: CPAssetCoverInfo.self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    if let unwrappedData = data {
                        self.routeCardUrl = unwrappedData.image_url
                    }
                default: break
                }
            }
        }
    }
    
    func createRoute() {
        guard let regionID = locationManager.regionID, store.routePoints.count > 1 else { return }
        
        let routeData = buildRouteData()
        let body: [String: Any] = [
            "title": title,
            "region_id": regionID,
            "terrain_type": terrainType.rawValue,
            "is_public": isPublic,
            "enable_magiccard": enableMagicCardSys,
            "enable_ranklist": isPublic,
            "route_type": store.selectedType.rawValue,
            "route_data": routeData
        ]
        
        guard let encodedBody = try? JSONSerialization.data(withJSONObject: body) else { return }
        
        var headers: [String: String] = [:]
        headers["Content-Type"] = "application/json"
        
        let request = APIRequest(path: "/training/running/create_route", method: .post, headers: headers, body: encodedBody, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: CPAssetResponse.self, showLoadingToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                guard let data else { return }
                DispatchQueue.main.async {
                    ToastManager.shared.show(toast: Toast(message: "toast.created.success"))
                    navigationManager.removeLast()
                    AssetManager.shared.updateCPAsset(assetID: data.asset_id, newBalance: data.new_balance)
                }
            default:
                break
            }
        }
    }
    
    func buildRouteData() -> [String: Any] {
        var steps: [[String: Any]] = []
        for point in store.routePoints {
            var coord = CLLocationCoordinate2D(latitude: point.coordinate.latitude, longitude: point.coordinate.longitude)
            
            if !CoordinateConverter.outOfChina(coordinate: coord) {
                coord = CoordinateConverter.gcj02ToWgs84(lat: coord.latitude, lon: coord.longitude)
            }
            var step: [String: Any] = [
                "kind": "checkpoint",
                "lat": coord.latitude,
                "lng": coord.longitude,
                "radius": point.radius
            ]
            if let penalty = point.penalty {
                step["penalty"] = penalty
            }
            steps.append(step)
        }
        return [
            "type": store.selectedType.rawValue,
            "steps": steps
        ]
    }
}

struct RunningRouteEnv {
    let routeID: String
    let title: String
    let enableMagicCard: Bool
    let routeType: RouteType
    var routePoints: [RoutePointRealtime]
}
