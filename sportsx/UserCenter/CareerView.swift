//
//  CareerView.swift
//  sportsx
//
//  Created by 任杰 on 2025/4/18.
//

import SwiftUI

struct CareerView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        LazyVStack(spacing: 15) {
            ForEach(appState.competitionManager.userTab1) { competition in
                CompetitionRecordCard(competition: competition, onStart:  {
                    print("onStart")
                })
            }
        }
        .padding(.horizontal)
        .padding(.top)
        //.border(.blue)
    }
}
