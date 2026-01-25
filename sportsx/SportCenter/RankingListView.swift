//
//  RankingListView.swift
//  sportsx
//
//  Created by 任杰 on 2025/6/15.
//

import SwiftUI


struct BikeScoreRankingView: View {
    @EnvironmentObject var appState: AppState
    @StateObject var viewModel: BikeScoreRankingViewModel
    @ObservedObject var userManager = UserManager.shared
    
    let genders: [Gender] = [.male, .female]
    
    init(seasonName: String, seasonID: String, gender: Gender) {
        _viewModel = StateObject(wrappedValue: BikeScoreRankingViewModel(seasonName: seasonName, seasonID: seasonID, gender: gender))
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
                (Text(viewModel.seasonName) + Text("competition.season.score.leaderboard"))
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
                        Button(LocalizedStringKey(gender.displayName)) {
                            viewModel.gender = gender
                        }
                    }
                } label: {
                    HStack {
                        Text(LocalizedStringKey(viewModel.gender.displayName))
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
            }
            
            HStack(spacing: 30) {
                Text("competition.track.leaderboard.ranking")
                Text("common.user")
                Spacer()
                Text("competition.track.leaderboard.score")
            }
            .font(.subheadline)
            .foregroundStyle(Color.secondText)
            .padding(.horizontal)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    if viewModel.rankingListEntries.isEmpty && !viewModel.isLoading {
                        HStack {
                            Spacer()
                            Text("competition.track.leaderboard.no_data")
                                .foregroundColor(.secondText)
                                .padding()
                            Spacer()
                        }
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(viewModel.rankingListEntries.indices, id: \.self) { index in
                                let entry = viewModel.rankingListEntries[index]
                                BikeScoreRankEntryView(entry: entry)
                                    .onAppear {
                                        if entry == viewModel.rankingListEntries.last && viewModel.hasMore {
                                            viewModel.queryScoreRankingList(reset: false)
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
        .enableSwipeBackGesture()
        .onFirstAppear {
            viewModel.queryScoreRankingList(reset: true)
        }
        .onValueChange(of: viewModel.gender) {
            viewModel.queryScoreRankingList(reset: true)
        }
    }
}

struct BikeRankingListView: View {
    @EnvironmentObject var appState: AppState
    @StateObject var viewModel: BikeRankingListViewModel
    @ObservedObject var userManager = UserManager.shared
    
    let genders: [Gender] = [.male, .female]
    
    init(trackID: String, gender: Gender, isHistory: Bool) {
        _viewModel = StateObject(wrappedValue: BikeRankingListViewModel(trackID: trackID, gender: gender, isHistory: isHistory))
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
                Text("competition.track.leaderboard")
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
                        Button(LocalizedStringKey(gender.displayName)) {
                            viewModel.gender = gender
                        }
                    }
                } label: {
                    HStack {
                        Text(LocalizedStringKey(viewModel.gender.displayName))
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
                if !viewModel.isHistory {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15))
                        .foregroundStyle(.white)
                        .onTapGesture {
                            viewModel.refresh()
                        }
                }
            }
            
            HStack(spacing: 30) {
                Text("competition.track.leaderboard.ranking")
                Text("competition.track.leaderboard.user_and_time")
                Spacer()
                Text("competition.track.leaderboard.reward")
                Text("competition.track.leaderboard.score")
            }
            .font(.subheadline)
            .foregroundStyle(Color.secondText)
            .padding(.horizontal)
            
            if (!viewModel.isHistory) && userManager.isLoggedIn {
                HStack {
                    if let rank = viewModel.rank {
                        Text("\(rank)")
                            .foregroundStyle(.white)
                            .font(.headline)
                            .padding(.horizontal, 10)
                    } else {
                        Text("error.no_data")
                            .foregroundStyle(.white)
                            .font(.subheadline)
                    }
                    CachedAsyncImage(
                        urlString: userManager.user.avatarImageURL
                    )
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                    .padding(.leading, 5)
                    .exclusiveTouchTapGesture {
                        appState.navigationManager.append(.userView(id: userManager.user.userID))
                    }
                    VStack(alignment: .leading) {
                        Text("common.me")
                            .font(.subheadline)
                            .foregroundStyle(Color.secondText)
                        Text(TimeDisplay.formattedTime(viewModel.duration, showFraction: true))
                            .font(.subheadline)
                            .foregroundStyle(Color.secondText)
                    }
                    Spacer()
                    if let voucher = viewModel.voucherAmount {
                        HStack(spacing: 2) {
                            Image("voucher")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20)
                            Text("\(voucher)")
                                .foregroundStyle(Color.secondText)
                        }
                    }
                    if let score = viewModel.score {
                        Text("\(score)")
                            .foregroundStyle(Color.secondText)
                    }
                }
                .padding(8)
                .background(Color.gray.opacity(0.8))
                .cornerRadius(10)
            }
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    if viewModel.rankingListEntries.isEmpty && !viewModel.isLoading {
                        HStack {
                            Spacer()
                            Text("competition.track.leaderboard.no_data")
                                .foregroundColor(.secondText)
                                .padding()
                            Spacer()
                        }
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(viewModel.rankingListEntries.indices, id: \.self) { index in
                                let entry = viewModel.rankingListEntries[index]
                                BikeRankingListEntryView(entry: entry)
                                    .onAppear {
                                        if entry == viewModel.rankingListEntries.last && viewModel.hasMore {
                                            if viewModel.isHistory {
                                                viewModel.queryHistoryRankingList(reset: false)
                                            } else {
                                                viewModel.queryRankingList(reset: false)
                                            }
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
        .enableSwipeBackGesture()
        .onFirstAppear {
            viewModel.refresh()
        }
        .onValueChange(of: viewModel.gender) {
            viewModel.refresh(enforce: true)
        }
    }
}

struct BikeScoreRankEntryView: View {
    @EnvironmentObject var appState: AppState
    let entry: BikeScoreRankEntry
    
    var body: some View {
        HStack {
            Text("\(entry.rank)")
                .foregroundStyle(.white)
                .font(.headline)
                .padding(.horizontal, 10)
            CachedAsyncImage(
                urlString: entry.avatarImageURL
            )
            .aspectRatio(contentMode: .fill)
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            .padding(.leading, 5)
            .exclusiveTouchTapGesture {
                appState.navigationManager.append(.userView(id: entry.userID))
            }
            Text(entry.nickname)
                .font(.subheadline)
                .foregroundStyle(.white)
            Spacer()
            Text("\(entry.score)")
                .foregroundStyle(Color.secondText)
        }
        .padding(8)
        .background(Color.gray.opacity(0.8))
        .cornerRadius(10)
    }
}

struct BikeRankingListEntryView: View {
    @EnvironmentObject var appState: AppState
    let entry: BikeRankingListEntry

    var body: some View {
        HStack {
            Text("\(entry.rank)")
                .foregroundStyle(.white)
                .font(.headline)
                .padding(.horizontal, 10)
            CachedAsyncImage(
                urlString: entry.avatarImageURL
            )
            .aspectRatio(contentMode: .fill)
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            .padding(.leading, 5)
            .exclusiveTouchTapGesture {
                appState.navigationManager.append(.userView(id: entry.userID))
            }
            VStack(alignment: .leading) {
                Text(entry.nickname)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                Text(TimeDisplay.formattedTime(entry.duration, showFraction: true))
                    .font(.subheadline)
                    .foregroundStyle(.white)
            }
            Spacer()
            HStack(spacing: 2) {
                Image("voucher")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20)
                Text("\(entry.voucher)")
                    .foregroundStyle(Color.secondText)
            }
            Text("\(entry.score)")
                .foregroundStyle(Color.secondText)
        }
        .padding(8)
        .background(Color.gray.opacity(0.8))
        .cornerRadius(10)
    }
}


struct RunningScoreRankingView: View {
    @EnvironmentObject var appState: AppState
    @StateObject var viewModel: RunningScoreRankingViewModel
    @ObservedObject var userManager = UserManager.shared
    
    let genders: [Gender] = [.male, .female]
    
    init(seasonName: String, seasonID: String, gender: Gender) {
        _viewModel = StateObject(wrappedValue: RunningScoreRankingViewModel(seasonName: seasonName, seasonID: seasonID, gender: gender))
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
                (Text(viewModel.seasonName) + Text("competition.season.score.leaderboard"))
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
                        Button(LocalizedStringKey(gender.displayName)) {
                            viewModel.gender = gender
                        }
                    }
                } label: {
                    HStack {
                        Text(LocalizedStringKey(viewModel.gender.displayName))
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
            }
            
            HStack(spacing: 30) {
                Text("competition.track.leaderboard.ranking")
                Text("common.user")
                Spacer()
                Text("competition.track.leaderboard.score")
            }
            .font(.subheadline)
            .foregroundStyle(Color.secondText)
            .padding(.horizontal)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    if viewModel.rankingListEntries.isEmpty && !viewModel.isLoading {
                        HStack {
                            Spacer()
                            Text("competition.track.leaderboard.no_data")
                                .foregroundColor(.secondText)
                                .padding()
                            Spacer()
                        }
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(viewModel.rankingListEntries.indices, id: \.self) { index in
                                let entry = viewModel.rankingListEntries[index]
                                RunningScoreRankEntryView(entry: entry)
                                    .onAppear {
                                        if entry == viewModel.rankingListEntries.last && viewModel.hasMore {
                                            viewModel.queryScoreRankingList(reset: false)
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
        .enableSwipeBackGesture()
        .onFirstAppear {
            viewModel.queryScoreRankingList(reset: true)
        }
        .onValueChange(of: viewModel.gender) {
            viewModel.queryScoreRankingList(reset: true)
        }
    }
}

struct RunningRankingListView: View {
    @EnvironmentObject var appState: AppState
    @StateObject var viewModel: RunningRankingListViewModel
    @ObservedObject var userManager = UserManager.shared
    
    let genders: [Gender] = [.male, .female]
    
    init(trackID: String, gender: Gender, isHistory: Bool) {
        _viewModel = StateObject(wrappedValue: RunningRankingListViewModel(trackID: trackID, gender: gender, isHistory: isHistory))
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
                Text("competition.track.leaderboard")
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
                        Button(LocalizedStringKey(gender.displayName)) {
                            viewModel.gender = gender
                        }
                    }
                } label: {
                    HStack {
                        Text(LocalizedStringKey(viewModel.gender.displayName))
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
                if !viewModel.isHistory {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15))
                        .foregroundStyle(.white)
                        .onTapGesture {
                            viewModel.refresh()
                        }
                }
            }
            
            HStack(spacing: 30) {
                Text("competition.track.leaderboard.ranking")
                Text("competition.track.leaderboard.user_and_time")
                Spacer()
                Text("competition.track.leaderboard.reward")
                Text("competition.track.leaderboard.score")
            }
            .font(.subheadline)
            .foregroundStyle(Color.secondText)
            .padding(.horizontal)
            
            if (!viewModel.isHistory) && userManager.isLoggedIn {
                HStack {
                    if let rank = viewModel.rank {
                        Text("\(rank)")
                            .foregroundStyle(.white)
                            .font(.headline)
                            .padding(.horizontal, 10)
                    } else {
                        Text("error.no_data")
                            .foregroundStyle(.white)
                            .font(.subheadline)
                    }
                    CachedAsyncImage(
                        urlString: userManager.user.avatarImageURL
                    )
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                    .padding(.leading, 5)
                    .exclusiveTouchTapGesture {
                        appState.navigationManager.append(.userView(id: userManager.user.userID))
                    }
                    VStack(alignment: .leading) {
                        Text("common.me")
                            .font(.subheadline)
                            .foregroundStyle(Color.secondText)
                        Text(TimeDisplay.formattedTime(viewModel.duration, showFraction: true))
                            .font(.subheadline)
                            .foregroundStyle(Color.secondText)
                    }
                    Spacer()
                    if let voucher = viewModel.voucherAmount {
                        HStack(spacing: 2) {
                            Image("voucher")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20)
                            Text("\(voucher)")
                                .foregroundStyle(Color.secondText)
                        }
                    }
                    if let score = viewModel.score {
                        Text("\(score)")
                            .foregroundStyle(Color.secondText)
                    }
                }
                .padding(8)
                .background(Color.gray.opacity(0.8))
                .cornerRadius(10)
            }
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    if viewModel.rankingListEntries.isEmpty && !viewModel.isLoading {
                        HStack {
                            Spacer()
                            Text("competition.track.leaderboard.no_data")
                                .foregroundColor(.secondText)
                                .padding()
                            Spacer()
                        }
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(viewModel.rankingListEntries.indices, id: \.self) { index in
                                let entry = viewModel.rankingListEntries[index]
                                RunningRankingListEntryView(entry: entry)
                                    .onAppear {
                                        if entry == viewModel.rankingListEntries.last && viewModel.hasMore{
                                            if viewModel.isHistory {
                                                viewModel.queryHistoryRankingList(reset: false)
                                            } else {
                                                viewModel.queryRankingList(reset: false)
                                            }
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
        .enableSwipeBackGesture()
        .onFirstAppear {
            viewModel.refresh()
        }
        .onValueChange(of: viewModel.gender) {
            viewModel.refresh(enforce: true)
        }
    }
}

struct RunningScoreRankEntryView: View {
    @EnvironmentObject var appState: AppState
    let entry: RunningScoreRankEntry
    
    var body: some View {
        HStack {
            Text("\(entry.rank)")
                .foregroundStyle(.white)
                .font(.headline)
                .padding(.horizontal, 10)
            CachedAsyncImage(
                urlString: entry.avatarImageURL
            )
            .aspectRatio(contentMode: .fill)
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            .padding(.leading, 5)
            .exclusiveTouchTapGesture {
                appState.navigationManager.append(.userView(id: entry.userID))
            }
            Text(entry.nickname)
                .font(.subheadline)
                .foregroundStyle(.white)
            Spacer()
            Text("\(entry.score)")
                .foregroundStyle(Color.secondText)
        }
        .padding(8)
        .background(Color.gray.opacity(0.8))
        .cornerRadius(10)
    }
}

struct RunningRankingListEntryView: View {
    @EnvironmentObject var appState: AppState
    let entry: RunningRankingListEntry

    var body: some View {
        HStack {
            Text("\(entry.rank)")
                .foregroundStyle(.white)
                .font(.headline)
                .padding(.horizontal, 10)
            CachedAsyncImage(
                urlString: entry.avatarImageURL
            )
            .aspectRatio(contentMode: .fill)
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            .padding(.leading, 5)
            .exclusiveTouchTapGesture {
                appState.navigationManager.append(.userView(id: entry.userID))
            }
            VStack(alignment: .leading) {
                Text(entry.nickname)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                Text(TimeDisplay.formattedTime(entry.duration, showFraction: true))
                    .font(.subheadline)
                    .foregroundStyle(.white)
            }
            Spacer()
            HStack(spacing: 2) {
                Image("voucher")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20)
                Text("\(entry.voucher)")
                    .foregroundStyle(Color.secondText)
            }
            Text("\(entry.score)")
                .foregroundStyle(Color.secondText)
        }
        .padding(8)
        .background(Color.gray.opacity(0.8))
        .cornerRadius(10)
    }
}
