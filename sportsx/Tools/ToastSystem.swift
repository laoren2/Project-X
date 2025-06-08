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
    var isProgressing: Bool
    var allowsInteraction: Bool
    
    init(
        message: String = "提示",
        duration: TimeInterval = 2,
        isProgressing: Bool = false,
        allowsInteraction: Bool = true
    ) {
        self.message = message
        self.duration = duration
        self.isProgressing = isProgressing
        self.allowsInteraction = allowsInteraction
    }
}

class ToastManager: ObservableObject {
    static let shared = ToastManager()

    private init() {}

    @Published var currentToast: Toast?
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

    func start(toast: Toast) {
        currentTask?.cancel()
        currentToast = toast
    }

    func finish() {
        currentTask?.cancel()
        currentToast = nil
    }
}

struct ToastView: View {
    let toast: Toast

    var body: some View {
        if toast.isProgressing {
            ProgressView()
                .padding()
                .background(Color.white.opacity(0.2))
                .foregroundColor(.black)
                .cornerRadius(8)
        } else {
            Text(toast.message)
                .padding()
                .background(Color.black.opacity(0.6))
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding(.horizontal, 16)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
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
                .disabled(toastManager.currentToast?.allowsInteraction == false)
                .blur(radius: toastManager.currentToast?.allowsInteraction == false ? 1 : 0)

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
