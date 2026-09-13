//
//  PaywallView.swift
//  Tapst (MemoTap)
//
//  MemoTap Pro paywall. Adaptive to Light/Dark; blue accent.
//  Includes StoreKit purchase, restore, and the legal links App Review expects.
//

import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store = ProStore.shared
    @State private var selected: ProPlan = .yearly
    @State private var legalDoc: LegalDoc?

    private let accent = Color(red: 0.36, green: 0.56, blue: 0.98)
    private let features: [(icon: String, text: String)] = [
        ("infinity", "잠금화면 메모 무제한 생성"),
        ("paintpalette.fill", "다양한 테마 지원 (카드·텍스트 색상)"),
        ("textformat", "글꼴 · 굵기 선택")
    ]

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 22) {
                    header
                    featureCard
                    planPicker
                }
                .padding(20)
                .padding(.bottom, 190)
            }

            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .padding(10)
                            .background(Color(.secondarySystemBackground), in: Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                Spacer()
                bottomBar
            }
        }
        .sheet(item: $legalDoc) { LegalView(doc: $0) }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image("AppLogo")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 84, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            Text("메모탭 Pro")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.primary)
            Text("메모를 무제한으로, 나만의 스타일로.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 44)
    }

    private var featureCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(features, id: \.text) { f in
                HStack(spacing: 14) {
                    Image(systemName: f.icon)
                        .font(.headline)
                        .foregroundStyle(accent)
                        .frame(width: 26)
                    Text(f.text)
                        .font(.callout)
                        .foregroundStyle(.primary)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
    }

    private var planPicker: some View {
        VStack(spacing: 12) {
            ForEach(ProPlan.allCases) { plan in
                Button { selected = plan } label: { planRow(plan) }
                    .buttonStyle(.plain)
            }
        }
    }

    private func planRow(_ plan: ProPlan) -> some View {
        let isSel = selected == plan
        return HStack(spacing: 14) {
            Image(systemName: isSel ? "largecircle.fill.circle" : "circle")
                .font(.title3)
                .foregroundStyle(isSel ? accent : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(plan.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                if let note = plan.note {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(store.displayPrice(for: plan))
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isSel ? accent : .clear, lineWidth: 2)
        )
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            Button {
                if store.isPro { dismiss() }
                else { Task { await store.purchase(selected) } }
            } label: {
                ZStack {
                    if store.purchasing {
                        ProgressView().tint(.white)
                    } else {
                        Text(store.isPro ? "이미 Pro를 사용 중이에요" : "구독 시작하기")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(accent, in: Capsule())
                .foregroundStyle(.white)
            }
            .disabled(store.isPro || store.purchasing)

            HStack(spacing: 18) {
                Button("구입복원") { Task { await store.restorePurchases() } }
                Button("이용약관") { legalDoc = .terms }
                Button("개인정보처리방침") { legalDoc = .privacy }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 14)
        .background(
            LinearGradient(colors: [Color(.systemBackground).opacity(0), Color(.systemBackground)],
                           startPoint: .top, endPoint: .bottom)
        )
    }
}

#Preview {
    PaywallView()
}
