//
//  IdentityAuthView.swift
//  sportsx
//
//  Created by 任杰 on 2025/4/29.
//

import SwiftUI

struct IdentityAuthView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ZStack {
            Color.defaultBackground
                .ignoresSafeArea()
            
            VStack(alignment: .leading) {
                Text("身份认证页面")
                    .font(.largeTitle)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBackGesture()
    }
}
