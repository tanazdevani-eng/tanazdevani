import SwiftUI

/// Onboarding IS profile setup, not a separate tutorial — matches how Hinge does it: a
/// short linear flow right after verification, framed as "getting you set up," not a
/// feature tour. This is deliberately just two fields; bio and photo can be filled in
/// later from Edit Profile, no reason to block getting into the app over them.
struct OnboardingProfileView: View {
    @EnvironmentObject var appModel: AppModel
    @State private var name = ""
    @State private var handle = ""
    @State private var goToNotifications = false

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !handle.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Nice to meet you")
                .font(KeptFont.display(24, weight: .semibold))
                .foregroundStyle(.keptInk)
                .padding(.top, 20)
            Text("Just enough to get started. You can fill in the rest later.")
                .font(KeptFont.body(13, weight: .medium))
                .foregroundStyle(.keptInkSoft)
                .padding(.top, 6)
                .padding(.bottom, 24)

            fieldLabel("Name")
            TextField("", text: $name)
                .font(KeptFont.body(15))
                .padding(15)
                .background(.keptSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.keptLine))
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()

            fieldLabel("Username").padding(.top, 16)
            TextField("", text: $handle)
                .font(KeptFont.body(15))
                .padding(15)
                .background(.keptSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.keptLine))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Spacer()

            Button("Continue") {
                appModel.completeProfileOnboarding(name: name, handle: handle)
                goToNotifications = true
            }
            .buttonStyle(KeptPillButtonStyle(background: .keptOrangeFill))
            .disabled(!isValid)
            .opacity(isValid ? 1 : 0.5)
        }
        .padding(22)
        .background(Color.keptBackground.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $goToNotifications) {
            OnboardingNotificationsView()
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(KeptFont.mono(11, weight: .semibold))
            .foregroundStyle(.keptInkSoft)
            .padding(.bottom, 8)
    }
}
