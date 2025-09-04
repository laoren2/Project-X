//
//  GameSummaryView.swift
//  sportsx
//
//  Created by 任杰 on 2025/4/18.
//

import SwiftUI

struct GameSummaryView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: UserViewModel
    
    
    var body: some View {
        LazyVStack(spacing: 15) {
            ForEach(viewModel.gameSummaryCards) { card in
                GameSummaryCardView(gameSummaryCard: card)
            }
        }
        .padding(.horizontal)
        .padding(.top)
        .border(.green)
    }
}

struct GameSummaryCardView: View {
    @EnvironmentObject var appState: AppState
    let gameSummaryCard: GameSummaryCard
    
    
    var body: some View {
        VStack {
            HStack {
                Text(gameSummaryCard.eventname)
                Spacer()
                Text(gameSummaryCard.trackName)
                Spacer()
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(.blue)
                Text(gameSummaryCard.cityName)
            }
            HStack {
                Text("PB")
                    .font(.system(size: 15))
                    .bold()
                    .padding(.horizontal, 5)
                    .background(.green.opacity(0.6))
                    .cornerRadius(5)
                Text(TimeDisplay.formattedTime(gameSummaryCard.best_time))
                Spacer()
                Text("No.\(gameSummaryCard.rank)")
                    .bold()
                Spacer()
                Image(systemName: "dollarsign.circle")
                    .foregroundStyle(.yellow)
                Text("\(gameSummaryCard.previewBonus)")
                    .bold()
            }
            HStack {
                Spacer()
                ForEach(gameSummaryCard.magicCards) { card in
                    MagicCardView(card: card)
                    Spacer()
                }
                ForEach(0..<(5 - gameSummaryCard.magicCards.count), id: \.self) { _ in
                    EmptyCardSlot()
                        //.opacity(0)
                    Spacer()
                }
            }
            .frame(height: 80)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 10)
        .foregroundStyle(.white)
        .background(.gray.opacity(0.5))
        .cornerRadius(10)
        //.border(.red)
    }
}

struct GameSummaryCard: Identifiable {
    let id = UUID()
    let eventname: String
    let trackName: String
    let cityName: String
    let best_time: TimeInterval
    let rank: Int
    let previewBonus: Int
    let magicCards: [MagicCard]
}


#Preview {
    let appState = AppState.shared
    let vm = UserViewModel(id: "qweasd", needBack: false)
    GameSummaryView(viewModel: vm)
        .environmentObject(appState)
}
