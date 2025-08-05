//
//  ButtonComponent.swift
//  sportsx
//
//  Created by 任杰 on 2025/7/14.
//

import SwiftUI


// todo: 暂只能用在非scrollView中，scrollView中应该拖动时禁止点击事件
struct CommonTextButton: View {
    let text: String
    let action: () -> Void
    
    var body: some View {
        Text(text)
            .exclusiveTouchTapGesture {
                action()
            }
    }
}

struct CommonIconButton: View {
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Image(systemName: icon)
            .exclusiveTouchTapGesture {
                action()
            }
    }
}

