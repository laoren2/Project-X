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
                Text("user.page.features.bind_device")
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
            ScrollView {
                VStack(spacing: 20) {
                    //BodyBindView(selectedPosition: $selectedPosition, isLoading: $isLoading, position: .posWST)
                    BodyBindView(selectedPosition: $selectedPosition, isLoading: $isLoading, position: .posLH)
                    BodyBindView(selectedPosition: $selectedPosition, isLoading: $isLoading, position: .posRH)
                    //BodyBindView(selectedPosition: $selectedPosition, isLoading: $isLoading, position: .posLF)
                    //BodyBindView(selectedPosition: $selectedPosition, isLoading: $isLoading, position: .posRF)
                }
                .padding()
            }
        }
        .background(Color.defaultBackground)
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBackGesture()
        .sheet(item: $selectedPosition) { pos in
            VStack {
                HStack {
                    Spacer()
                    Text("user.page.bind_device.select")
                        .foregroundStyle(Color.secondText)
                    Spacer()
                }
                .padding()
                ScrollView {
                    VStack {
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
                                .foregroundStyle(Color.white)
                                .padding()
                                .background(Color.gray.opacity(0.6))
                                .cornerRadius(10)
                            }
                        } else {
                            Text("暂无可连接的设备")
                                .foregroundStyle(Color.thirdText)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 100)
                        }
                        // more device...
                    }
                    .padding()
                }
            }
            .presentationDetents([.medium])
            .background(Color.defaultBackground)
        }
    }
    
    func bindAWDevice(pos: BodyPosition) {
        // 创建一个 AppleWatchDevice 并绑定
        // 未来支持更多设备(Xiaomi/Huawei等)
        ToastManager.shared.start(toast: LoadingToast())
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
                    ToastManager.shared.finish()
                    let toast = Toast(message: "user.page.bind_device.result.success")
                    ToastManager.shared.show(toast: toast)
                }
                timer.cancel()
            } else {
                counter += 1
                if counter >= 10 {
                    DispatchQueue.main.async {
                        ToastManager.shared.finish()
                        isLoading = nil
                        let toast = Toast(message: "user.page.bind_device.result.failed")
                        ToastManager.shared.show(toast: toast)
                    }
                    timer.cancel()
                }
            }
        }
        timer.resume()
    }
}

struct BodyBindView: View {
    @ObservedObject var deviceManager = DeviceManager.shared
    @Binding var selectedPosition: BodyPosition?
    @Binding var isLoading: BodyPosition?
    
    let position: BodyPosition
    
    var body: some View {
        HStack(spacing: 10) {
            Image(position.icon)
                .resizable()
                .scaledToFit()
                .frame(width: 45)
            Text(LocalizedStringKey(position.name))
                .font(.title3)
                .bold()
                .foregroundStyle(Color.secondText)
            Spacer()
            if deviceManager.isBound(at: position),
               let device = deviceManager.getDevice(at: position) {
                HStack(spacing: 2) {
                    // 已绑定状态 => 显示设备名
                    Text("\(device.deviceName)")
                    Image(systemName: "info.circle")
                        .font(.subheadline)
                        .exclusiveTouchTapGesture {
                            PopupWindowManager.shared.presentPopup(
                                title: "\(device.deviceName)",
                                message: "user.page.bind_device.popup.applewatch",
                                bottomButtons: [
                                    .confirm()
                                ]
                            )
                        }
                }
                .foregroundStyle(Color.secondText)
                Spacer()
                Text("user.setup.action.phone.unbind")
                    .padding(.vertical, 8)
                    .padding(.horizontal, 15)
                    .foregroundColor(.red.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.red.opacity(0.5), lineWidth: 2)
                    )
                    .exclusiveTouchTapGesture {
                        deviceManager.unbindDevice(at: position)
                        ToastManager.shared.show(toast: Toast(message: "user.page.unbind_device.result.success"))
                    }
            } else {
                // 未绑定状态
                if isLoading == position {
                    ProgressView()
                } else {
                    Text("user.setup.action.phone.bind")
                        .padding(.vertical, 8)
                        .padding(.horizontal, 15)
                        .foregroundColor(.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(deviceManager.isBound(at: position) ? Color.green.opacity(0.8) : Color.gray, lineWidth: 2)
                        )
                        .exclusiveTouchTapGesture {
                            selectedPosition = position
                        }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(deviceManager.isBound(at: position) ? Color.green : Color.gray, lineWidth: 2)
        )
    }
}

#Preview {
    let appState = AppState.shared
    return SensorBindView()
        .environmentObject(appState)
}
