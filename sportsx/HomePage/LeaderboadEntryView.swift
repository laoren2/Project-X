//
//  LeaderboadEntryView.swift
//  sportsx
//
//  Created by 任杰 on 2024/8/21.
//

import SwiftUI

struct LeaderboardEntryView: View {
    @EnvironmentObject var appState: AppState
    var entry: LeaderboardEntry

    var body: some View {
        HStack {
            if let urlString = entry.avatarImageURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .clipShape(Circle()) // 使图片变为圆形
                        .overlay(Circle().stroke(Color.white, lineWidth: 2)) // 添加白色边框
                        .padding(.leading, 5)
                } placeholder: {
                    //Circle()
                    Image("Ads")
                        //.fill(Color.gray)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.blue, lineWidth: 2))
                        .padding(.leading, 5)
                        .onTapGesture {
                            appState.navigationManager.path.append(.userView(id: "123454321", needBack: true))
                        }
                }
            } else {
                Circle()
                    .fill(Color.gray)
                    .frame(width: 50, height: 50)
                    .padding(.leading, 5)
            }
            
            VStack(alignment: .leading) {
                Text(entry.nickname)
                    .font(.headline)
                Text("Time: \(entry.best_time) seconds")
                    .font(.subheadline)
            }
            .padding(.leading, 1)
        }
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .padding(.horizontal)
    }
}

//#Preview {
//    LeaderboadEntryView()
//}
