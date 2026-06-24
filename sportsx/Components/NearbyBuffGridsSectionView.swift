//
//  NearbyBuffGridsSectionView.swift
//  sportsx
//
//  自由训练页：momentum 与地图之间的「附近 buff 网格」区块。
//  - 标题栏左侧用徽标展示用户当前赛季已占领的网格数，右侧用 CapsuleScrollSelector 选择距离档位
//  - 横向滚动展示所选距离内、当天还能领取的 buff 网格紧凑卡片（复用结算页的 ZStack 角标设计）
//  - 点击卡片选中并在下方展示完整说明
//  bike/running 共用，传入 sport 区分接口路径与图标。
//

import SwiftUI
import CoreLocation


// 距离档位（米），CapsuleScrollSelector 的 titleKey 不支持插值，故用离散本地化 key
enum NearbyDistanceOption: Hashable, CaseIterable {
    case km1, km5, km10, km20

    var meters: Double {
        switch self {
        case .km1: return 1000
        case .km5: return 5000
        case .km10: return 10000
        case .km20: return 20000
        }
    }

    var titleKey: String {
        switch self {
        case .km1: return "training.free.nearby.distance.1km"
        case .km5: return "training.free.nearby.distance.5km"
        case .km10: return "training.free.nearby.distance.10km"
        case .km20: return "training.free.nearby.distance.20km"
        }
    }
}

// 附近 buff 网格（仅解码卡片/详情所需字段，多余字段 Codable 自动忽略）
struct NearbyBuffGridDTO: Codable, Identifiable {
    let grid_x: Int
    let grid_y: Int
    let center_lat: Double
    let center_lon: Double
    let description: String
    let condition_type: String
    let reward_type: String
    let reward_count: Int

    var id: String { "\(grid_x)_\(grid_y)" }
}

struct NearbyBuffGridsResponse: Codable {
    let grids: [NearbyBuffGridDTO]
}

struct GridOccupancyResponse: Codable {
    let occupied_count: Int
}


struct NearbyBuffGridsSectionView: View {
    let sport: SportName

    @ObservedObject var locationManager = LocationManager.shared
    @ObservedObject var userManager = UserManager.shared

    @State private var distance: NearbyDistanceOption = .km10
    @State private var grids: [NearbyBuffGridDTO] = []
    @State private var selected: NearbyBuffGridDTO? = nil
    @State private var occupiedCount: Int = 0
    @State private var isLoading: Bool = true
    @State private var didLoad: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题栏：左侧已占领徽标 + 标题，右侧距离选择器
            HStack(spacing: 8) {
                Text("training.free.nearby.title")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.white)
                HStack(spacing: 4) {
                    Image(systemName: "crown")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.orange)
                    Text("\(occupiedCount)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.secondText)
                        .exclusiveTouchTapGesture {
                            PopupWindowManager.shared.presentPopup(
                                title: "training.free.nearby.occupied.title",
                                message: "training.free.nearby.occupied.description",
                                bottomButtons: [.confirm()]
                            )
                        }
                }
                .foregroundStyle(Color.white)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(
                    Capsule().fill(Color.white.opacity(0.15))
                )

                Spacer()

                CapsuleScrollSelector(
                    options: NearbyDistanceOption.allCases,
                    selection: $distance,
                    titleKey: { $0.titleKey },
                    expandedWidth: 150,
                    onSelect: { _ in
                        selected = nil
                        fetchGrids()
                    }
                )
            }

            // 内容区：无定位 / 加载骨架 / 空态 / 卡片横向列表
            if locationManager.getLocation() == nil {
                Text("training.free.nearby.no_location")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.thirdText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else if isLoading {
                skeletonRow
            } else if grids.isEmpty {
                Text("training.free.nearby.empty")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.thirdText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(grids) { grid in
                            gridTile(grid)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 2)
                }
            }

            // 选中详情
            if let selected {
                gridDetailCard(selected)
            }
        }
        .onStableAppear {
            guard userManager.isLoggedIn else { return }
            if !didLoad {
                fetchGrids()
                fetchOccupiedCount()
                DispatchQueue.main.async { didLoad = true }
            }
        }
        .onValueChange(of: locationManager.regionID) { _, _ in
            guard userManager.isLoggedIn else { return }
            fetchGrids()
        }
        .onValueChange(of: userManager.isLoggedIn) { _, newValue in
            if newValue {
                fetchGrids()
                fetchOccupiedCount()
            } else {
                grids = []
                selected = nil
                occupiedCount = 0
            }
        }
    }

    // MARK: - 子视图

    // 加载骨架：与卡片同尺寸的灰色占位块（风格对齐 FreeTrainingView 的 Color.gray.opacity(0.5)）
    private var skeletonRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(0..<10, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: 40, height: 40)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 2)
        }
    }

    // 紧凑卡片：reward 图标 + 右上角 condition 角标（复用结算页 ZStack 设计），选中态加亮
    private func gridTile(_ grid: NearbyBuffGridDTO) -> some View {
        let isSelected = selected?.id == grid.id
        return ZStack(alignment: .topTrailing) {
            if let iconName = rewardIconName(grid.reward_type) {
                Image(iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22)
            }
            if let badge = conditionBadgeName(grid.condition_type) {
                Image(badge)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 15)
                    .offset(x: 4, y: -4)
            }
        }
        .frame(width: 40, height: 40)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.orange.opacity(isSelected ? 0.35 : 0.2))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.orange.opacity(isSelected ? 1.0 : 0.8), lineWidth: isSelected ? 2.5 : 1.5)
        )
        .exclusiveTouchTapGesture {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            selected = isSelected ? nil : grid
        }
    }

    // 选中网格的完整说明：图标 + 富文本描述（含 reward）+ 距离
    private func gridDetailCard(_ grid: NearbyBuffGridDTO) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .bottom, spacing: 12) {
                ZStack(alignment: .topTrailing) {
                    if let iconName = rewardIconName(grid.reward_type) {
                        Image(iconName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20)
                    }
                    if let badge = conditionBadgeName(grid.condition_type) {
                        Image(badge)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 15)
                            .offset(x: 4, y: -4)
                    }
                }
                .frame(width: 35, height: 35)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.orange.opacity(0.2))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.orange.opacity(0.8), lineWidth: 1.5)
                )
                .fixedSize()
                
                if let distanceText = distanceText(to: grid) {
                    HStack(spacing: 4) {
                        Image("location")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 15, height: 15)
                        Text(distanceText)
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(Color.secondText)
                }
            }
            
            if let iconName = rewardIconName(grid.reward_type) {
                RichTextLabel(
                    templateKey: grid.description,
                    items: [
                        ("reward", .image(iconName, width: 20)),
                        ("reward", .text(" * \(grid.reward_count)"))
                    ],
                    font: .systemFont(ofSize: 15)
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.15))
        )
    }

    // MARK: - 辅助

    private func rewardIconName(_ rewardType: String) -> String? {
        CCAssetType(rawValue: rewardType)?.iconName
    }

    // condition_type 字符串 → 右上角角标图标：按运动解码到各自的条件枚举，
    // 便于后续不同运动设计不同的条件类型与角标映射。
    private func conditionBadgeName(_ conditionType: String) -> String? {
        switch sport {
        case .Bike:
            return BikeGridConditionType(rawValue: conditionType)?.badgeImageName
        case .Running, .Default:
            return RunningGridConditionType(rawValue: conditionType)?.badgeImageName
        case .Badminton:
            return nil
        }
    }

    private func distanceText(to grid: NearbyBuffGridDTO) -> String? {
        guard let loc = locationManager.getLocation() else { return nil }
        let d = GeographyTool.haversineDistance(
            lat1: loc.coordinate.latitude, lon1: loc.coordinate.longitude,
            lat2: grid.center_lat, lon2: grid.center_lon
        )
        if d >= 1000 {
            return String(format: "%.1f km", d / 1000)
        }
        return String(format: "%.0f m", d)
    }

    // MARK: - 网络

    private func fetchGrids() {
        guard userManager.isLoggedIn, let loc = locationManager.getLocation() else {
            grids = []
            selected = nil
            isLoading = false
            return
        }
        var components = URLComponents(string: "/training/\(sport.rawValue)/query_grids_within_distance")
        components?.queryItems = [
            URLQueryItem(name: "lat", value: "\(loc.coordinate.latitude)"),
            URLQueryItem(name: "lon", value: "\(loc.coordinate.longitude)"),
            URLQueryItem(name: "distance", value: "\(distance.meters)")
        ]
        guard let urlPath = components?.string else { return }

        let request = APIRequest(path: urlPath, method: .get, requiresAuth: true)
        isLoading = true
        NetworkService.sendRequest(
            with: request,
            decodingType: NearbyBuffGridsResponse.self,
            showLoadingToast: false,
            showErrorToast: true
        ) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let data):
                    grids = data?.grids ?? []
                    // 保留仍存在的选中项，否则清空详情
                    if let current = selected, !grids.contains(where: { $0.id == current.id }) {
                        selected = nil
                    }
                default:
                    break
                }
            }
        }
    }

    private func fetchOccupiedCount() {
        guard userManager.isLoggedIn else { return }
        guard let urlPath = URLComponents(string: "/training/\(sport.rawValue)/query_occupied_grids_count")?.string else { return }

        let request = APIRequest(path: urlPath, method: .get, requiresAuth: true)
        NetworkService.sendRequest(
            with: request,
            decodingType: GridOccupancyResponse.self,
            showLoadingToast: false,
            showErrorToast: false
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    if let data { occupiedCount = data.occupied_count }
                default:
                    break
                }
            }
        }
    }
}
