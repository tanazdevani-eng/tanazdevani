import SwiftUI

struct PhoneEntryView: View {
    @EnvironmentObject var appModel: AppModel
    let intent: AuthIntent

    @State private var phoneDigits = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var verifiedPhone: String?

    /// Minimal E.164 formatting: assumes a US number unless the user typed their own
    /// country code with a leading "+". A full country picker is a reasonable follow-up
    /// once this is tested against a real SMS provider outside the US.
    private var e164Phone: String {
        let digits = phoneDigits.filter(\.isNumber)
        return digits.count == 10 ? "+1\(digits)" : "+\(digits)"
    }

    private var isValid: Bool { phoneDigits.filter(\.isNumber).count >= 10 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(intent == .signUp ? "What's your number?" : "Welcome back")
                .font(KeptFont.display(24, weight: .semibold))
                .foregroundStyle(.keptInk)
                .padding(.top, 20)
            Text("We'll text you a code, no password to remember.")
                .font(KeptFont.body(13, weight: .medium))
                .foregroundStyle(.keptInkSoft)
                .padding(.top, 6)
                .padding(.bottom, 24)

            TextField("(555) 123-4567", text: $phoneDigits)
                .keyboardType(.phonePad)
                .font(KeptFont.body(17))
                .padding(16)
                .background(.keptSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.keptLine))

            if let errorMessage {
                Text(errorMessage)
                    .font(KeptFont.body(12, weight: .medium))
                    .foregroundStyle(.keptOrangeDeep)
                    .padding(.top, 8)
            }

            Spacer()

            Button {
                Task { await sendCode() }
            } label: {
                if isSending {
                    ProgressView().tint(.white)
                } else {
                    Text("Send code")
                }
            }
            .buttonStyle(KeptPillButtonStyle(background: .keptOrangeFill))
            .disabled(!isValid || isSending)
            .opacity(isValid ? 1 : 0.5)
        }
        .padding(22)
        .background(Color.keptBackground.ignoresSafeArea())
        .navigationTitle(intent == .signUp ? "Sign Up" : "Log In")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $verifiedPhone) { phone in
            VerifyCodeView(phone: phone, intent: intent)
        }
    }

    private func sendCode() async {
        isSending = true
        errorMessage = nil
        do {
            try await appModel.requestVerificationCode(phone: e164Phone)
            verifiedPhone = e164Phone
        } catch {
            errorMessage = error.localizedDescription
        }
        isSending = false
    }
}
