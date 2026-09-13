//
//  GuideView.swift
//  Tapst (MemoTap)
//
//  Guide hub + 툭-style guide detail (title, demo video placeholder, numbered
//  steps, 완료 button). Real demo videos are dropped in later.
//

import SwiftUI
import AVKit

/// The capture methods we provide a guide for.
enum GuideTopic: String, Identifiable, CaseIterable {
    case tap        // 뒷면 탭
    case shortcut   // 잠금화면 '단축어' 위젯

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tap: return "탭으로 메모하기"
        case .shortcut: return "단축키로 메모하기"
        }
    }

    var subtitle: String {
        switch self {
        case .tap: return "아이폰 뒷면을 두 번 탭해서 바로 적기"
        case .shortcut: return "잠금화면 단축키를 눌러 바로 적기"
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
        switch self {
        case .tap: return "가이드 [문의하기](mailto:marcap.official@gmail.com)\n24시간 365일 열려있어요!"
        case .shortcut: return "가이드 [문의하기](mailto:marcap.official@gmail.com)\n24시간 365일 열려있어요!"
        }
    }

    /// Bundled demo clip for this guide.
    var videoName: String {
        switch self {
        case .tap: return "guide_tap"
        case .shortcut: return "guide_shortcut"
        }
    }

    /// Numbered setup steps the user performs on their iPhone.
    var steps: [String] {
        switch self {
        case .tap:
            return [
                "단축어 앱에서 ‘+’를 클릭하고 ‘Add memo’를 추가해요.",
                "'설정 › 손쉬운 사용 › 터치 › 뒷면 탭 › 두 번 탭'에서 방금 만든 단축어 Add memo를 선택해요."
            ]
        case .shortcut:
            return [
                "잠금화면을 길게 누르고 하단의 사용자화를 클릭해요.",
                "상단의 제어 항목 검색에서 ‘단축어 실행’을 입력 후 선택을 클릭해요.",
                "상단의 단축어 검색에서 ’메모탭’을 입력하고 '할 일 추가'를 선택해요. 우측 상단의 완료를 클릭해요."
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
                        ForEach(Array(topic.steps.enumerated()), id: \.offset) { index, step in
                            GuideStepCard(number: index + 1, text: step)
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

    @ViewBuilder
    private var demoVideo: some View {
        if let url = Bundle.main.url(forResource: topic.videoName, withExtension: "mov") {
            // Dark card with the full video fit inside (letterboxed, never cropped).
            ZStack {
                Color.black
                // Size the player to the EXACT video ratio (540:1170) so it can
                // never be cropped, centered on the black card (letterbox).
                LoopingVideoPlayer(url: url)
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
    // Make the view's backing layer the AVPlayerLayer so it always tracks the
    // view's bounds and honors videoGravity (fixes the earlier crop issue where
    // a manually-sized sublayer filled instead of fitting).
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    private let queuePlayer = AVQueuePlayer()
    private var looper: AVPlayerLooper?

    init(url: URL) {
        super.init(frame: .zero)
        let item = AVPlayerItem(url: url)
        looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
        queuePlayer.isMuted = true
        playerLayer.player = queuePlayer
        playerLayer.videoGravity = .resizeAspect   // fit whole frame, never crop
        queuePlayer.play()
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
