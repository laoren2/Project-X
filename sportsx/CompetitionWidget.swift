//
//  CompetitionWidget.swift
//  sportsx
//
//  Created by 任杰 on 2024/12/16.
//

import SwiftUI
import Combine

struct CompetitionWidget: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var dataFusionManager = DataFusionManager.shared
    //@State private var modelResults: [String: Any] = [:]
    //private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        if appState.competitionManager.isShowWidget {
            VStack(alignment: .leading) {
                Text("比赛进行中")
                    .font(.headline)
                Text("已进行时间: \(TimeDisplay.formattedTime(dataFusionManager.elapsedTime))")
                    .font(.subheadline)
            }
            .frame(width: 300, height: 100) // 根据需要调整大小
            .background(Color.gray.opacity(0.8))
            .cornerRadius(10)
            .shadow(radius: 8)
            .onTapGesture {
                appState.navigationManager.path.append("competitionRealtimeView") // 触发导航
            }
            //.padding(.bottom, 100) // 调整与屏幕边缘的距离
            //.padding(.trailing, -200)
        }
    }
    
    func displayResult(_ result: Any) -> String {
        switch result {
        case let bool as Bool:
            return bool ? "✅" : "❌"
        case let int as Int:
            return "\(int)"
        case let double as Double:
            return String(format: "%.2f", double)
        default:
            return "?"
        }
    }
    
    func displayColor(_ result: Any) -> Color {
        switch result {
        case let bool as Bool:
            return bool ? .green : .red
        case let int as Int:
            return int > 10 ? .green : .red
        case let double as Double:
            return double > 10.0 ? .green : .red
        default:
            return .gray
        }
    }
}

#Preview{
    @Previewable @State var test: Bool = false
    let appState = AppState()
    CompetitionWidget()
        .environmentObject(appState)
}
