//
//  DesignSettingsView.swift
//  Tapst (MemoTap)
//
//  Lock Screen card appearance. Text size is free (Basic); theme color and font
//  are MemoTap Pro. Changes persist to shared storage and refresh the card.
//

import SwiftUI

struct DesignSettingsView: View {
    @State private var store = ProStore.shared
    @State private var showPaywall = false

    @State private var textScale: Double = TapstStorage.textScale
    @State private var themeColorID: String = TapstStorage.themeColorID
    @State private var textColorID: String = TapstStorage.textColorID
    @State private var fontDesign: String = TapstStorage.fontDesignRaw
    @State private var fontBold: Bool = TapstStorage.fontBold

    private let fontDesigns: [(id: String, name: String)] = [
        ("default", "기본"), ("myeongjo", "명조"), ("jua", "둥근"),
        ("pen", "손글씨"), ("dohyeon", "진한고딕")
    ]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 14), count: 6)

    var body: some View {
        List {
            Section("미리보기") { previewCard.listRowInsets(EdgeInsets()) }

            // Text size — available to everyone.
            Section {
                HStack(spacing: 12) {
                    Text("가").font(.footnote).foregroundStyle(.secondary)
                    Slider(value: $textScale, in: 0.85...1.25, step: 0.05)
                        .onChange(of: textScale) { _, v in
                            TapstStorage.textScale = v; apply()
                        }
                    Text("가").font(.title3).foregroundStyle(.secondary)
                }
            } header: {
                Text("글씨 크기")
            } footer: {
                Text("잠금화면 카드의 글씨·체크 크기를 조절해요.")
            }

            // Theme color — Pro.
            Section {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(TapstDesignKit.colors, id: \.id) { item in
                        Circle()
                            .fill(item.color)
                            .frame(height: 34)
                            .overlay {
                                if themeColorID == item.id {
                                    Image(systemName: "checkmark")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white)
                                }
                            }
                            .overlay(Circle().strokeBorder(.white.opacity(0.15)))
                            .onTapGesture { selectColor(item.id) }
                    }
                }
                .padding(.vertical, 6)
            } header: {
                proHeader("테마 색상")
            } footer: {
                if !store.isPro { Text("테마 색상은 메모탭 Pro 전용이에요.") }
            }

            // Text color — Pro.
            Section {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(TapstDesignKit.textColors, id: \.id) { item in
                        Circle()
                            .fill(item.color)
                            .frame(height: 34)
                            .overlay {
                                if textColorID == item.id {
                                    Image(systemName: "checkmark")
                                        .font(.caption.bold())
                                        .foregroundStyle(item.id == "white" ? .black : .white)
                                }
                            }
                            .overlay(Circle().strokeBorder(.gray.opacity(0.4)))
                            .onTapGesture { selectTextColor(item.id) }
                    }
                }
                .padding(.vertical, 6)
            } header: {
                proHeader("텍스트 색상")
            } footer: {
                if !store.isPro { Text("텍스트 색상은 메모탭 Pro 전용이에요.") }
            }

            // Font — Pro.
            Section {
                Picker("서체", selection: $fontDesign) {
                    ForEach(fontDesigns, id: \.id) { Text($0.name).tag($0.id) }
                }
                .onChange(of: fontDesign) { _, v in
                    guard gateProChange() else { return }
                    TapstStorage.fontDesignRaw = v; apply()
                }
                Toggle("굵게", isOn: $fontBold)
                    .onChange(of: fontBold) { _, v in
                        guard gateProChange() else { return }
                        TapstStorage.fontBold = v; apply()
                    }
            } header: {
                proHeader("글꼴")
            }
            .disabled(!store.isPro)
            .opacity(store.isPro ? 1 : 0.5)
        }
        .onAppear { reloadFromStorage() }
        .navigationTitle("디자인")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }

    private func proHeader(_ title: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
            if !store.isPro {
                Image(systemName: "lock.fill").font(.caption2)
            }
        }
    }

    private var previewCard: some View {
        HStack(spacing: 14 * textScale) {
            Circle()
                .strokeBorder(TapstDesignKit.textColor(textColorID).opacity(0.85), lineWidth: 2.5)
                .frame(width: 26 * textScale, height: 26 * textScale)
            Text("메모 미리보기")
                .font(TapstDesignKit.memoFont(fontDesign, size: 20 * textScale, bold: fontBold))
                .foregroundStyle(TapstDesignKit.textColor(textColorID))
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TapstDesignKit.color(themeColorID).opacity(0.5), in: RoundedRectangle(cornerRadius: 22))
        .background(RoundedRectangle(cornerRadius: 22).fill(.black.opacity(0.85)))
        .padding(16)
    }

    private func selectColor(_ id: String) {
        guard gateProChange() else { return }
        themeColorID = id
        TapstStorage.themeColorID = id
        apply()
    }

    private func selectTextColor(_ id: String) {
        guard gateProChange() else { return }
        textColorID = id
        TapstStorage.textColorID = id
        apply()
    }

    /// Returns false (and shows the paywall) when a Pro-only change is attempted by a Basic user.
    private func gateProChange() -> Bool {
        if store.isPro { return true }
        // revert any optimistic UI change
        themeColorID = TapstStorage.themeColorID
        textColorID = TapstStorage.textColorID
        fontDesign = TapstStorage.fontDesignRaw
        fontBold = TapstStorage.fontBold
        showPaywall = true
        return false
    }

    private func reloadFromStorage() {
        textScale = TapstStorage.textScale
        themeColorID = TapstStorage.themeColorID
        textColorID = TapstStorage.textColorID
        fontDesign = TapstStorage.fontDesignRaw
        fontBold = TapstStorage.fontBold
    }

    private func apply() {
        Task { await TapstLiveActivity.refresh() }
    }
}

#Preview {
    NavigationStack { DesignSettingsView() }
}
