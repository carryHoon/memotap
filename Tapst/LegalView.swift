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

    var title: String { self == .privacy ? "개인정보처리방침" : "이용약관" }

    var markdown: String {
        switch self {
        case .privacy:
            return """
            **메모탭 개인정보처리방침**

            메모탭(이하 ‘앱’)은 이용자의 개인정보를 수집·전송하지 않는 것을 원칙으로 합니다.

            **1. 수집하지 않는 정보**
            앱은 이름, 이메일, 연락처, 위치, 사용 기록 등 개인을 식별할 수 있는 정보를 수집하지 않습니다.

            **2. 메모 데이터**
            이용자가 작성한 메모는 기기 내부와 앱 그룹(잠금화면 위젯 공유용)에 **로컬로만** 저장되며, 외부 서버로 전송되지 않습니다.

            **3. 결제 정보**
            구독 및 구매는 Apple App Store(StoreKit)를 통해 처리됩니다. 앱은 결제 수단이나 금융 정보를 수집·저장하지 않으며, 구매/구독 상태만 Apple을 통해 확인합니다.

            **4. 문의**
            개인정보 관련 문의: [marcap.official@gmail.com](mailto:marcap.official@gmail.com)

            최종 업데이트: 2026-09-12
            """
        case .terms:
            return """
            **메모탭 이용약관**

            본 약관은 메모탭(이하 ‘앱’) 이용에 적용됩니다.

            **1. 서비스**
            앱은 잠금화면에 메모를 표시하는 기능을 제공합니다. 일부 기능(무제한 메모, 테마, 글꼴 등)은 메모탭 Pro 구매 시 이용할 수 있습니다.

            **2. 구독 및 결제**
            월·연 구독은 **자동 갱신**되며, 현재 기간 종료 24시간 전까지 해지하지 않으면 동일 금액으로 자동 갱신·결제됩니다. ‘평생 이용’은 1회 결제 상품입니다. 구매 후 App Store 계정 설정에서 언제든 관리·해지할 수 있습니다.

            **3. 환불**
            결제 및 환불은 Apple App Store의 정책을 따릅니다.

            **4. 표준 이용약관(EULA)**
            자동 갱신 구독에는 Apple의 표준 최종 사용자 사용권 계약이 함께 적용됩니다: [Apple 표준 EULA](https://www.apple.com/legal/internet-services/itunes/dev/stdeula/)

            **5. 책임의 한계**
            앱은 관련 법이 허용하는 범위에서 ‘있는 그대로’ 제공됩니다.

            **6. 문의**
            [marcap.official@gmail.com](mailto:marcap.official@gmail.com)

            최종 업데이트: 2026-09-12
            """
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
