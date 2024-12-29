//
//  test.swift
//  sportsx
//
//  Created by 任杰 on 2024/9/20.
//

import SwiftUI
import MapKit


struct test: View {
    @State private var selectedSport = "自行车" // 默认运动
    @State private var showSportPicker = false
    @State private var selectedMode = 1
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                // 运动选择模块
                HStack {
                    Button(action: {
                        withAnimation {
                            showSportPicker.toggle()
                        }
                    }) {
                        Image(systemName: "repeat")
                            .foregroundColor(.primary)
                            .font(.headline)
                    }
                    .sheet(isPresented: $showSportPicker) {
                        SportSelectedView()
                    }
                    Spacer()
                }
                .padding(.leading, 10)
                
                // 模式切换开关
                Picker("", selection: $selectedMode) {
                    Text("训练").tag(0)
                    Text("竞赛").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 120, height: 40)
                .padding(.trailing)
            }
            
            Spacer()

            if selectedMode == 0 {
                PlaceholderView(title: "qwe")
            } else {
                PlaceholderView(title: "asd")
            }
            Spacer()
        }
        .toolbar(.hidden, for: .navigationBar) // 隐藏导航栏
    }
}

struct SportSelectedView: View {
    var body: some View {
        Text("SportSelectedView")
    }
}


#Preview {
    let appState = AppState()
    test()
        .environmentObject(appState)
}
