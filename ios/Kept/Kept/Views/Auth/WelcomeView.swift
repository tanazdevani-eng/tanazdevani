import SwiftUI

struct WelcomeView: View {
    @State private var intent: AuthIntent?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 10) {
                Text("Kept").keptWordmark(44).foregroundStyle(.keptInk)
                Text("Some habits you keep. Some you keep to yourself.")
                    .font(KeptFont.display(15, italic: true))
                    .foregroundStyle(.keptInkSoft)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()

            VStack(spacing: 10) {
                Button("Sign Up") { intent = .signUp }
                    .buttonStyle(KeptPillButtonStyle(background: .keptOrangeFill))

                Button("Log In") { intent = .logIn }
                    .buttonStyle(KeptPillButtonStyle(background: .keptBackground, foreground: .keptInk, borderColor: .keptLine))
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 30)
        }
        .background(Color.keptBackground.ignoresSafeArea())
        .navigationDestination(item: $intent) { intent in
            PhoneEntryView(intent: intent)
        }
    }
}
