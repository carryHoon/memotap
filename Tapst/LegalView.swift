//
//  LegalView.swift
//  Tapst (MemoTap)
//
//  In-app Privacy Policy / Terms of Use. Shown from the paywall so the links
//  are always functional in the binary (App Review requirement for IAP), even
//  without an external host. Also used for App Store Connect metadata content.
//

import SwiftUI

enum LegalDoc: String, Identifiable {
    case privacy
    case terms
    var id: String { rawValue }

    var title: String {
        self == .privacy ? String(localized: "개인정보처리방침") : String(localized: "이용약관")
    }

    /// Full document body. The Korean/English text lives in Localizable.xcstrings
    /// (keys "legal.privacy.body" / "legal.terms.body") so the whole document
    /// localizes with the rest of the app.
    var markdown: String {
        switch self {
        case .privacy: return String(localized: "legal.privacy.body")
        case .terms: return String(localized: "legal.terms.body")
        }
    }
}

struct LegalView: View {
    let doc: LegalDoc
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(markdownText)
                    .tint(.blue)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }
            .navigationTitle(doc.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }

    private var markdownText: AttributedString {
        (try? AttributedString(
            markdown: doc.markdown,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(doc.markdown)
    }
}

#Preview {
    LegalView(doc: .privacy)
}
