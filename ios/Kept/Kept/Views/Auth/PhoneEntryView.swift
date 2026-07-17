import SwiftUI

struct PhoneEntryView: View {
    @EnvironmentObject var appModel: AppModel
    let intent: AuthIntent

    @State private var phoneDigits = ""
    @State private var selectedCountry = CountryCode.detected()
    @State private var showingCountryPicker = false
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var verifiedPhone: String?

    /// Real E.164 formatting using the picked country's dial code — the old version
    /// assumed every number was a bare 10-digit US number, which silently mangled any
    /// number from outside the US instead of actually sending a usable code.
    private var e164Phone: String {
        "\(selectedCountry.dialCode)\(phoneDigits.filter(\.isNumber))"
    }

    /// Loose on purpose: national number lengths genuinely vary a lot by country (6-14
    /// digits is roughly the real-world range), and the SMS provider is the actual source
    /// of truth on whether a number is deliverable, not a client-side digit count.
    private var isValid: Bool {
        let count = phoneDigits.filter(\.isNumber).count
        return count >= 6 && count <= 14
    }

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

            HStack(spacing: 10) {
                Button {
                    showingCountryPicker = true
                } label: {
                    Text(selectedCountry.dialCode)
                        .font(KeptFont.body(17, weight: .semibold))
                        .foregroundStyle(.keptInk)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 14)
                        .background(.keptSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.keptLine))
                }
                .buttonStyle(.plain)

                TextField("Phone number", text: $phoneDigits)
                    .keyboardType(.phonePad)
                    .font(KeptFont.body(17))
                    .padding(16)
                    .background(.keptSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.keptLine))
            }

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
        .sheet(isPresented: $showingCountryPicker) {
            CountryCodePicker(selection: $selectedCountry)
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
