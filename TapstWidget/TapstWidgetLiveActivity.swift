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

    /// Applies the user's independent text-size and mark-size preferences (Basic).
    /// Text/gap/spacing follow the text scale; only the ring follows the mark scale.
    func scaled(text ts: CGFloat, mark ms: CGFloat) -> TapstRowMetrics {
        TapstRowMetrics(text: text * ts, ring: ring * ms, gap: gap * ts, spacing: spacing * ts, vPadding: vPadding)
    }
}

/// The completion mark as a hollow outline in the user's chosen shape, sized to
/// `size`. Resizable so the outline (and its stroke) scale proportionally.
struct TapstMarkView: View {
    let shapeRaw: String
    let size: CGFloat
    let color: Color

    var body: some View {
        Image(systemName: TapstDesignKit.markSymbol(shapeRaw))
            .resizable()
            .scaledToFit()
            .foregroundStyle(color)
            .frame(width: size, height: size)
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
                if !context.state.hideDynamicIsland {
                    Image(systemName: "checklist")
                }
            } compactTrailing: {
                if !context.state.hideDynamicIsland {
                    Text("\(context.state.tasks.count)").fontWeight(.semibold)
                }
            } minimal: {
                if !context.state.hideDynamicIsland {
                    Text("\(context.state.tasks.count)")
                }
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
    private var metrics: TapstRowMetrics {
        .forCount(min(count, cap)).scaled(text: CGFloat(state.textScale), mark: CGFloat(state.markScale))
    }

    private var textColor: Color { TapstDesignKit.textColor(state.textColorID) }
    private var memoFont: Font {
        TapstDesignKit.memoFont(state.fontDesignRaw, size: metrics.text, bold: state.fontBold)
    }

    var body: some View {
        // Timetable (Pro) and the task checklist are fully independent layouts.
        if state.mode == "schedule" {
            scheduleContent
        } else {
            taskContent
        }
    }

    // MARK: Tasks (unchanged behavior)

    private var taskContent: some View {
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
                        markShape: state.markShapeRaw,
                        completing: state.completingIDs.contains(task.id.uuidString),
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
            TapstMarkView(shapeRaw: state.markShapeRaw, size: metrics.ring, color: textColor.opacity(0.5))
            Text("뒷면을 탭해 추가하세요")
                .font(memoFont)
                .foregroundStyle(textColor.opacity(0.6))
                .lineLimit(1)
        }
    }

    // MARK: Timetable (Pro) — digital time column + text, chronological

    /// A fixed-width time column keeps the time/text split perfectly aligned across
    /// every row; a thin divider makes the two zones unmistakable. Capped at
    /// TapstStorage.maxScheduleItems so all rows stay legible at full size.
    private var scheduleContent: some View {
        let s = CGFloat(state.textScale)
        let timeSize = 17 * s
        let textSize = 19 * s
        let timeCol = 64 * s
        let font = TapstDesignKit.memoFont(state.fontDesignRaw, size: textSize, bold: state.fontBold)
        // Show *today's* items, computed at render so the card flips at midnight.
        // Independent of the toggle: recurring weekdays always show, and a one-time
        // (toggle-off) entry still shows on its own occurrence day.
        let items = TapstStorage.lockScreenScheduleItems(from: state.schedule,
                                                         enabled: state.scheduleWeekdays)

        // spacing 0: the inter-row gap is provided by the dashed connectors so the
        // dashes fall exactly between consecutive times (n rows → n-1 connectors).
        return VStack(alignment: .leading, spacing: 0) {
            if items.isEmpty {
                scheduleRow(time: "--:--", text: String(localized: "오늘 시간표가 없어요"),
                            timeCol: timeCol, timeSize: timeSize, textSize: textSize,
                            font: font, dim: true)
            } else {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    scheduleRow(time: tapstTimeString(hour: item.hour, minute: item.minute),
                                text: item.text,
                                timeCol: timeCol, timeSize: timeSize, textSize: textSize,
                                font: font, dim: false)
                    // Dashed link in the gap between this time and the next only.
                    if index < items.count - 1 {
                        colonConnector(x: timeSize * 1.5, gap: 14 * s, s: s)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, TapstDesign.hPadding)
        .padding(.vertical, 14)
    }

    /// A short dashed segment sitting in the gap between two consecutive time rows,
    /// aligned under the colon (~timeSize * 1.5 from the leading edge), so the times
    /// read as links in one chronological chain with a clean break at each time.
    private func colonConnector(x: CGFloat, gap: CGFloat, s: CGFloat) -> some View {
        HStack(spacing: 0) {
            TapstDashedVLine()
                .stroke(textColor.opacity(0.35),
                        style: StrokeStyle(lineWidth: 1, dash: [2 * s, 3 * s]))
                .frame(width: 1, height: gap)
                .offset(x: x)
            Spacer(minLength: 0)
        }
    }

    private func scheduleRow(time: String, text: String, timeCol: CGFloat,
                             timeSize: CGFloat, textSize: CGFloat, font: Font, dim: Bool) -> some View {
        HStack(spacing: 0) {
            Text(time)
                .font(.system(size: timeSize, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(textColor.opacity(dim ? 0.5 : 1))
                .frame(width: timeCol, alignment: .leading)
            Rectangle()
                .fill(textColor.opacity(0.25))
                .frame(width: 1, height: textSize * 1.1)
                .padding(.trailing, 12)
            Text(text)
                .font(font)
                .foregroundStyle(textColor.opacity(dim ? 0.6 : 1))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }
}

/// A full-height vertical line, stroked with a dash pattern to form the
/// timetable's chronological "timeline" spine.
private struct TapstDashedVLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}

/// One checklist row: a tappable ring on the left, then the memo text.
struct TapstChecklistRow: View {
    let task: TapstTask
    let metrics: TapstRowMetrics
    let font: Font
    let textColor: Color
    var markShape: String = "circle"
    var completing: Bool = false
    var overflowBadge: Int? = nil

    var body: some View {
        HStack(spacing: metrics.gap) {
            Button(intent: CompleteTaskIntent(taskID: task.id.uuidString)) {
                ZStack {
                    TapstMarkView(shapeRaw: markShape, size: metrics.ring, color: textColor.opacity(0.85))
                    if completing {
                        // Brief "done" checkmark inside the mark before the row is removed.
                        Image(systemName: "checkmark")
                            .font(.system(size: metrics.ring * 0.62, weight: .bold))
                            .foregroundStyle(textColor)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
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
