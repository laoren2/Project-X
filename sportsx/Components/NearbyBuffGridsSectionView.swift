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
    let condition_params: JSONValue
    let reward_type: String
    let reward_count: Int

    var id: String { "\(grid_x)_\(grid_y)" }
}

struct NearbyBuffGridsResponse: Codable {
    let grids: [NearbyBuffGridDTO]
}

struct GridOccupancyResponse: Codable {
    let occupied_count: Int
    let rank: Int?
}


struct NearbyBuffGridsSectionView: View {
    let sport: SportName
    // 外层（FreeTrainingView）统一消费 refreshFreeTrainingView 刷新信号后递增此值，驱动本 section 重拉。
    let refreshToken: Int
    // bike/running 自由训练页共用的区域排行榜入口。
    let onOpenOccupiedRankList: (String) -> Void

    @ObservedObject var locationManager = LocationManager.shared
    @ObservedObject var userManager = UserManager.shared

    @State private var distance: NearbyDistanceOption = .km10
    @State private var grids: [NearbyBuffGridDTO] = []
    @State private var selected: NearbyBuffGridDTO? = nil
    @State private var occupiedCount: Int = 0
    @State private var occupiedRank: Int? = nil
    @State private var isLoading: Bool = true
    @State private var didLoad: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题栏：左侧已占领徽标 + 标题，右侧距离选择器
            HStack(spacing: 8) {
                Text("training.free.nearby.title")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.white)

                occupancyBadge

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

                Spacer()

                CapsuleScrollSelector(
                    options: NearbyDistanceOption.allCases,
                    selection: $distance,
                    titleKey: { $0.titleKey },
                    expandedWidth: 150,
                    backgroundColor: Color.black.opacity(0.2),
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
            // 首次加载：section 自行拉取；后续的训练结束等刷新由外层通过 refreshToken 驱动
            if !didLoad {
                fetchGrids()
                fetchOccupiedCount()
            }
            DispatchQueue.main.async { didLoad = true }
        }
        .onValueChange(of: refreshToken) { _, _ in
            guard userManager.isLoggedIn else { return }
            fetchGrids()
            fetchOccupiedCount()
        }
        .onValueChange(of: locationManager.regionID) { _, _ in
            guard userManager.isLoggedIn else { return }
            // nearby grids 以当前 GPS 坐标为查询依据，不受手动选择 region 影响。
            fetchOccupiedCount()
        }
        .onValueChange(of: userManager.isLoggedIn) { _, newValue in
            if newValue {
                fetchGrids()
                fetchOccupiedCount()
            } else {
                grids = []
                selected = nil
                occupiedCount = 0
                occupiedRank = nil
            }
        }
    }

    // MARK: - 子视图

    private var occupancyBadge: some View {
        Button {
            guard let regionID = locationManager.regionID else { return }
            onOpenOccupiedRankList(regionID)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "crown")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.orange)
                Text("\(occupiedCount)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .padding(.trailing, 4)
                if let occupiedRank {
                    Text("#\(occupiedRank)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white)
                } else {
                    Text("#-")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.thirdText)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.secondText)
            }
            .foregroundStyle(Color.white)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(Capsule().fill(Color.white.opacity(0.15)))
        }
        .buttonStyle(.plain)
    }

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
            if let badge = conditionBadge(for: grid) {
                GridConditionBadgeImage(badge: badge)
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
                    if let badge = conditionBadge(for: grid) {
                        GridConditionBadgeImage(badge: badge)
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
                    items: richTextItems(for: grid, rewardIconName: iconName),
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

    private func conditionBadge(for grid: NearbyBuffGridDTO) -> GridConditionBadge? {
        GridConditionPresentation.badge(
            conditionType: grid.condition_type,
            conditionParams: grid.condition_params
        )
    }

    private func richTextItems(for grid: NearbyBuffGridDTO, rewardIconName: String) -> [(String, RichTextItem)] {
        var items: [(String, RichTextItem)] = [
            ("reward", .image(rewardIconName, width: 20)),
            ("reward", .text(" * \(grid.reward_count)"))
        ]
        if grid.condition_type == "weather" {
            let symbolName = WeatherConditionIcon.symbolName(for: grid.condition_params["match"]?.stringValue)
            items.append(("weather", .systemSymbol(symbolName, width: 18)))
        }
        return items
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
        guard userManager.isLoggedIn, let regionID = locationManager.regionID else {
            occupiedCount = 0
            occupiedRank = nil
            return
        }
        var components = URLComponents(string: "/training/\(sport.rawValue)/query_occupied_grids_count")
        components?.queryItems = [URLQueryItem(name: "region_id", value: regionID)]
        guard let urlPath = components?.string else { return }

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
                    // 切换 region 时旧请求可能晚返回，不能覆盖新 region 的统计。
                    guard locationManager.regionID == regionID else { return }
                    if let data {
                        occupiedCount = data.occupied_count
                        occupiedRank = data.rank
                    }
                default:
                    break
                }
            }
        }
    }
}
