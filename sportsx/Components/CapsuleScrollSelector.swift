//
//  CapsuleScrollSelector.swift
//  sportsx
//
//  统一的横向滚动胶囊选择器，替代系统 Picker（规避其显示 bug），
//  样式对齐路线创建页：未展开时显示当前值 + 提示图标，点击后横向展开所有选项。
//

import SwiftUI

struct CapsuleScrollSelector<T: Hashable>: View {
    let options: [T]
    @Binding var selection: T
    /// 返回每个选项用于展示的本地化 key
    let titleKey: (T) -> String
    /// 未展开态尾部的提示图标（筛选用 arrow.left.arrow.right，排序用 arrow.up.arrow.down）
    var icon: String = "arrow.left.arrow.right"
    /// 展开态横向滚动区域的最大宽度
    var expandedWidth: CGFloat = 200
    /// 选项发生「真实变化」后回调（值未变则不触发），用于触发重新查询等副作用
    var onSelect: ((T) -> Void)? = nil

    @State private var isSelecting: Bool = false
    
    var backgroundColor: Color = Color.defaultBackground

    var body: some View {
        if isSelecting {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(options, id: \.self) { option in
                        Text(LocalizedStringKey(titleKey(option)))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(selection == option ? Color.white : Color.thirdText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(selection == option ? Color.orange : Color.secondBackground)
                            )
                            .exclusiveTouchTapGesture {
                                isSelecting = false
                                guard option != selection else { return }
                                selection = option
                                onSelect?(option)
                            }
                    }
                }
            }
            .frame(maxWidth: expandedWidth)
        } else {
            HStack(spacing: 4) {
                Text(LocalizedStringKey(titleKey(selection)))
                    .foregroundStyle(Color.white)
                    .font(.system(size: 13, weight: .medium))
                Image(systemName: icon)
                    .foregroundStyle(Color.secondText)
                    .font(.system(size: 10, weight: .light))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(backgroundColor)
                    .overlay(
                        Capsule()
                            .stroke(Color.orange, lineWidth: 1)
                    )
            )
            .exclusiveTouchTapGesture {
                isSelecting = true
            }
        }
    }
}
