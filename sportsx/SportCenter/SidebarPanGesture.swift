//
//  SidebarPanGesture.swift
//  sportsx
//
//  Created by 任杰 on 2026/6/6.
//

import SwiftUI

/// 运动中心侧边栏的「全屏唤出 / 收起」手势。
///
/// 在 window 上挂载 `UIPanGestureRecognizer` + 委托仲裁，实现「全屏右滑唤出、左滑收起」，
/// 并在以下情况主动让位，避免与内容手势冲突（对齐 X 的体感）：
/// - 纵向意图（刷列表）→ 让位给纵向 `ScrollView`；
/// - 落点位于可横向滚动的 `ScrollView`（如赛事轮播）→ 让位给该 `ScrollView`。
///
/// 之所以挂到 window 而非叠加在内容之上，是为了不吞掉点击/滚动；是否生效完全交由委托判定。
struct SidebarPanGesture: UIViewRepresentable {
    /// 仅在需要时启用（如：运动中心 tab、导航栈根层、无登录页遮挡）
    let enabled: Bool
    /// 当前侧边栏是否已展开（= NavigationManager.showSideBar）
    let isOpen: Bool
    /// 拖动过程回调，参数为水平位移
    let onChanged: (CGFloat) -> Void
    /// 拖动结束回调，参数为水平位移与水平速度
    let onEnded: (_ translationX: CGFloat, _ velocityX: CGFloat) -> Void

    func makeUIView(context: Context) -> PanHostView {
        let coordinator = context.coordinator
        let view = PanHostView()
        view.onAttachToWindow = { window in
            guard coordinator.pan == nil else { return }
            let pan = UIPanGestureRecognizer(
                target: coordinator,
                action: #selector(Coordinator.handlePan(_:))
            )
            pan.delegate = coordinator
            pan.cancelsTouchesInView = true         // 一旦识别为横向拖动，取消底层视图触摸（点击不触发故不受影响）
            window.addGestureRecognizer(pan)
            coordinator.pan = pan
        }
        return view
    }

    func updateUIView(_ uiView: PanHostView, context: Context) {
        context.coordinator.parent = self
    }

    static func dismantleUIView(_ uiView: PanHostView, coordinator: Coordinator) {
        if let pan = coordinator.pan {
            pan.view?.removeGestureRecognizer(pan)
            coordinator.pan = nil
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    // MARK: - Coordinator

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: SidebarPanGesture
        weak var pan: UIPanGestureRecognizer?
        var lockedScrollViews: [UIScrollView] = []   // 拖动期间被临时禁用滚动的视图（含嵌套）

        init(_ parent: SidebarPanGesture) { self.parent = parent }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let window = gesture.view as? UIWindow else { return }
            let translationX = gesture.translation(in: window).x
            switch gesture.state {
            case .began:
                // 锁定触点路径上所有滚动视图，避免横向拖动时内容（含嵌套列表）跟随上下滚动
                lockScrollViews(at: gesture.location(in: window), in: window)
                parent.onChanged(translationX)
            case .changed:
                parent.onChanged(translationX)
            case .ended, .cancelled, .failed:
                unlockScrollViews()
                parent.onEnded(translationX, gesture.velocity(in: window).x)
            default:
                break
            }
        }

        /// 临时禁用触点到根视图路径上的所有滚动视图（含嵌套），拖动结束后恢复
        private func lockScrollViews(at point: CGPoint, in window: UIWindow) {
            var view: UIView? = window.hitTest(point, with: nil)
            while let current = view {
                if let scrollView = current as? UIScrollView, scrollView.isScrollEnabled {
                    scrollView.isScrollEnabled = false
                    lockedScrollViews.append(scrollView)
                }
                view = current.superview
            }
        }

        private func unlockScrollViews() {
            for scrollView in lockedScrollViews {
                scrollView.isScrollEnabled = true
            }
            lockedScrollViews.removeAll()
        }

        // 仲裁：只有「该侧边栏管」的拖动才起手
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard parent.enabled,
                  PopupWindowManager.shared.popups.isEmpty,    // 有弹窗时让位
                  let pan = pan,
                  let window = pan.view as? UIWindow
            else { return false }

            let velocity = pan.velocity(in: window)
            // 纵向意图 → 让位给纵向滚动
            guard abs(velocity.x) > abs(velocity.y) else { return false }

            if parent.isOpen {
                // 已展开：仅向左拖动可收起
                return velocity.x < 0
            } else {
                // 未展开：仅向右拖动可唤出
                guard velocity.x > 0 else { return false }
                // 落点位于可横向滚动的 ScrollView → 让位
                return !isInsideHorizontalScrollView(at: pan.location(in: window), in: window)
            }
        }

        // 未起手时让内容手势（点击/滚动）正常工作
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            return true
        }

        /// 命中测试：从触点向上回溯，是否存在可横向滚动的 `UIScrollView`
        private func isInsideHorizontalScrollView(at point: CGPoint, in window: UIWindow) -> Bool {
            var view: UIView? = window.hitTest(point, with: nil)
            while let current = view {
                if let scrollView = current as? UIScrollView,
                   scrollView.isScrollEnabled,
                   scrollView.contentSize.width > scrollView.bounds.width {
                    return true
                }
                view = current.superview
            }
            return false
        }
    }
}

/// 承载 window 级手势的宿主视图：进入 window 后回调挂载手势。
final class PanHostView: UIView {
    var onAttachToWindow: ((UIWindow) -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if let window = window {
            onAttachToWindow?(window)
        }
    }
}
