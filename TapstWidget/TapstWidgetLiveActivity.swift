//
//  TapstWidgetLiveActivity.swift
//  TapstWidget
//
//  Lock Screen checklist Live Activity. Appearance (theme color, text color,
//  font, size, limit) is carried in ContentState so every change re-renders.
//  Point-based sizes render identically across iPhones.
//

import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Adaptive row metrics

struct TapstRowMetrics {
    let text: CGFloat
    let ring: CGFloat
    let gap: CGFloat
    let spacing: CGFloat
    let vPadding: CGFloat

    /// Tiers chosen so the rows fit the Live Activity height budget (~160pt).
    static func forCount(_ count: Int) -> TapstRowMetrics {
        switch min(count, 6) {
        case 0, 1, 2, 3: return .init(text: 26, ring: 30, gap: 16, spacing: 18, vPadding: 16)
        case 4:          return .init(text: 20, ring: 24, gap: 14, spacing: 12, vPadding: 13)
        case 5:          return .init(text: 16, ring: 20, gap: 12, spacing: 9,  vPadding: 10)
        default:         return .init(text: 14, ring: 18, gap: 11, spacing: 6,  vPadding: 8)
        }
    }

    /// Applies the user's text-size preference (Basic feature).
    func scaled(_ s: CGFloat) -> TapstRowMetrics {
        TapstRowMetrics(text: text * s, ring: ring * s, gap: gap * s, spacing: spacing * s, vPadding: vPadding)
    }
}

private enum TapstDesign {
    static let hPadding: CGFloat = 22
}

struct TapstWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TapstActivityAttributes.self) { context in
            TapstChecklistView(state: context.state)
                .widgetURL(URL(string: "tapst://all"))
                .activityBackgroundTint(TapstDesignKit.color(context.state.themeColorID).opacity(0.5))
                .activitySystemActionForegroundColor(TapstDesignKit.textColor(context.state.textColorID))

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    TapstChecklistView(state: context.state)
                }
            } compactLeading: {
                Image(systemName: "checklist")
            } compactTrailing: {
                Text("\(context.state.tasks.count)").fontWeight(.semibold)
            } minimal: {
                Text("\(context.state.tasks.count)")
            }
        }
    }
}

/// The adaptive checklist card, fully driven by ContentState.
struct TapstChecklistView: View {
    let state: TapstActivityAttributes.ContentState

    private var tasks: [TapstTask] { state.tasks }
    private var count: Int { tasks.count }
    private var cap: Int { max(1, state.limit) }
    private var overflow: Bool { count > cap }
    private var visibleCount: Int { min(count, cap) }
    private var metrics: TapstRowMetrics { .forCount(min(count, cap)).scaled(CGFloat(state.textScale)) }

    private var textColor: Color { TapstDesignKit.textColor(state.textColorID) }
    private var memoFont: Font {
        TapstDesignKit.memoFont(state.fontDesignRaw, size: metrics.text, bold: state.fontBold)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.spacing) {
            if tasks.isEmpty {
                emptyRow
            } else {
                let visible = Array(tasks.prefix(visibleCount).enumerated())
                ForEach(visible, id: \.element.id) { index, task in
                    let isLast = index == visibleCount - 1
                    TapstChecklistRow(
                        task: task,
                        metrics: metrics,
                        font: memoFont,
                        textColor: textColor,
                        overflowBadge: (overflow && isLast) ? (count - visibleCount) : nil
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, TapstDesign.hPadding)
        .padding(.vertical, metrics.vPadding)
    }

    private var emptyRow: some View {
        HStack(spacing: metrics.gap) {
            Circle()
                .strokeBorder(textColor.opacity(0.5), lineWidth: 2.5)
                .frame(width: metrics.ring, height: metrics.ring)
            Text("뒷면을 탭해 추가하세요")
                .font(memoFont)
                .foregroundStyle(textColor.opacity(0.6))
                .lineLimit(1)
        }
    }
}

/// One checklist row: a tappable ring on the left, then the memo text.
struct TapstChecklistRow: View {
    let task: TapstTask
    let metrics: TapstRowMetrics
    let font: Font
    let textColor: Color
    var overflowBadge: Int? = nil

    var body: some View {
        HStack(spacing: metrics.gap) {
            Button(intent: CompleteTaskIntent(taskID: task.id.uuidString)) {
                Circle()
                    .strokeBorder(textColor.opacity(0.85), lineWidth: metrics.ring > 22 ? 2.5 : 2)
                    .frame(width: metrics.ring, height: metrics.ring)
            }
            .buttonStyle(.plain)

            Text(task.text)
                .font(font)
                .foregroundStyle(textColor)
                .lineLimit(1)

            Spacer(minLength: 8)

            if let overflowBadge {
                HStack(spacing: 2) {
                    Text("+\(overflowBadge)")
                        .font(.system(size: max(12, metrics.text * 0.6), weight: .bold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: max(9, metrics.text * 0.45), weight: .bold))
                }
                .foregroundStyle(textColor.opacity(0.75))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(textColor.opacity(0.15), in: Capsule())
                .layoutPriority(1)
                .fixedSize()
            }
        }
    }
}

extension TapstActivityAttributes {
    fileprivate static var preview: TapstActivityAttributes { TapstActivityAttributes() }
}

extension TapstActivityAttributes.ContentState {
    fileprivate static var sample: TapstActivityAttributes.ContentState {
        .init(tasks: [
            TapstTask(text: "다이소 가기"),
            TapstTask(text: "오마이갓"),
            TapstTask(text: "헬스 가기")
        ], limit: 5)
    }
}

#Preview("Lock Screen", as: .content, using: TapstActivityAttributes.preview) {
    TapstWidgetLiveActivity()
} contentStates: {
    TapstActivityAttributes.ContentState.sample
}
