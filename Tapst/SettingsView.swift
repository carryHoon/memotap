//
//  SettingsView.swift
//  Tapst (MemoTap)
//
//  Settings tab: Pro upgrade + 도움말 (guide).
//

import SwiftUI

struct SettingsView: View {
    @State private var store = ProStore.shared
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button { showPaywall = true } label: { proRow }
                }

                Section("기능") {
                    NavigationLink {
                        DesignSettingsView()
                    } label: {
                        Label("디자인", systemImage: "paintbrush.pointed.fill")
                    }
                    NavigationLink {
                        ConvenienceSettingsView()
                    } label: {
                        Label("편의설정", systemImage: "slider.horizontal.3")
                    }
                }

                Section("도움말") {
                    NavigationLink {
                        GuideListView()
                    } label: {
                        Label("가이드 보기", systemImage: "sparkles")
                    }
                }
            }
            .navigationTitle("설정")
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    private var proRow: some View {
        HStack(spacing: 14) {
            Image(systemName: store.isPro ? "checkmark.seal.fill" : "sparkles")
                .font(.title2)
                .foregroundStyle(store.isPro ? .green : Color(red: 0.36, green: 0.56, blue: 0.98))
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(store.isPro ? "메모탭 Pro 사용 중" : "메모탭 Pro 업그레이드 하기")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(store.isPro ? "모든 기능이 열려 있어요" : "메모 무제한 · 다양한 테마 ·  다양한 글꼴")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !store.isPro {
                Image(systemName: "chevron.right")
                    .font(.footnote.bold())
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Convenience Settings

struct ConvenienceSettingsView: View {
    @State private var hideDynamicIsland: Bool = TapstStorage.hideDynamicIsland
    @State private var hideWhenEmpty: Bool = TapstStorage.hideWhenEmpty

    var body: some View {
        List {
            Section {
                Toggle("다이나믹 아일랜드 숨기기", isOn: $hideDynamicIsland)
                    .onChange(of: hideDynamicIsland) { _, v in
                        TapstStorage.hideDynamicIsland = v
                        Task { await TapstLiveActivity.refresh() }
                    }
                Toggle("할 일이 없으면 숨기기", isOn: $hideWhenEmpty)
                    .onChange(of: hideWhenEmpty) { _, v in
                        TapstStorage.hideWhenEmpty = v
                        Task { await TapstLiveActivity.refresh() }
                    }
            } footer: {
                Text("'할 일이 없으면 숨기기'를 켜면 모든 메모를 완료했을 때 잠금화면 카드가 자동으로 사라져요.")
            }
        }
        .onAppear {
            hideDynamicIsland = TapstStorage.hideDynamicIsland
            hideWhenEmpty = TapstStorage.hideWhenEmpty
        }
        .navigationTitle("편의설정")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SettingsView()
}
