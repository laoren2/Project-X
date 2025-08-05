//
//  ToastSystem.swift
//  sportsx
//
//  Created by 任杰 on 2025/5/19.
//
import SwiftUI
import Foundation

struct Toast: Identifiable, Equatable {
    let id = UUID()
    var message: String
    var duration: TimeInterval
    
    init(
        message: String = "提示",
        duration: TimeInterval = 2
    ) {
        self.message = message
        self.duration = duration
    }
}

struct LoadingToast: Identifiable, Equatable {
    let id = UUID()
    var allowsInteraction: Bool
    
    init(allowsInteraction: Bool = false) {
        self.allowsInteraction = allowsInteraction
    }
}

class ToastManager: ObservableObject {
    static let shared = ToastManager()

    private init() {}

    @Published var currentToast: Toast?
    @Published var currentLoadingToast: LoadingToast?
    
    private var currentTask: Task<Void, Never>?

    func show(toast: Toast) {
        currentTask?.cancel()  // 取消之前的计时任务
        currentToast = toast

        currentTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(toast.duration * 1_000_000_000))
            if !Task.isCancelled {
                await MainActor.run {
                    self.currentToast = nil
                }
            }
        }
    }

    func start(toast: LoadingToast) {
        //currentTask?.cancel()
        currentLoadingToast = toast
    }

    func finish() {
        //currentTask?.cancel()
        currentLoadingToast = nil
    }
}

struct ToastView: View {
    let toast: Toast

    var body: some View {
        Text(toast.message)
            .padding()
            .background(Color.black.opacity(0.6))
            .foregroundColor(.white)
            .cornerRadius(8)
            .padding(.horizontal, 16)
            .transition(.move(edge: .top).combined(with: .opacity))
    }
}

struct LoadingToastView: View {
    var body: some View {
        ProgressView()
            .padding()
            .background(Color.black.opacity(0.5))
            .foregroundColor(.white)
            .cornerRadius(8)
    }
}

struct ToastContainerView<Content: View>: View {
    @ObservedObject var toastManager = ToastManager.shared
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            content
                .disabled(toastManager.currentLoadingToast?.allowsInteraction == false)
            if let toast = toastManager.currentLoadingToast {
                VStack {
                    Spacer()
                    LoadingToastView()
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut, value: toast)
            }
            if let toast = toastManager.currentToast {
                VStack {
                    Spacer()
                    ToastView(toast: toast)
                    Spacer()
                }
                .zIndex(1)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut, value: toast)
            }
        }
    }
}
