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
            CachedAsyncImage(
                urlString: entry.avatarImageURL,
                placeholder: Image(systemName: "person"),
                errorImage: Image(systemName: "photo.badge.exclamationmark")
            )
            .aspectRatio(contentMode: .fill)
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            .padding(.leading, 5)
            .onTapGesture {
                appState.navigationManager.append(.userView(id: entry.user_id, needBack: true))
            }
            
            VStack(alignment: .leading) {
                Text(entry.nickname)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Time: \(entry.best_time) seconds")
                    .font(.subheadline)
                    .foregroundStyle(.white)
            }
            .padding(.leading, 1)
            
            Image(systemName: "dollarsign.circle")
                .foregroundStyle(.yellow)
            Text("\(entry.predictBonus)")
        }
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}

struct LeaderboardEntrySelfView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var userManager = UserManager.shared
    var entry: LeaderboardEntry

    var body: some View {
        HStack {
            if let avater_image = userManager.avatarImage {
                Image(uiImage: avater_image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                    .padding(.leading, 5)
                    .onTapGesture {
                        appState.navigationManager.append(.userView(id: userManager.user.userID, needBack: true))
                    }
            } else {
                CachedAsyncImage(
                    urlString: userManager.user.avatarImageURL,
                    placeholder: Image(systemName: "person"),
                    errorImage: Image(systemName: "photo.badge.exclamationmark")
                )
                .aspectRatio(contentMode: .fill)
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                .padding(.leading, 5)
                .onTapGesture {
                    appState.navigationManager.append(.userView(id: userManager.user.userID, needBack: true))
                }
            }
            
            VStack(alignment: .leading) {
                Text(userManager.user.nickname)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Time: \(entry.best_time) seconds")
                    .font(.subheadline)
                    .foregroundStyle(.white)
            }
            .padding(.leading, 1)
            
            Image(systemName: "dollarsign.circle")
                .foregroundStyle(.yellow)
            Text("\(entry.predictBonus)")
        }
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}

//#Preview {
//    LeaderboadEntryView()
//}
