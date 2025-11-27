//
//  SensorBindView.swift
//  sportsx
//
//  Created by 任杰 on 2025/1/9.
//

import SwiftUI
import WatchConnectivity


struct SensorBindView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var deviceManager = DeviceManager.shared
    @State private var isLoading: BodyPosition? = nil
    @State private var selectedPosition: BodyPosition? = nil
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                CommonIconButton(icon: "chevron.left") {
                    appState.navigationManager.removeLast()
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.secondText)
                Spacer()
                Text("多位置设备绑定")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.secondText)
                Spacer()
                Button(action: {}) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.clear)
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            // 生成 5 个位置的绑定按钮
            ForEach(BodyPosition.allCases, id: \.self) { position in
                VStack {
                    if deviceManager.isBound(at: position),
                       let device = deviceManager.getDevice(at: position) {
                        // 已绑定状态 => 显示设备名
                        Text("已绑定设备: \(device.deviceName)")
                            .foregroundColor(.green)
                        
                        Text("点击解绑")
                            .padding(.vertical, 4)
                            .buttonStyle(.bordered)
                            .foregroundColor(.white)
                            .exclusiveTouchTapGesture {
                                deviceManager.unbindDevice(at: position)
                            }
                    } else {
                        // 未绑定状态
                        if isLoading == position {
                            ProgressView()
                        } else {
                            Text("未绑定")
                                .foregroundColor(.red)
                            
                            Text("点击绑定")
                                .padding(.vertical, 4)
                                .buttonStyle(.bordered)
                                .foregroundColor(.white)
                                .exclusiveTouchTapGesture {
                                    selectedPosition = position
                                }
                        }
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
            Spacer()
        }
        .background(Color.defaultBackground)
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBackGesture()
        .sheet(item: $selectedPosition) { pos in
            VStack {
                Text("选择设备")
                    .bold()
                    .padding()
                List {
                    if deviceManager.existAvailableAW() && !deviceManager.hasAppleWatchBound() {
                        Button(action: {
                            bindAWDevice(pos: pos)
                            selectedPosition = nil
                        }) {
                            HStack {
                                Text("Apple Watch")
                                Spacer()
                                Image(systemName: "applewatch")
                            }
                        }
                    }
                    // more device...
                }
                .presentationDetents([.medium])
            }
        }
    }
    
    func bindAWDevice(pos: BodyPosition) {
        // 创建一个 AppleWatchDevice 并绑定
        // 未来支持更多设备(Xiaomi/Huawei等)
        let newWatch = AppleWatchDevice(
            deviceID: "applewatch-\(pos.rawValue)",
            deviceName: "applewatch",
            sensorPos: pos.rawValue
        )
        isLoading = pos
        var counter = 0
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        timer.schedule(deadline: .now(), repeating: 1.0)
        timer.setEventHandler {
            if newWatch.connect() {
                DispatchQueue.main.async {
                    deviceManager.bindDevice(newWatch, at: pos)
                    isLoading = nil
                    let toast = Toast(message: "绑定成功")
                    ToastManager.shared.show(toast: toast)
                }
                timer.cancel()
            } else {
                counter += 1
                if counter >= 10 {
                    DispatchQueue.main.async {
                        isLoading = nil
                        let toast = Toast(message: "绑定失败")
                        ToastManager.shared.show(toast: toast)
                    }
                    timer.cancel()
                }
            }
        }
        timer.resume()
    }
}

#Preview {
    let appState = AppState.shared
    return SensorBindView()
        .environmentObject(appState)
}
