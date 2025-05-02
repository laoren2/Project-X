//
//  SensorBindView.swift
//  sportsx
//
//  Created by 任杰 on 2025/1/9.
//

import SwiftUI

struct SensorBindView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var deviceManager = DeviceManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Text("多位置设备绑定示例")
                .font(.headline)
            
            // 生成 5 个位置的绑定按钮
            ForEach(BodyPosition.allCases, id: \.self) { position in
                VStack {
                    if deviceManager.isBound(at: position),
                       let device = deviceManager.getDevice(at: position) {
                        // 已绑定状态 => 显示设备名
                        Text("已绑定设备: \(device.deviceName)")
                            .foregroundColor(.green)
                        
                        Button("点击解绑") {
                            deviceManager.unbindDevice(at: position)
                        }
                        .padding(.vertical, 4)
                        .buttonStyle(.bordered)
                    } else {
                        // 未绑定状态
                        Text("未绑定")
                            .foregroundColor(.red)
                        
                        Button("点击绑定") {
                            // 模拟创建一个 AppleWatchDevice 并绑定
                            // 实际项目中可让用户选择不同设备(Apple/Huawei等)
                            let newWatch = AppleWatchDevice(
                                deviceID: "applewatch-\(position.rawValue)",
                                deviceName: "AppleWatch_Pos\(position.rawValue)",
                                sensorPos: position.rawValue,
                                dataFusionManager: appState.competitionManager.dataFusionManager
                            )
                            deviceManager.bindDevice(newWatch, at: position)
                        }
                        .padding(.vertical, 4)
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
                .overlay(
                    Text(position.name)
                        .font(.footnote)
                        .foregroundColor(.blue),
                    alignment: .topLeading
                )
                .border(.gray, width: 1)
            }
        }
        .padding()
    }
}

#Preview {
    let appState = AppState.shared
    return SensorBindView()
        .environmentObject(appState)
}
