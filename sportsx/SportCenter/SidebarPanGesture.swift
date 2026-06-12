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

            // 落点位于浮层区域（如运动中的比赛浮窗）→ 让位给浮层自身的拖动手势
            if isInsideExcludedArea(at: pan.location(in: window), in: window) { return false }

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

        // 触摸落点位于浮层让位区域（如比赛浮窗）时，从源头就不接收该触摸，
        // 比 shouldBegin 更早，避免边缘时序窗口里仍与浮层拖动同时响应
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldReceive touch: UITouch
        ) -> Bool {
            guard let window = pan?.view as? UIWindow else { return true }
            return !isInsideExcludedArea(at: touch.location(in: window), in: window)
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

        /// 落点是否位于浮层让位区域内。
        ///
        /// 浮层（如比赛浮窗）自带 SwiftUI 拖动手势，但其本身不会生成独立 `UIView`，
        /// 无法靠 `hitTest` 识别；故由浮层用 `SidebarGestureExcludedArea` 在自身区域埋一个
        /// 不可交互的标记视图，这里遍历窗口找到该标记并按其窗口坐标系下的 frame 判断落点。
        private func isInsideExcludedArea(at point: CGPoint, in window: UIWindow) -> Bool {
            func search(_ view: UIView) -> Bool {
                for subview in view.subviews {
                    if subview.tag == SidebarGestureExcludedArea.tag,
                       subview.convert(subview.bounds, to: window).contains(point) {
                        return true
                    }
                    if search(subview) { return true }
                }
                return false
            }
            return search(window)
        }
    }
}

/// 浮层让位标记：放在浮层（如比赛浮窗）的可拖动区域内（不可交互、不影响布局与触摸），
/// 供 `SidebarPanGesture` 据此让位，避免在浮层上拖动时同时触发侧边栏唤出/收起手势。
struct SidebarGestureExcludedArea: UIViewRepresentable {
    /// 约定的私有 tag，用于在窗口层级中定位标记视图
    static let tag = 990_601

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.tag = Self.tag
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
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
