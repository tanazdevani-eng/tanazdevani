import SwiftUI

struct VerifyCodeView: View {
    @EnvironmentObject var appModel: AppModel
    let phone: String
    let intent: AuthIntent

    @State private var code = ""
    @State private var isVerifying = false
    @State private var errorMessage: String?
    @FocusState private var codeFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Enter the code")
                .font(KeptFont.display(24, weight: .semibold))
                .foregroundStyle(.keptInk)
                .padding(.top, 20)
            Text("We sent a 6-digit code to \(phone).")
                .font(KeptFont.body(13, weight: .medium))
                .foregroundStyle(.keptInkSoft)
                .padding(.top, 6)

            if !SupabaseConfig.isConfigured {
                Text("Testing locally — Supabase isn't configured yet, so use code \(MockBackendService.testVerificationCode).")
                    .font(KeptFont.body(11.5, weight: .semibold))
                    .foregroundStyle(.keptPurpleDeep)
                    .padding(.top, 10)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(Color.keptPurpleSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            TextField("123456", text: $code)
                .keyboardType(.numberPad)
                .font(KeptFont.mono(24, weight: .semibold))
                .multilineTextAlignment(.center)
                .focused($codeFocused)
                .padding(16)
                .background(.keptSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.keptLine))
                .padding(.top, 20)
                .onChange(of: code) { _, newValue in
                    code = String(newValue.filter(\.isNumber).prefix(6))
                }

            if let errorMessage {
                Text(errorMessage)
                    .font(KeptFont.body(12, weight: .medium))
                    .foregroundStyle(.keptOrangeDeep)
                    .padding(.top, 8)
            }

            Spacer()

            Button {
                Task { await verify() }
            } label: {
                if isVerifying {
                    ProgressView().tint(.white)
                } else {
                    Text("Verify")
                }
            }
            .buttonStyle(KeptPillButtonStyle(background: .keptOrangeFill))
            .disabled(code.count != 6 || isVerifying)
            .opacity(code.count == 6 ? 1 : 0.5)
        }
        .padding(22)
        .background(Color.keptBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { codeFocused = true }
    }

    private func verify() async {
        isVerifying = true
        errorMessage = nil
        do {
            try await appModel.verifyCode(phone: phone, code: code, intent: intent)
        } catch {
            errorMessage = error.localizedDescription
        }
        isVerifying = false
    }
}
