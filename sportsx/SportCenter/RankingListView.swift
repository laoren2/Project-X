//
//  RankingListView.swift
//  sportsx
//
//  Created by 任杰 on 2025/6/15.
//

import SwiftUI


struct BikeRankingListView: View {
    @EnvironmentObject var appState: AppState
    @StateObject var viewModel: BikeRankingListViewModel
    @ObservedObject var userManager = UserManager.shared
    
    let genders: [Gender] = [.male, .female]
    
    init(trackID: String) {
        _viewModel = StateObject(wrappedValue: BikeRankingListViewModel(trackID: trackID))
    }
    
    var body: some View {
        VStack {
            HStack {
                CommonIconButton(icon: "chevron.left") {
                    appState.navigationManager.removeLast()
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                Spacer()
                Text("bike排行榜")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: {}) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.clear)
                }
            }
            
            HStack {
                Menu {
                    ForEach(genders, id: \.self) { gender in
                        Button(gender.rawValue) {
                            viewModel.gender = gender
                        }
                    }
                } label: {
                    HStack {
                        Text(viewModel.gender.rawValue)
                            .font(.subheadline)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .foregroundStyle(.white)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 8)
                    .cornerRadius(5)
                }
                Spacer()
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .onTapGesture {
                        viewModel.refresh()
                    }
            }
            
            if let rankInfo = viewModel.selfRankInfo {
                BikeRankingListEntryView(entry: BikeRankingListEntry(userID: userManager.user.userID, nickname: userManager.user.nickname, avatarImageURL: userManager.user.avatarImageURL, score: rankInfo.duration ?? 0, recordID: rankInfo.recordID ?? "无数据"), rank: rankInfo.rank)
            }
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    if viewModel.rankingListEntries.isEmpty && !viewModel.isLoading {
                        HStack {
                            Spacer()
                            Text("暂无排行榜数据")
                                .foregroundColor(.secondText)
                                .padding()
                            Spacer()
                        }
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(viewModel.rankingListEntries.indices, id: \.self) { index in
                                let entry = viewModel.rankingListEntries[index]
                                BikeRankingListEntryView(entry: entry, rank: index + 1)
                                    .onAppear {
                                        if entry == viewModel.rankingListEntries.last && viewModel.hasMore{
                                            viewModel.queryRankingList(reset: false)
                                        }
                                    }
                            }
                            if viewModel.isLoading {
                                ProgressView()
                                    .padding()
                            }
                        }
                    }
                }
                .padding(.top, 10)
            }
        }
        .padding(.horizontal)
        .background(Color.defaultBackground)
        .toolbar(.hidden, for: .navigationBar)
        .enableBackGesture()
        .onFirstAppear {
            viewModel.refresh()
        }
        .onChange(of: viewModel.gender) {
            viewModel.refresh(enforce: true)
        }
    }
}

struct BikeRankingListEntryView: View {
    @EnvironmentObject var appState: AppState
    let entry: BikeRankingListEntry
    let rank: Int?

    var body: some View {
        HStack {
            if let rank = rank {
                Text("No. \(rank)")
                    .foregroundStyle(.white)
                    .font(.subheadline)
            } else {
                Text("无数据")
                    .foregroundStyle(Color.secondText)
                    .font(.subheadline)
            }
            CachedAsyncImage(
                urlString: entry.avatarImageURL,
                placeholder: Image(systemName: "person"),
                errorImage: Image(systemName: "photo.badge.exclamationmark")
            )
            .aspectRatio(contentMode: .fill)
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            .padding(.leading, 5)
            .exclusiveTouchTapGesture {
                appState.navigationManager.append(.userView(id: entry.userID, needBack: true))
            }
            VStack(alignment: .leading) {
                Text(entry.nickname)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(TimeDisplay.formattedTime(entry.score, showFraction: true))
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    //.onTapGesture {
                    //    print("record_id: \(entry.recordID)")
                    //}
            }
            Spacer()
        }
        .padding(8)
        .background(Color.gray.opacity(0.8))
        .cornerRadius(10)
    }
}


struct RunningRankingListView: View {
    @EnvironmentObject var appState: AppState
    @StateObject var viewModel: RunningRankingListViewModel
    @ObservedObject var userManager = UserManager.shared
    
    let genders: [Gender] = [.male, .female]
    
    init(trackID: String) {
        _viewModel = StateObject(wrappedValue: RunningRankingListViewModel(trackID: trackID))
    }
    
    var body: some View {
        VStack {
            HStack {
                CommonIconButton(icon: "chevron.left") {
                    appState.navigationManager.removeLast()
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                Spacer()
                Text("running排行榜")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: {}) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.clear)
                }
            }
            
            HStack {
                Menu {
                    ForEach(genders, id: \.self) { gender in
                        Button(gender.rawValue) {
                            viewModel.gender = gender
                        }
                    }
                } label: {
                    HStack {
                        Text(viewModel.gender.rawValue)
                            .font(.subheadline)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .foregroundStyle(.white)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 8)
                    .cornerRadius(5)
                }
                Spacer()
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .onTapGesture {
                        viewModel.refresh()
                    }
            }
            
            if let rankInfo = viewModel.selfRankInfo {
                RunningRankingListEntryView(entry: RunningRankingListEntry(userID: userManager.user.userID, nickname: userManager.user.nickname, avatarImageURL: userManager.user.avatarImageURL, score: rankInfo.duration ?? 0, recordID: rankInfo.recordID ?? "无数据"), rank: rankInfo.rank)
            }
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    if viewModel.rankingListEntries.isEmpty && !viewModel.isLoading {
                        HStack {
                            Spacer()
                            Text("暂无排行榜数据")
                                .foregroundColor(.secondText)
                                .padding()
                            Spacer()
                        }
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(viewModel.rankingListEntries.indices, id: \.self) { index in
                                let entry = viewModel.rankingListEntries[index]
                                RunningRankingListEntryView(entry: entry, rank: index + 1)
                                    .onAppear {
                                        if entry == viewModel.rankingListEntries.last && viewModel.hasMore{
                                            viewModel.queryRankingList(reset: false)
                                        }
                                    }
                            }
                            if viewModel.isLoading {
                                ProgressView()
                                    .padding()
                            }
                        }
                    }
                }
                .padding(.top, 10)
            }
        }
        .padding(.horizontal)
        .background(Color.defaultBackground)
        .toolbar(.hidden, for: .navigationBar)
        .enableBackGesture()
        .onFirstAppear {
            viewModel.refresh()
        }
        .onChange(of: viewModel.gender) {
            viewModel.refresh(enforce: true)
        }
    }
}

struct RunningRankingListEntryView: View {
    @EnvironmentObject var appState: AppState
    let entry: RunningRankingListEntry
    let rank: Int?

    var body: some View {
        HStack {
            if let rank = rank {
                Text("No. \(rank)")
                    .foregroundStyle(.white)
                    .font(.subheadline)
            } else {
                Text("无数据")
                    .foregroundStyle(Color.secondText)
                    .font(.subheadline)
            }
            CachedAsyncImage(
                urlString: entry.avatarImageURL,
                placeholder: Image(systemName: "person"),
                errorImage: Image(systemName: "photo.badge.exclamationmark")
            )
            .aspectRatio(contentMode: .fill)
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            .padding(.leading, 5)
            .exclusiveTouchTapGesture {
                appState.navigationManager.append(.userView(id: entry.userID, needBack: true))
            }
            VStack(alignment: .leading) {
                Text(entry.nickname)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(TimeDisplay.formattedTime(entry.score, showFraction: true))
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    //.onTapGesture {
                    //    print("record_id: \(entry.recordID)")
                    //}
            }
            Spacer()
        }
        .padding(8)
        .background(Color.gray.opacity(0.8))
        .cornerRadius(10)
    }
}
