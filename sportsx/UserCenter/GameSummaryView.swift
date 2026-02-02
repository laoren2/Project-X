//
//  GameSummaryView.swift
//  sportsx
//
//  Created by 任杰 on 2025/4/18.
//

import SwiftUI

struct GameSummaryView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var userManager = UserManager.shared
    @ObservedObject var viewModel: UserViewModel
    
    var body: some View {
        VStack {
            if !viewModel.gameSummaryCards.isEmpty {
                LazyVStack(spacing: 15) {
                    ForEach(viewModel.gameSummaryCards) { card in
                        GameSummaryCardView(sport: viewModel.sport, gameSummaryCard: card)
                    }
                }
                .padding(.horizontal)
                .padding(.top)
            } else {
                Spacer()
                VStack(spacing: 20) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 60))
                    Text("competition.season.no_current_matches")
                        .font(.headline)
                }
                .foregroundStyle(Color.white.opacity(0.3))
            }
            Spacer()
        }
        .frame(minHeight: 700)
    }
}

struct LocalGameSummaryView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var userManager = UserManager.shared
    @ObservedObject var viewModel: LocalUserViewModel
    
    var body: some View {
        VStack {
            if !userManager.isLoggedIn {
                Spacer()
                Text("toast.no_login.2")
                    .foregroundStyle(Color.secondText)
                    .padding(.top, 100)
            } else {
                if !viewModel.gameSummaryCards.isEmpty {
                    LazyVStack(spacing: 15) {
                        ForEach(viewModel.gameSummaryCards) { card in
                            GameSummaryCardView(sport: viewModel.sport, gameSummaryCard: card)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                } else {
                    Spacer()
                    VStack(spacing: 20) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 60))
                        Text("competition.season.no_current_matches")
                            .font(.headline)
                    }
                    .foregroundStyle(Color.white.opacity(0.3))
                }
            }
            Spacer()
        }
        .frame(minHeight: 600)
    }
}

struct GameSummaryCardView: View {
    @EnvironmentObject var appState: AppState
    @State var sport: SportName
    let gameSummaryCard: GameSummaryCard
    
    var body: some View {
        VStack {
            HStack(spacing: 5) {
                Text(gameSummaryCard.eventname)
                Spacer()
                Text(gameSummaryCard.trackName)
                Spacer()
                Image("location")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                Text(LocalizedStringKey(gameSummaryCard.cityName))
            }
            .font(.headline)
            .foregroundStyle(Color.white)
            Divider()
            HStack {
                Text("PB")
                    .font(.system(size: 15))
                    .bold()
                    .padding(.horizontal, 5)
                    .background(.green.opacity(0.6))
                    .cornerRadius(5)
                Text(TimeDisplay.formattedTime(gameSummaryCard.best_time))
                Spacer()
                Text("competition.track.leaderboard.ranking") + Text(": \(gameSummaryCard.rank)")
                Spacer()
                Text("competition.track.leaderboard.score") + Text(": \(gameSummaryCard.score)")
            }
            .font(.subheadline)
            .foregroundStyle(Color.secondText)
            Divider()
            HStack(spacing: 5) {
                Image(CCAssetType.voucher.iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20)
                Text("\(gameSummaryCard.voucher)")
                Spacer()
                HStack(spacing: 4) {
                    Text("action.detail")
                    Image(systemName: "chevron.right")
                }
                .exclusiveTouchTapGesture {
                    if sport == .Bike {
                        appState.navigationManager.append(.bikeRecordDetailView(recordID: gameSummaryCard.record_id))
                    } else if sport == .Running {
                        appState.navigationManager.append(.runningRecordDetailView(recordID: gameSummaryCard.record_id))
                    }
                }
            }
            .font(.subheadline)
            .foregroundStyle(Color.secondText)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 10)
        .background(.white.opacity(0.3))
        .cornerRadius(10)
    }
}

struct GameSummaryCard: Identifiable {
    var id: String { record_id }
    let record_id: String
    let eventname: String
    let trackName: String
    let cityName: String
    let best_time: TimeInterval
    let rank: Int
    let voucher: Int
    let score: Int
    //let magicCards: [MagicCard]
    
    init(from card: GameSummaryCardDTO) {
        self.record_id = card.record_id
        self.eventname = card.event_name
        self.trackName = card.track_name
        self.cityName = card.city_name
        self.best_time = card.best_time
        self.rank = card.rank
        self.voucher = card.voucher
        self.score = card.score
    }
}

struct GameSummaryCardDTO: Codable {
    let record_id: String
    let event_name: String
    let track_name: String
    let city_name: String
    let best_time: Double
    let rank: Int
    let voucher: Int
    let score: Int
}

struct GameSummaryResponse: Codable {
    let records: [GameSummaryCardDTO]
}

#Preview {
    let appState = AppState.shared
    let vm = UserViewModel(id: "qweasd")
    GameSummaryView(viewModel: vm)
        .environmentObject(appState)
}
