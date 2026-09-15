//
//  OnboardingView.swift
//  Tapst (MemoTap)
//
//  First-launch onboarding, 3 steps:
//   1) write your first memo, 2) see it went to the Lock Screen,
//   3) choose a capture method (opens the matching guide).
//  Monochrome, adaptive to Light/Dark mode.
//

import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var step = 0
    @State private var memo = ""
    @State private var selected: GuideTopic?
    @FocusState private var inputFocused: Bool

    private let accent = Color(red: 0.36, green: 0.56, blue: 0.98)

    private var savedMemo: String {
        let t = memo.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? String(localized: "헬스 가기") : t
    }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                switch step {
                case 0: inputStep
                case 1: confirmStep
                default: methodStep
                }

                Spacer(minLength: 0)

                bottomButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
            }
            .padding(.top, 24)
        }
        .animation(.easeInOut(duration: 0.25), value: step)
        .sheet(item: $selected) { topic in
            GuideDetailView(topic: topic)
        }
    }

    // MARK: Step 1 — write a memo

    private var inputStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("메모탭으로,\n잠금화면에")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.primary)
                Text("메모를 적어보세요.")
                    .font(.headline)
                    .fontWeight(.regular)
                    .foregroundStyle(.secondary)
            }

            TextField("", text: $memo, prompt: Text("새로운 메모").foregroundColor(.secondary))
                .foregroundStyle(.primary)
                .font(.title3)
                .focused($inputFocused)
                .submitLabel(.done)
                .onSubmit(advanceFromInput)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal, 24)
        .onAppear { inputFocused = true }
    }

    // MARK: Step 2 — it's on the Lock Screen

    private var confirmStep: some View {
        VStack(spacing: 24) {
            lockScreenMock
            VStack(spacing: 8) {
                Text("방금 잠금화면에 올라갔어요")
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                Text("지금 바로 확인해보세요.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 24)
    }

    private var lockScreenMock: some View {
        VStack(spacing: 6) {
            Image(systemName: "lock.fill")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
            Text(Date(), format: .dateTime.hour().minute())
                .font(.system(size: 60, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
            Text(Date(), format: .dateTime.month().day().weekday(.wide))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Circle()
                    .strokeBorder(.primary.opacity(0.85), lineWidth: 2.5)
                    .frame(width: 26, height: 26)
                Text(savedMemo)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
            .padding(.top, 14)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 28))
    }

    // MARK: Step 3 — choose a method

    private var methodStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Text("메모탭 이렇게 활용하세요")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.primary)
                Text("앱을 켜지 않고도 추가할 수 있어요.")
                    .font(.headline)
                    .fontWeight(.regular)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 14) {
                ForEach(GuideTopic.allCases) { topic in
                    Button { selected = topic } label: { methodCard(topic) }
                        .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 24)
    }

    private func methodCard(_ topic: GuideTopic) -> some View {
        HStack(spacing: 14) {
            Image(systemName: topic.icon)
                .font(.title2)
                .foregroundStyle(.primary)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(topic.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(topic.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: Bottom button

    private var bottomButton: some View {
        Button(action: primaryAction) {
            Text(step == 2 ? "시작하기" : "다음")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(accent, in: Capsule())
                .foregroundStyle(.white)
        }
        .opacity(step == 0 && memo.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
        .disabled(step == 0 && memo.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    private func primaryAction() {
        switch step {
        case 0: advanceFromInput()
        case 1: withAnimation { step = 2 }
        default: hasSeenOnboarding = true
        }
    }

    private func advanceFromInput() {
        let text = memo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        TaskStore.shared.add(text)      // saves + starts the Lock Screen Live Activity
        inputFocused = false
        withAnimation { step = 1 }
    }
}

#Preview {
    OnboardingView()
}
