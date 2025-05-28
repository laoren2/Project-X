//
//  LeaderboadEntryView.swift
//  sportsx
//
//  Created by 任杰 on 2024/8/21.
//

import SwiftUI

struct LeaderboardEntryView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var userManager = UserManager.shared
    var entry: LeaderboardEntry

    var body: some View {
        HStack {
            if entry.user_id == userManager.user.userID, let avater_image = userManager.avatarImage {
                Image(uiImage: avater_image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                    .padding(.leading, 5)
                    .onTapGesture {
                        appState.navigationManager.append(.userView(id: entry.user_id, needBack: true))
                    }
            } else {
                if let urlString = entry.avatarImageURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 50, height: 50)
                            .clipShape(Circle()) // 使图片变为圆形
                            .padding(.leading, 5)
                            .onTapGesture {
                                appState.navigationManager.append(.userView(id: entry.user_id, needBack: true))
                            }
                    } placeholder: {
                        //Circle()
                        Image("Ads")
                        //.fill(Color.gray)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                            .padding(.leading, 5)
                            .onTapGesture {
                                appState.navigationManager.append(.userView(id: entry.user_id, needBack: true))
                            }
                    }
                } else {
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 50, height: 50)
                        .padding(.leading, 5)
                }
            }
            
            VStack(alignment: .leading) {
                Text(entry.user_id == userManager.user.userID ? userManager.user.nickname : entry.nickname)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Time: \(entry.best_time) seconds")
                    .font(.subheadline)
                    .foregroundStyle(.white)
            }
            .padding(.leading, 1)
        }
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .cornerRadius(10)
        .shadow(radius: 2)
        //.padding(.horizontal)
    }
}

//#Preview {
//    LeaderboadEntryView()
//}
