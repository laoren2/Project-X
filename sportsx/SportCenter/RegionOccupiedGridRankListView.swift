//
//  RegionOccupiedGridRankListView.swift
//  sportsx
//
//  当前赛季、当前 region 的基础网格占领排行榜（不区分性别）。
//

import SwiftUI


struct RegionGridOccupancyRankEntryDTO: Codable {
    let user: PersonInfoDTO
    let occupied_count: Int
    let rank: Int
}

struct RegionGridOccupancyRankMeDTO: Codable {
    let occupied_count: Int
    let rank: Int?
}

struct RegionGridOccupancyRankListDTO: Codable {
    let entries: [RegionGridOccupancyRankEntryDTO]
    let next_cursor: String?
    let me: RegionGridOccupancyRankMeDTO
}


struct RegionOccupiedGridRankListView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var userManager = UserManager.shared

    let sport: SportName
    let regionID: String

    @State private var entries: [RegionGridOccupancyRankEntryDTO] = []
    @State private var me = RegionGridOccupancyRankMeDTO(occupied_count: 0, rank: nil)
    @State private var nextCursor: String? = nil
    @State private var isLoading = false
    @State private var didLoad = false

    private var regionName: LocalizedStringKey {
        guard let region = RegionStore.index[regionID] else { return "error.region" }
        return LocalizedStringKey(region.regionName)
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                CommonIconButton(icon: "chevron.left") {
                    appState.navigationManager.removeLast()
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.white)

                Spacer()
                VStack(spacing: 2) {
                    Text("training.free.occupied.ranklist.title")
                        .font(.system(size: 18, weight: .bold))
                }
                Spacer()
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.clear)
            }
            
            HStack {
                Image("location")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20)
                Text(regionName)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.secondText)
            }

            myRankCard

            HStack {
                Text("competition.track.leaderboard.ranking")
                Text("common.user")
                Spacer()
                Text("training.free.occupied.ranklist.count")
            }
            .font(.subheadline)
            .foregroundStyle(Color.secondText)
            .padding(.horizontal, 4)

            ScrollView(showsIndicators: false) {
                if entries.isEmpty && !isLoading && didLoad {
                    VStack(spacing: 16) {
                        Image("no_data")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 60)
                        Text("training.free.occupied.ranklist.empty")
                            .foregroundStyle(Color.thirdText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(entries, id: \.user.user_id) { entry in
                            rankEntry(entry)
                                .onAppear {
                                    if entry.user.user_id == entries.last?.user.user_id {
                                        fetchNextPage()
                                    }
                                }
                        }
                        if isLoading {
                            ProgressView().padding()
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .background(Color.defaultBackground)
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBackGesture()
        .onStableAppear {
            guard !didLoad else { return }
            didLoad = true
            fetchRankList(reset: true)
        }
    }

    private var myRankCard: some View {
        HStack(spacing: 10) {
            Text(me.rank.map { "#\($0)" } ?? "#-")
                .font(.system(size: 21, weight: .bold, design: .rounded))
                .foregroundStyle(me.rank == nil ? Color.thirdText : Color.orange)
                .frame(minWidth: 36, alignment: .leading)
            CachedAsyncImage(urlString: userManager.user.avatarImageURL)
                .aspectRatio(contentMode: .fill)
                .frame(width: 46, height: 46)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text("common.me")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondText)
                if me.rank == nil {
                    Text("training.free.occupied.ranklist.unranked")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.white)
                } else {
                    Text("training.free.occupied.ranklist.count \(me.occupied_count)")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.white)
                }
            }
            Spacer()
            Image(systemName: "crown")
                .foregroundStyle(Color.orange)
        }
        .padding(10)
        .background(Color.gray.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .exclusiveTouchTapGesture {
            appState.navigationManager.append(.userView(id: userManager.user.userID))
        }
    }

    private func rankEntry(_ entry: RegionGridOccupancyRankEntryDTO) -> some View {
        HStack(spacing: 10) {
            Text("#\(entry.rank)")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(entry.rank == 1 ? Color.gold : Color.white)
                .frame(minWidth: 36, alignment: .leading)
            CachedAsyncImage(urlString: entry.user.avatar_image_url)
                .aspectRatio(contentMode: .fill)
                .frame(width: 46, height: 46)
                .clipShape(Circle())
            Text(entry.user.nickname)
                .foregroundStyle(Color.white)
                .lineLimit(1)
            if entry.rank == 1 {
                Image(systemName: "crown.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.orange)
            }
            Spacer()
            Text("\(entry.occupied_count)")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white)
        }
        .padding(10)
        .background(Color.white.opacity(0.16))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .exclusiveTouchTapGesture {
            appState.navigationManager.append(.userView(id: entry.user.user_id))
        }
    }

    private func fetchNextPage() {
        guard !isLoading, nextCursor != nil else { return }
        fetchRankList(reset: false)
    }

    private func fetchRankList(reset: Bool) {
        guard userManager.isLoggedIn, !isLoading else { return }
        var components = URLComponents(string: "/training/\(sport.rawValue)/occupied_grids_ranklist")
        var queryItems = [
            URLQueryItem(name: "region_id", value: regionID),
            URLQueryItem(name: "limit", value: "20")
        ]
        if !reset, let nextCursor {
            queryItems.append(URLQueryItem(name: "cursor", value: nextCursor))
        }
        components?.queryItems = queryItems
        guard let urlPath = components?.string else { return }

        isLoading = true
        let request = APIRequest(path: urlPath, method: .get, requiresAuth: true)
        NetworkService.sendRequest(
            with: request,
            decodingType: RegionGridOccupancyRankListDTO.self,
            showLoadingToast: false,
            showErrorToast: true
        ) { result in
            DispatchQueue.main.async {
                isLoading = false
                guard case .success(let optionalData) = result, let data = optionalData else { return }
                me = data.me
                if reset {
                    entries = data.entries
                } else {
                    entries.append(contentsOf: data.entries)
                }
                nextCursor = data.next_cursor
            }
        }
    }
}
