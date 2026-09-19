//
//  GuideView.swift
//  Tapst (MemoTap)
//
//  Guide hub + 툭-style guide detail (title, demo video placeholder, numbered
//  steps, 완료 button). Real demo videos are dropped in later.
//

import SwiftUI
import AVKit
import UIKit

/// The capture methods we provide a guide for.
enum GuideTopic: String, Identifiable, CaseIterable {
    case tap        // 뒷면 탭
    case shortcut   // 잠금화면 '단축어' 위젯

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tap: return String(localized: "탭으로 메모하기")
        case .shortcut: return String(localized: "단축키로 메모하기")
        }
    }

    var subtitle: String {
        switch self {
        case .tap: return String(localized: "아이폰 뒷면을 두 번 탭해서 바로 메모")
        case .shortcut: return String(localized: "잠금화면 단축키를 눌러 바로 메모")
        }
    }

    var icon: String {
        switch self {
        case .tap: return "hand.tap.fill"
        case .shortcut: return "lock.rectangle.on.rectangle.fill"
        }
    }

    /// The two-line headline at the top of the detail sheet.
    var headline: String {
        // Same headline for both topics; localized via the string catalog.
        String(localized: "가이드 [문의하기](mailto:marcap.official@gmail.com)\n24시간 365일 열려있어요!")
    }

    /// Bundled demo clip for this guide. Prefers a language-specific clip
    /// (e.g. "guide_tap_en") when one is bundled, falling back to the base clip.
    var videoName: String {
        let base: String
        switch self {
        case .tap: base = "guide_tap"
        case .shortcut: base = "guide_shortcut"
        }
        // If the device's language has a matching localized clip, use it.
        if let lang = Locale.current.language.languageCode?.identifier {
            let localized = "\(base)_\(lang)"
            if Bundle.main.url(forResource: localized, withExtension: "mov") != nil {
                return localized
            }
        }
        return base
    }

    /// Numbered setup steps the user performs on their iPhone.
    var steps: [String] {
        switch self {
        case .tap:
            return [
                String(localized: "'설정 › 손쉬운 사용 › 터치 › 뒷면 탭 › 두 번 탭'에서 'memotap'을 선택해요.")
            ]
        case .shortcut:
            return [
                String(localized: "잠금화면을 길게 누르고 하단의 '사용자화'를 클릭해요."),
                String(localized: "상단의 제어 항목 검색에서 ‘단축어 실행’을 입력 후 선택을 클릭해요."),
                String(localized: "상단의 단축어 검색에서 ’메모탭’을 입력하고 '할 일 추가'를 선택해요. 우측 상단의 완료를 클릭해요.")
            ]
        }
    }
}

// MARK: - Guide hub

struct GuideListView: View {
    @State private var selected: GuideTopic?

    var body: some View {
        List {
            Section("메모 추가 방법") {
                ForEach(GuideTopic.allCases) { topic in
                    Button {
                        selected = topic
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: topic.icon)
                                .frame(width: 28)
                                .foregroundStyle(.tint)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(topic.title)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                Text(topic.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote.bold())
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
        .navigationTitle("가이드 보기")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selected) { topic in
            GuideDetailView(topic: topic)
        }
    }
}

// MARK: - Guide detail (툭-style)

struct GuideDetailView: View {
    let topic: GuideTopic
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(headlineMarkdown)
                        .font(.system(size: 26, weight: .bold))
                        .tint(.blue)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)

                    demoVideo

                    VStack(spacing: 10) {
                        if topic == .tap {
                            // Step 1 is a one-tap import of the ready-made shortcut,
                            // replacing the old "build it yourself" instruction.
                            shortcutImportStep
                            ForEach(Array(topic.steps.enumerated()), id: \.offset) { index, step in
                                GuideStepCard(number: index + 2, text: step)
                            }
                        } else {
                            ForEach(Array(topic.steps.enumerated()), id: \.offset) { index, step in
                                GuideStepCard(number: index + 1, text: step)
                            }
                        }
                    }
                }
                .padding(20)
            }

            Button {
                dismiss()
            } label: {
                Text("완료")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.primary, in: Capsule())
                    .foregroundStyle(Color(.systemBackground))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .presentationDragIndicator(.visible)
    }

    /// Renders the headline as markdown so the "문의하기" mailto link is tappable.
    private var headlineMarkdown: AttributedString {
        (try? AttributedString(
            markdown: topic.headline,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(topic.headline)
    }

    /// Prebuilt "할 일 추가" shortcut shared via iCloud. Tapping opens the import
    /// sheet in the Shortcuts app; one "단축어 추가" tap saves it to "나의 단축어"
    /// so it shows up in the Back Tap / Lock Screen shortcut list — no manual
    /// building required.
    private static let addMemoShortcutURL =
        URL(string: "https://www.icloud.com/shortcuts/31dde7178a3b4ba9b93c1b85beab220b")!

    /// Probe used to detect whether the (removable) Shortcuts app is installed.
    /// Requires "shortcuts" in Info.plist ▸ LSApplicationQueriesSchemes.
    private static let shortcutsProbeURL = URL(string: "shortcuts://")!

    /// Apple's Shortcuts app on the App Store, opened when it isn't installed.
    private static let shortcutsAppStoreURL = URL(string: "https://apps.apple.com/app/id915249334")!

    /// Opens the ready-made shortcut import when Shortcuts is installed; otherwise
    /// sends the user to install Shortcuts from the App Store first.
    private func openShortcutImport() {
        if UIApplication.shared.canOpenURL(Self.shortcutsProbeURL) {
            openURL(Self.addMemoShortcutURL)
        } else {
            openURL(Self.shortcutsAppStoreURL)
        }
    }

    /// Step 1 of the tap guide: a single tappable card (numbered like the other
    /// steps) that imports the ready-made shortcut with one tap — styled like a
    /// Shortcuts-app row (gradient glyph tile + label + chevron).
    @ViewBuilder
    private var shortcutImportStep: some View {
        Button {
            openShortcutImport()
        } label: {
            HStack(alignment: .center, spacing: 14) {
                Text("1")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color(.systemBackground))
                    .frame(width: 26, height: 26)
                    .background(.primary, in: Circle())

                Image(systemName: "square.2.layers.3d.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.42, green: 0.31, blue: 0.90),
                                     Color(red: 0.30, green: 0.55, blue: 0.98)],
                            startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 8)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("단축어 추가하기")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("에서 '단축어 추가'를 클릭해요.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var demoVideo: some View {
        if let url = Bundle.main.url(forResource: topic.videoName, withExtension: "mov") {
            // Black card; player is constrained to exact 1170:2532 ratio so
            // SwiftUI gives the UIView precise bounds — guarantees no crop.
            ZStack {
                Color.black
                LoopingVideoPlayer(url: url)
                    .aspectRatio(CGSize(width: 1170, height: 2532), contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: 440)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 440)
            .clipShape(RoundedRectangle(cornerRadius: 22))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.secondarySystemBackground))
                VStack(spacing: 10) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("가이드 영상 준비 중")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 380)
        }
    }
}

/// A muted, auto-looping video view with no playback controls.
struct LoopingVideoPlayer: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> LoopingPlayerUIView {
        LoopingPlayerUIView(url: url)
    }

    func updateUIView(_ uiView: LoopingPlayerUIView, context: Context) {}
}

final class LoopingPlayerUIView: UIView {
    private let playerLayer = AVPlayerLayer()
    private let queuePlayer = AVQueuePlayer()
    private var looper: AVPlayerLooper?

    init(url: URL) {
        super.init(frame: .zero)
        layer.addSublayer(playerLayer)
        let item = AVPlayerItem(url: url)
        looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
        queuePlayer.isMuted = true
        playerLayer.player = queuePlayer
        playerLayer.videoGravity = .resizeAspect
        queuePlayer.play()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Disable implicit CALayer animation so the frame snaps instantly.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer.frame = bounds
        CATransaction.commit()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

struct GuideStepCard: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(number)")
                .font(.subheadline.bold())
                .foregroundStyle(Color(.systemBackground))
                .frame(width: 26, height: 26)
                .background(.primary, in: Circle())

            Text(text)
                .font(.callout)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    NavigationStack { GuideListView() }
}
