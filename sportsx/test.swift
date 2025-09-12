//
//  test.swift
//  sportsx
//
//  only use for local unit tests
//  ⚠️ clear before each submission
//
//  Created by 任杰 on 2024/9/20.
//

import SwiftUI
import UIKit
import MapKit
import Combine
import CoreML
import os


struct TestView: View {
    //@EnvironmentObject var appState: AppState
    //@StateObject var viewModel = TestViewModel()
    
    var body: some View {
        ZStack {
            Button("test"){
                print("test")
            }
        }
    }
}

class TestViewModel: ObservableObject {
    
}


#Preview {
    //let appState = AppState.shared
    TestView()
    //    .environmentObject(appState)
}
